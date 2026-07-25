#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p backups
set -a
source .env.hostinger
set +a

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
docker compose --env-file .env.hostinger -f docker-compose.hostinger.yml exec -T mysql \
  mysqldump --single-transaction --quick -usenderwho -p"$MYSQL_PASSWORD" senderwho \
  | gzip > "backups/senderwho-$stamp.sql.gz"

find backups -type f -name 'senderwho-*.sql.gz' -mtime +14 -delete
echo "Created backups/senderwho-$stamp.sql.gz"
