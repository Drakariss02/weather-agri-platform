#!/usr/bin/env bash
set -e
PGHOST="${POSTGRES_HOST:-localhost}"
PGPORT="${POSTGRES_PORT:-5432}"
PGDB="${POSTGRES_DB:-agri}"
PGUSER="${POSTGRES_USER:-agri_user}"
PGPASS="${POSTGRES_PASSWORD:-changeme}"

export PGPASSWORD="$PGPASS"

echo "Initialisation de la base ${PGDB} sur ${PGHOST}:${PGPORT}..."
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDB" -f db/init.sql
echo "Terminé."
