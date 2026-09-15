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

containers=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgis|db' || true)

if [ -z "$containers" ]; then
    echo "❌ Nenhum container de banco de dados encontrado."
    exit 1
fi

FTP_ENABLED="${FTP_ENABLED:-true}"
FTP_HOST="${FTP_HOST:-143.255.205.193}"
FTP_USER="${FTP_USER:-master_ftp}"
FTP_PORT="${FTP_PORT:-2121}"
FTP_PASS="${FTP_PASS:-}"
FTP_PATH="${FTP_PATH:-/MAPACULTURAL}"

for container in $containers; do
    filename="${DUMP_NAME}.sql.gz"
    dumpname=$(echo "$container" | sed 's/-[0-9]\+$//')
    dumpfolder="${DUMP_FOLDER}/${dumpname}"

    mkdir -p "$dumpfolder"

    echo "🛢️ Gerando dump de $container..."
    if docker exec "$container" pg_dump -U mapas --no-owner -d mapas | gzip -c > "$dumpfolder/$filename"; then

        if [ ! -s "$dumpfolder/$filename" ]; then
            echo "❌ Dump vazio gerado para $container."
            continue
        fi
        echo "✅ Dump salvo: $dumpfolder/$filename"
    else
        echo "❌ Erro ao executar pg_dump em $container."
        continue
    fi

    # Limpeza Local Segura
    total=$(ls -1t "$dumpfolder"/*.sql.gz 2>/dev/null | wc -l)
    if [ "$total" -gt 7 ]; then
        ls -1t "$dumpfolder"/*.sql.gz | tail -n +8 | while read -r old_dump; do
            rm -f "$old_dump"
        done
    fi

    # Envios FTP
    if [ "$FTP_ENABLED" = true ]; then
        REMOTE_DIR="$FTP_PATH/$dumpname"

        lftp -p "$FTP_PORT" -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<EOF
set ftp:ssl-allow yes
set ftp:passive-mode yes
mkdir -p $REMOTE_DIR
cd $REMOTE_DIR
put "$dumpfolder/$filename"
bye
EOF
    fi
done

echo "✅ Processo de dump finalizado!"