-- Minimal auth schema & helpers for local testing
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY,
  email TEXT,
  raw_user_meta_data JSONB DEFAULT '{}'::JSONB,
  email_confirmed_at TIMESTAMPTZ
);

-- Stub for auth.uid(): returns NULL by default (policies will still be present and RLS can be checked)
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID LANGUAGE SQL STABLE AS $$
  SELECT NULL::uuid;
$$;

-- Optionally insert a dummy user for manual tests
INSERT INTO auth.users (id, email) SELECT '00000000-0000-0000-0000-000000000000'::uuid, 'local@example.com'
  WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000000');
