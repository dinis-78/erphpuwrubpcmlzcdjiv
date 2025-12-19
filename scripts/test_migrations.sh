#!/usr/bin/env bash
set -euo pipefail

# Allow overriding the host or the full URL (useful for docker-compose)
HOST="${HOST:-localhost}"
PSQL_URL="${PSQL_URL:-postgresql://postgres:postgres@${HOST}:5432/postgres}"

echo "Waiting for Postgres to be ready on host ${HOST}..."
until pg_isready -h "$HOST" -p 5432 -U postgres >/dev/null 2>&1; do
  sleep 1
done

echo "Preparing local auth stub for Supabase-like objects..."
if [ -f tests/setup_auth.sql ]; then
  psql "$PSQL_URL" -v ON_ERROR_STOP=1 -f tests/setup_auth.sql
fi

# Quick sanity check: detect core tables that indicate an existing DB to avoid
# duplicate DDL/policy errors (common with Docker volumes). Provide a helpful
# hint and fail early so users can run a clean migration.
EXISTING_COUNT=$(psql "$PSQL_URL" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('users','jobs','subscriptions','invoices','proof_entries')" || echo "0")
# keep digits only
EXISTING_COUNT=${EXISTING_COUNT//[^0-9]/}
if [ "${EXISTING_COUNT:-0}" -gt 0 ]; then
  echo "Detected existing schema objects (${EXISTING_COUNT}). To run migrations from a clean database, either:"
  echo "  • Remove the compose volumes and retry: docker compose down -v && docker compose up --abort-on-container-exit --exit-code-from migrate"
  echo "  • Or drop the public schema manually: psql \"$PSQL_URL\" -c \"DROP SCHEMA public CASCADE; CREATE SCHEMA public;\""
  echo "If you intended to re-apply migrations to an existing database, ensure the migration files are idempotent; exiting."
  exit 1
fi

echo "Applying migrations..."
psql "$PSQL_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/001_init.sql

echo "Running smoke checks..."
psql "$PSQL_URL" -c "SELECT to_regclass('public.users') AS users_table, to_regclass('public.jobs') AS jobs_table;"

# Run schema smoke tests if present
if [ -f tests/schema_smoke.sql ]; then
  echo "Running schema smoke tests..."
  psql "$PSQL_URL" -v ON_ERROR_STOP=1 -f tests/schema_smoke.sql
fi

echo "Done."
