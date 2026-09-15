#!/bin/bash

# -----------------------------
# Backup de Arquivos do Mapas Culturais
# -----------------------------
set -euo pipefail

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    echo "❌ Erro: Parâmetros não fornecidos."
    echo "Uso: $0 <pasta_projeto> <pasta_backup>"
    exit 1
fi

PROJECT_FOLDER="$1"
BACKUP_FOLDER="$2"
BACKUP_NAME="$(date +%Y%m%d%H%M%S)-mapacultural-files"

# Carregar arquivo .env do projeto se existir
ENV_FILE="$PROJECT_FOLDER/.env"
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

echo "📁 Iniciando backup dos arquivos..."

mkdir -p "$BACKUP_FOLDER/docker-data/private-files"
mkdir -p "$BACKUP_FOLDER/docker-data/public-files"
mkdir -p "$BACKUP_FOLDER/docker-data/logs"

echo "🔄 Copiando diretórios..."
[ -d "$PROJECT_FOLDER/docker-data/private-files" ] && rsync -ar "$PROJECT_FOLDER/docker-data/private-files/" "$BACKUP_FOLDER/docker-data/private-files/"
[ -d "$PROJECT_FOLDER/docker-data/public-files" ] && rsync -ar "$PROJECT_FOLDER/docker-data/public-files/" "$BACKUP_FOLDER/docker-data/public-files/"
[ -d "$PROJECT_FOLDER/docker-data/logs" ] && rsync -ar "$PROJECT_FOLDER/docker-data/logs/" "$BACKUP_FOLDER/docker-data/logs/"

if [ -f "$PROJECT_FOLDER/.env" ]; then
    cp "$PROJECT_FOLDER/.env" "$BACKUP_FOLDER/.env"
fi

echo "🗜️  Compactando arquivos..."
FILES_BACKUP_NAME="${BACKUP_NAME}.tar.gz"
tar -czf "$BACKUP_FOLDER/$FILES_BACKUP_NAME" -C "$BACKUP_FOLDER" docker-data .env 2>/dev/null || true

backup_size=$(du -h "$BACKUP_FOLDER/$FILES_BACKUP_NAME" | cut -f1)
echo "📦 Tamanho do backup: $backup_size"

# Limpeza local
total_files_backup=$(ls -1t "$BACKUP_FOLDER"/*-mapacultural-files.tar.gz 2>/dev/null | wc -l)
if [ "$total_files_backup" -gt 7 ]; then
    echo "🧹 Removendo backups antigos locais..."
    ls -1t "$BACKUP_FOLDER"/*-mapacultural-files.tar.gz | tail -n +8 | while read -r old_backup; do
        rm -f "$old_backup"
    done
fi

# Upload FTP
if [ "$FTP_ENABLED" = "true" ]; then
    REMOTE_DIR="$FTP_PATH/files"
    [ "$USE_DAILY_SUBFOLDER" = "true" ] && REMOTE_DIR="$FTP_PATH/files/$DATE_FOLDER"

    echo "📤 Enviando para FTP ($FTP_HOST:$FTP_PORT)..."
    if lftp -p "$FTP_PORT" -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<FTP_EOF
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit no
set net:max-retries 3
set net:timeout 30

mkdir -p $REMOTE_DIR
cd $REMOTE_DIR
put "$BACKUP_FOLDER/$FILES_BACKUP_NAME"
bye
FTP_EOF
    then
        echo "✅ Backup enviado com sucesso para: $REMOTE_DIR/$FILES_BACKUP_NAME"
    else
        echo "❌ Falha no envio FTP."
    fi

    # Limpeza Remota
    if [ "$CLEAN_REMOTE" = "true" ]; then
        echo "🧹 Executando limpeza de backups remotos antigos..."
        FILES_LIST=$(mktemp)
        lftp -p "$FTP_PORT" -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<LIST_EOF 2>/dev/null | grep 'mapacultural-files\.tar\.gz$' > "$FILES_LIST" || true
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit no
cd "$REMOTE_DIR"
cls -1
bye
LIST_EOF

        if [ -s "$FILES_LIST" ]; then
            TOTAL_FILES=$(wc -l < "$FILES_LIST")
            if [ "$TOTAL_FILES" -gt "$REMOTE_KEEP_COUNT" ]; then
                REMOVE_COUNT=$((TOTAL_FILES - REMOTE_KEEP_COUNT))
                FILES_TO_DELETE=$(sort "$FILES_LIST" | head -n "$REMOVE_COUNT")

                echo "🗑️  Removendo $REMOVE_COUNT backups remotos antigos..."
                lftp -p "$FTP_PORT" -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<CLEAN_EOF 2>/dev/null || true
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit no
cd "$REMOTE_DIR"
$(echo "$FILES_TO_DELETE" | while IFS= read -r file; do [ -n "$file" ] && echo "rm \"$file\""; done)
bye
CLEAN_EOF
                echo "✅ Limpeza remota concluída."
            fi
        fi
        rm -f "$FILES_LIST"
    fi
fi

rm -rf "$BACKUP_FOLDER/docker-data" "$BACKUP_FOLDER/.env"
echo "✅ Backup de arquivos concluído!"