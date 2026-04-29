#!/bin/bash

# -----------------------------
# Backup de Arquivos do Mapas Culturais
# -----------------------------
set -euo pipefail

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "❌ Erro: Parâmetros não fornecidos."
    echo "Uso: $0 <pasta_projeto> <pasta_backup>"
    exit 1
fi

PROJECT_FOLDER="$1"
BACKUP_FOLDER="$2"
BACKUP_NAME="$(date +%Y%m%d%H%M%S)-mapacultural-files"

# Configurações FTP
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

echo "📁 Iniciando backup dos arquivos..."

# Criar estrutura de diretórios para backup
mkdir -p "$BACKUP_FOLDER/docker-data/private-files"
mkdir -p "$BACKUP_FOLDER/docker-data/public-files"
mkdir -p "$BACKUP_FOLDER/docker-data/logs"

# Backup dos arquivos com rsync (preserva permissões e estrutura)
echo "🔄 Copiando private-files..."
rsync -ar "$PROJECT_FOLDER/docker-data/private-files/" "$BACKUP_FOLDER/docker-data/private-files/" && echo "✅ private-files copiados"

echo "🔄 Copiando public-files..."
rsync -ar "$PROJECT_FOLDER/docker-data/public-files/" "$BACKUP_FOLDER/docker-data/public-files/" && echo "✅ public-files copiados"

echo "🔄 Copiando logs..."
rsync -ar "$PROJECT_FOLDER/docker-data/logs/" "$BACKUP_FOLDER/docker-data/logs/" && echo "✅ logs copiados"

# Backup do .env
if [ -f "$PROJECT_FOLDER/.env" ]; then
    cp "$PROJECT_FOLDER/.env" "$BACKUP_FOLDER/.env" && echo "✅ .env copiado"
else
    echo "⚠️  Arquivo .env não encontrado em $PROJECT_FOLDER"
fi

# Compactar os arquivos de backup
echo "🗜️  Compactando arquivos..."
FILES_BACKUP_NAME="${BACKUP_NAME}.tar.gz"
pushd "$BACKUP_FOLDER" > /dev/null
tar -czf "$FILES_BACKUP_NAME" docker-data .env 2>/dev/null && echo "✅ Arquivos compactados: $FILES_BACKUP_NAME"
popd > /dev/null

# Calcular tamanho do backup
backup_size=$(du -h "$BACKUP_FOLDER/$FILES_BACKUP_NAME" | cut -f1)
echo "📦 Tamanho do backup: $backup_size"

# Limpeza local de backups antigos
total_files_backup=$(ls -1t "$BACKUP_FOLDER"/*-mapacultural-files.tar.gz 2>/dev/null | wc -l)
if [ "$total_files_backup" -gt 7 ]; then
    echo "🧹 Removendo backups de arquivos antigos locais..."
    ls -1t "$BACKUP_FOLDER"/*-mapacultural-files.tar.gz | tail -n +8 | while read -r old_backup; do
        echo "   🗑️  Removendo: $(basename "$old_backup")"
        rm -f "$old_backup"
    done
fi

# -----------------------------
# Upload para FTP
# -----------------------------
if [ "$FTP_ENABLED" = true ]; then
    echo "🌍 Enviando backup para FTP..."

    if [ "$USE_DAILY_SUBFOLDER" = true ]; then
        REMOTE_DIR="$FTP_PATH/files/$DATE_FOLDER"
    else
        REMOTE_DIR="$FTP_PATH/files"
    fi

    # Upload do backup dos arquivos
    if [ -f "$BACKUP_FOLDER/$FILES_BACKUP_NAME" ]; then
        echo "📤 Enviando: $FILES_BACKUP_NAME"
        
        if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<FTP_EOF 2>/dev/null
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit no
set net:max-retries 3
set net:timeout 30

mkdir -p $REMOTE_DIR 2>/dev/null
cd $REMOTE_DIR
put "$BACKUP_FOLDER/$FILES_BACKUP_NAME"
bye
FTP_EOF
        then
            echo "✅ Backup enviado com sucesso para: $REMOTE_DIR/$FILES_BACKUP_NAME"
        else
            echo "❌ Falha no envio FTP"
        fi
    else
        echo "❌ Arquivo de backup não encontrado: $FILES_BACKUP_NAME"
    fi

    # -----------------------------
    # Limpeza remota
    # -----------------------------
    if [ "$CLEAN_REMOTE" = true ]; then
        echo "🧹 Executando limpeza de backups remotos antigos..."
        
        FILES_LIST=$(mktemp)
        lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<LIST_EOF 2>/dev/null | grep 'mapacultural-files\.tar\.gz$' > "$FILES_LIST"
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit no
cd "$REMOTE_DIR"
cls -1
bye
LIST_EOF

        if [ -s "$FILES_LIST" ]; then
            TOTAL_FILES=$(wc -l < "$FILES_LIST")
            echo "📊 Total de backups remotos: $TOTAL_FILES"
            
            if [ "$TOTAL_FILES" -gt "$REMOTE_KEEP_COUNT" ]; then
                REMOVE_COUNT=$((TOTAL_FILES - REMOTE_KEEP_COUNT))
                echo "🗑️  Removendo $REMOVE_COUNT backups antigos..."
                
                FILES_TO_DELETE=$(sort "$FILES_LIST" | head -n "$REMOVE_COUNT")
                
                echo "📋 Arquivos marcados para remoção:"
                echo "$FILES_TO_DELETE" | while IFS= read -r file; do
                    if [ -n "$file" ]; then
                        echo "   🗑️  $file"
                    fi
                done
                
                # Executar limpeza
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
            else
                echo "ℹ️  Nenhuma limpeza necessária ($TOTAL_FILES arquivos, mantendo $REMOTE_KEEP_COUNT)"
            fi
        else
            echo "ℹ️  Nenhum backup remoto encontrado para limpeza"
        fi
        
        rm -f "$FILES_LIST"
    fi
fi

# Limpar arquivos descompactados (opcional - comente se quiser manter)
echo "🧹 Limpando arquivos temporários..."
rm -rf "$BACKUP_FOLDER/docker-data" "$BACKUP_FOLDER/.env"

echo "✅ Backup de arquivos concluído!"
echo "📊 Resumo:"
echo "   - Backup: $FILES_BACKUP_NAME"
echo "   - Tamanho: $backup_size"
echo "   - Local: $BACKUP_FOLDER/$FILES_BACKUP_NAME"
if [ "$FTP_ENABLED" = true ]; then
    echo "   - Remoto: $FTP_HOST$REMOTE_DIR/$FILES_BACKUP_NAME"
fi