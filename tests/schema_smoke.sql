-- Simple smoke tests to validate essential schema objects and RLS
DO $$
BEGIN
  IF to_regclass('public.users') IS NULL THEN
    RAISE EXCEPTION 'Missing table public.users';
  END IF;
  IF to_regclass('public.subscriptions') IS NULL THEN
    RAISE EXCEPTION 'Missing table public.subscriptions';
  END IF;
  IF to_regclass('public.invoices') IS NULL THEN
    RAISE EXCEPTION 'Missing table public.invoices';
  END IF;
  IF to_regclass('public.jobs') IS NULL THEN
    RAISE EXCEPTION 'Missing table public.jobs';
  END IF;
  IF to_regclass('public.proof_entries') IS NULL THEN
    RAISE EXCEPTION 'Missing table public.proof_entries';
  END IF;

  -- Functions & triggers
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_new_user') THEN
    RAISE EXCEPTION 'Missing function: handle_new_user';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') THEN
    RAISE EXCEPTION 'Missing trigger: on_auth_user_created';
  END IF;

  -- Policy existence check (example)
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polname = 'Users can view own profile') THEN
    RAISE EXCEPTION 'Missing policy: Users can view own profile';
  END IF;

  -- Ensure RLS is enabled on key tables
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class c
    WHERE c.relname = 'users' AND c.relrowsecurity
  ) THEN
    RAISE EXCEPTION 'RLS not enabled on table: users';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class c
    WHERE c.relname = 'jobs' AND c.relrowsecurity
  ) THEN
    RAISE EXCEPTION 'RLS not enabled on table: jobs';
  END IF;

  -- If we reach here, tests passed
  RAISE NOTICE 'Schema smoke tests passed';
END;
$$;
