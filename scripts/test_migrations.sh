#!/usr/bin/env bash
set -euo pipefail

PSQL_URL="postgresql://postgres:postgres@localhost:5432/postgres"

echo "Waiting for Postgres to be ready..."
until pg_isready -h localhost -p 5432 -U postgres >/dev/null 2>&1; do
  sleep 1
done

echo "Applying migrations..."
psql "$PSQL_URL" -f supabase/migrations/001_init.sql

echo "Running smoke checks..."
psql "$PSQL_URL" -c "SELECT to_regclass('public.users') AS users_table, to_regclass('public.jobs') AS jobs_table;"

echo "Done."
