#!/bin/bash

# -----------------------------
# Configurações
# -----------------------------
set -euo pipefail

if [ -z "$1" ]; then
    echo "❌ Erro: Pasta de destino não fornecida."
    echo "Uso: $0 <pasta_destino>"
    exit 1
fi

DUMP_FOLDER="$1"
DUMP_NAME="$(date +%Y%m%d%H%M%S)-mapacultural-postgres"

containers=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgis|db')

if [ -z "$containers" ]; then
    echo "❌ Nenhum container de banco de dados encontrado."
    exit 1
fi

FTP_ENABLED=true
FTP_HOST="172.16.0.20"
FTP_USER="junior.ti"
FTP_PASS="Ejr@94_30"
FTP_PATH="/backups/mapacultural"

USE_DAILY_SUBFOLDER=false
DATE_FOLDER=$(date +%Y-%m-%d)

# Ativar limpeza remota
CLEAN_REMOTE=true
REMOTE_KEEP_COUNT=7

if ! command -v lftp >/dev/null 2>&1; then
    echo "❌ Erro: 'lftp' não está instalado. Execute: sudo apt install -y lftp"
    exit 1
fi

echo "Containers encontrados: ${containers}"

for container in $containers; do
    filename="${DUMP_NAME}.sql.gz"
    
    # CORREÇÃO: Extrair o nome base do container removendo o sufixo numérico
    # Para "mc-redencao-pa-db-1" vai se tornar "mc-redencao-pa-db"
    dumpname=$(echo "$container" | sed 's/-[0-9]\+$//')
    #dumpname="database"
    dumpfolder="${DUMP_FOLDER}/${dumpname}"

    # VERIFICAÇÃO: Criar diretório apenas se não existir
    if [ ! -d "$dumpfolder" ]; then
        echo "📁 Criando diretório: $dumpfolder"
        mkdir -p "$dumpfolder"
    fi

    pushd "$dumpfolder" > /dev/null

    echo "Gerando dump do container $container ..."
    if docker exec "$container" sh -c 'pg_dump -U mapas --no-owner -d mapas' | gzip -c > "$filename"; then
        echo "✅ Dump salvo em: $dumpfolder/$filename"
        
        if [ ! -s "$filename" ]; then
            echo "❌ Arquivo de dump vazio para $container"
            popd > /dev/null
            continue
        fi
    else
        echo "❌ Falha ao gerar dump para $container"
        popd > /dev/null
        continue
    fi

    # Limpeza local
    total=$(ls -1t ./*.sql.gz 2>/dev/null | wc -l)
    if [ "$total" -gt 7 ]; then
        echo "🧹 Removendo dumps antigos locais..."
        ls -1t ./*.sql.gz | tail -n +8 | xargs rm -f
    fi

    # FTP
    if [ "$FTP_ENABLED" = true ]; then
        echo "🌍 Enviando dump via FTP para $FTP_HOST ..."

        if [ "$USE_DAILY_SUBFOLDER" = true ]; then
            REMOTE_DIR="$FTP_PATH/$dumpname/$DATE_FOLDER"
        else
            REMOTE_DIR="$FTP_PATH/$dumpname"
        fi

        # Upload do arquivo - versão sem aviso de mkdir
        if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<EOF 2>/dev/null
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit no
set net:max-retries 3
set net:timeout 30

# Tenta criar diretório (ignora erro se já existir)
mkdir -p $REMOTE_DIR 2>/dev/null
cd $REMOTE_DIR
put "$filename"
bye
EOF
        then
            echo "✅ Backup enviado com sucesso para FTP: $REMOTE_DIR/$filename"
        else
            echo "❌ Falha no envio FTP para $container"
            popd > /dev/null
            continue
        fi

        # Limpeza remota
        if [ "$CLEAN_REMOTE" = true ]; then
            echo "🧹 Executando limpeza de backups remotos antigos..."
            
            # Obter lista de arquivos do FTP
            FILES_LIST=$(mktemp)
            lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<LIST_EOF 2>/dev/null | grep '\.sql\.gz$' > "$FILES_LIST"
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit no
cd "$REMOTE_DIR"
cls -1
bye
LIST_EOF

            # Verificar se encontrou arquivos
            if [ ! -s "$FILES_LIST" ]; then
                echo "ℹ️  Nenhum arquivo encontrado para limpeza"
                rm -f "$FILES_LIST"
            else
                TOTAL_FILES=$(wc -l < "$FILES_LIST")
                echo "📊 Total de arquivos remotos: $TOTAL_FILES"
                
                if [ "$TOTAL_FILES" -le "$REMOTE_KEEP_COUNT" ]; then
                    echo "ℹ️  Nenhuma limpeza necessária ($TOTAL_FILES arquivos, mantendo $REMOTE_KEEP_COUNT)"
                    rm -f "$FILES_LIST"
                else
                    REMOVE_COUNT=$((TOTAL_FILES - REMOTE_KEEP_COUNT))
                    echo "🗑️  Removendo $REMOVE_COUNT arquivos antigos..."
                    
                    # Ordenar arquivos por nome (do mais antigo para o mais recente) e pegar os mais antigos
                    FILES_TO_DELETE=$(sort "$FILES_LIST" | head -n "$REMOVE_COUNT")
                    
                    # Mostrar quais arquivos serão removidos
                    echo "📋 Arquivos marcados para remoção:"
                    echo "$FILES_TO_DELETE" | while IFS= read -r file; do
                        if [ -n "$file" ]; then
                            echo "   🗑️  $file"
                        fi
                    done
                    
                    # Executar limpeza usando here document
                    if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<CLEAN_EOF 2>/dev/null
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit no
set net:max-retries 3
set net:timeout 30

cd "$REMOTE_DIR"

$(echo "$FILES_TO_DELETE" | while IFS= read -r file; do
    [ -n "$file" ] && echo "rm \"$file\""
done)

bye
CLEAN_EOF
                    then
                        echo "✅ Limpeza remota concluída com sucesso"
                    else
                        echo "⚠️  Alguns erros durante a limpeza remota"
                    fi
                    
                    rm -f "$FILES_LIST"
                fi
            fi
        fi
    fi

    popd > /dev/null
done

echo "✅ Backup concluído!"