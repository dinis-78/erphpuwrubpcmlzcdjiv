#!/usr/bin/env bash
set -euo pipefail

# Allow overriding the host or the full URL (useful for docker-compose)
HOST="${HOST:-localhost}"
PSQL_URL="${PSQL_URL:-postgresql://postgres:postgres@${HOST}:5432/postgres}"

echo "Waiting for Postgres to be ready on host ${HOST}..."
until pg_isready -h "$HOST" -p 5432 -U postgres >/dev/null 2>&1; do
  sleep 1
done

echo "Applying migrations..."
psql "$PSQL_URL" -f supabase/migrations/001_init.sql

echo "Running smoke checks..."
psql "$PSQL_URL" -c "SELECT to_regclass('public.users') AS users_table, to_regclass('public.jobs') AS jobs_table;"

# Run schema smoke tests if present
if [ -f tests/schema_smoke.sql ]; then
  echo "Running schema smoke tests..."
  psql "$PSQL_URL" -v ON_ERROR_STOP=1 -f tests/schema_smoke.sql
fi

echo "Done."
