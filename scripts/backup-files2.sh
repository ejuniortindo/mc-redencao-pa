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

# Configurações FTP via variáveis de ambiente (com fallback)
FTP_ENABLED="${FTP_ENABLED:-true}"
FTP_HOST="${FTP_HOST:-143.255.205.193}"
FTP_USER="${FTP_USER:-master_ftp}"
FTP_PORT="${FTP_PORT:-2121}"
FTP_PASS="${FTP_PASS:-}" # Recomenda-se definir no ambiente
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
rsync -ar "$PROJECT_FOLDER/docker-data/private-files/" "$BACKUP_FOLDER/docker-data/private-files/"
rsync -ar "$PROJECT_FOLDER/docker-data/public-files/" "$BACKUP_FOLDER/docker-data/public-files/"
rsync -ar "$PROJECT_FOLDER/docker-data/logs/" "$BACKUP_FOLDER/docker-data/logs/"

if [ -f "$PROJECT_FOLDER/.env" ]; then
    cp "$PROJECT_FOLDER/.env" "$BACKUP_FOLDER/.env"
fi

echo "🗜️ Compactando arquivos..."
FILES_BACKUP_NAME="${BACKUP_NAME}.tar.gz"
tar -czf "$BACKUP_FOLDER/$FILES_BACKUP_NAME" -C "$BACKUP_FOLDER" docker-data .env

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
if [ "$FTP_ENABLED" = true ]; then
    REMOTE_DIR="$FTP_PATH/files"
    [ "$USE_DAILY_SUBFOLDER" = true ] && REMOTE_DIR="$FTP_PATH/files/$DATE_FOLDER"

    echo "📤 Enviando para FTP..."
    if lftp -p "$FTP_PORT" -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<FTP_EOF
set ftp:ssl-allow yes
set ftp:passive-mode yes
set cmd:fail-exit yes
mkdir -p $REMOTE_DIR
cd $REMOTE_DIR
put "$BACKUP_FOLDER/$FILES_BACKUP_NAME"
bye
FTP_EOF
    then
        echo "✅ Backup enviado com sucesso."
    else
        echo "❌ Falha no envio FTP."
    fi
fi

rm -rf "$BACKUP_FOLDER/docker-data" "$BACKUP_FOLDER/.env"
echo "✅ Concluído!"
