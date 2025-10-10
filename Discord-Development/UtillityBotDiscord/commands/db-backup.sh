#!/usr/bin/env bash
set -euo pipefail

DB="NOMEDB"
USER="root"
PASS=""
HOST="127.0.0.1"
PORT="3306"

OUT_DIR="/home/ubuntu/Desktop/BACKUPS/BACKUPDB"
mkdir -p "$OUT_DIR"
STAMP="$(date +%F_%H-%M)"
FILE="$OUT_DIR/${DB}_${STAMP}.sql.gz"

# Resolve binários
MYSQLDUMP_BIN="$(command -v mysqldump || true)"
[[ -z "$MYSQLDUMP_BIN" && -x "/opt/lampp/bin/mysqldump" ]] && MYSQLDUMP_BIN="/opt/lampp/bin/mysqldump"
MYSQL_BIN="$(command -v mysql || true)"
[[ -z "$MYSQL_BIN" && -x "/opt/lampp/bin/mysql" ]] && MYSQL_BIN="/opt/lampp/bin/mysql"

[[ -z "${MYSQLDUMP_BIN:-}" ]] && { echo "ERRO: mysqldump não encontrado."; exit 127; }

# Flags de acesso
EXTRA_OPTS=( --host="$HOST" --port="$PORT" --protocol=TCP )
PASS_OPTS=(); [[ -n "$PASS" ]] && PASS_OPTS=(-p"$PASS")

# Descobre se o event_scheduler está ON; se não, ignora events
EVENTS_FLAG="--skip-events"
if [[ -n "${MYSQL_BIN:-}" ]]; then
  ES="$("$MYSQL_BIN" -u "$USER" "${PASS_OPTS[@]}" -h "$HOST" -P "$PORT" -Nse "SELECT @@event_scheduler;")" || true
  [[ "$ES" == "ON" || "$ES" == "1" ]] && EVENTS_FLAG="--events"
fi

# Dump com rotinas e triggers; events só se suportado
"$MYSQLDUMP_BIN" -u "$USER" "${PASS_OPTS[@]}" \
  --single-transaction --quick --routines --triggers "$EVENTS_FLAG" \
  "${EXTRA_OPTS[@]}" "$DB" | gzip > "$FILE"

# Rotação (7 dias)
find "$OUT_DIR" -name "${DB}_*.sql.gz" -mtime +7 -delete

echo "$FILE"
