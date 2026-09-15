#!/bin/bash

# -----------------------------
# Backup do Banco de Dados PostgreSQL
# -----------------------------
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "❌ Erro: Pasta de destino não fornecida."
    echo "Uso: $0 <pasta_destino>"
    exit 1
fi

DUMP_FOLDER="$1"
DUMP_NAME="$(date +%Y%m%d%H%M%S)-mapacultural-postgres"

# Tentar localizar o arquivo .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo "📄 Carregando configurações do arquivo .env..."
    set -o allexport
    eval "$(grep -v '^#' "$ENV_FILE" | grep -v '^\s*$' | sed -e 's/=/="/' -e 's/$/"/')"
    set +o allexport
fi

# Configurações FTP (valores do .env com fallback caso estejam ausentes)
FTP_ENABLED="${FTP_ENABLED:-true}"
FTP_HOST="${FTP_HOST:-143.255.205.193}"
FTP_USER="${FTP_USER:-master_ftp}"
FTP_PORT="${FTP_PORT:-2121}"
FTP_PASS="${FTP_PASS:-}"
FTP_PATH="${FTP_PATH:-/MAPACULTURAL}"

USE_DAILY_SUBFOLDER=false
DATE_FOLDER=$(date +%Y-%m-%d)

CLEAN_REMOTE=true
REMOTE_KEEP_COUNT=7

if ! command -v lftp >/dev/null 2>&1; then
    echo "❌ Erro: 'lftp' não está instalado."
    exit 1
fi

containers=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgis|db' || true)

if [ -z "$containers" ]; then
    echo "❌ Nenhum container de banco de dados encontrado."
    exit 1
fi

echo "Containers encontrados: ${containers}"

for container in $containers; do
    filename="${DUMP_NAME}.sql.gz"
    dumpname=$(echo "$container" | sed 's/-[0-9]\+$//')
    dumpfolder="${DUMP_FOLDER}/${dumpname}"

    mkdir -p "$dumpfolder"

    echo "🛢️ Gerando dump de $container..."
    if docker exec "$container" pg_dump -U mapas --no-owner -d mapas | gzip -c > "$dumpfolder/$filename"; then
        if [ ! -s "$dumpfolder/$filename" ]; then
            echo "❌ Arquivo de dump vazio para $container"
            continue
        fi
        echo "✅ Dump salvo em: $dumpfolder/$filename"
    else
        echo "❌ Falha ao gerar dump para $container"
        continue
    fi

    # Limpeza Local
    total=$(ls -1t "$dumpfolder"/*.sql.gz 2>/dev/null | wc -l)
    if [ "$total" -gt 7 ]; then
        echo "🧹 Removendo dumps antigos locais..."
        ls -1t "$dumpfolder"/*.sql.gz | tail -n +8 | while read -r old_dump; do
            rm -f "$old_dump"
        done
    fi

    # Upload FTP
    if [ "$FTP_ENABLED" = "true" ]; then
        REMOTE_DIR="$FTP_PATH/$dumpname"
        [ "$USE_DAILY_SUBFOLDER" = "true" ] && REMOTE_DIR="$FTP_PATH/$dumpname/$DATE_FOLDER"

        echo "🌍 Enviando dump via FTP para $FTP_HOST:$FTP_PORT..."
        if lftp -p "$FTP_PORT" -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<EOF
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit yes
set net:max-retries 3
set net:timeout 30

mkdir -p $REMOTE_DIR 2>/dev/null || true
cd $REMOTE_DIR
put "$dumpfolder/$filename"
bye
EOF
        then
            echo "✅ Backup enviado com sucesso para FTP: $REMOTE_DIR/$filename"
        else
            echo "❌ Falha no envio FTP para $container"
            continue
        fi

        # Limpeza Remota
        if [ "$CLEAN_REMOTE" = "true" ]; then
            echo "🧹 Executando limpeza de backups remotos antigos..."
            FILES_LIST=$(mktemp)
            lftp -p "$FTP_PORT" -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<LIST_EOF 2>/dev/null | grep '\.sql\.gz$' > "$FILES_LIST" || true
set ftp:ssl-allow yes
set ftp:passive-mode yes
cd "$REMOTE_DIR"
cls -1
bye
LIST_EOF

            if [ -s "$FILES_LIST" ]; then
                TOTAL_FILES=$(wc -l < "$FILES_LIST")
                if [ "$TOTAL_FILES" -gt "$REMOTE_KEEP_COUNT" ]; then
                    REMOVE_COUNT=$((TOTAL_FILES - REMOTE_KEEP_COUNT))
                    FILES_TO_DELETE=$(sort "$FILES_LIST" | head -n "$REMOVE_COUNT")

                    echo "🗑️  Removendo $REMOVE_COUNT dumps remotos antigos..."
                    lftp -p "$FTP_PORT" -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<CLEAN_EOF 2>/dev/null || true
set ftp:ssl-allow yes
set ftp:passive-mode yes
cd "$REMOTE_DIR"
$(echo "$FILES_TO_DELETE" | while IFS= read -r file; do [ -n "$file" ] && echo "rm \"$file\""; done)
bye
CLEAN_EOF
                    echo "✅ Limpeza remota concluída com sucesso."
                fi
            fi
            rm -f "$FILES_LIST"
        fi
    fi
done

echo "✅ Backup de banco de dados concluído!"