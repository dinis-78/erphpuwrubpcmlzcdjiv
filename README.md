# ProJob Shield — SQL schema & Supabase migrations

This repository contains the Postgres schema for ProJob Shield (designed for Supabase with Auth & RLS).

**What's added:**

- `supabase/migrations/001_init.sql` — canonical migration created from this SQL
- `scripts/test_migrations.sh` — local test runner that applies the migration against a local Postgres service
- `.github/workflows/supabase-migrations.yml` — GitHub Actions to test migrations on PRs and to deploy them to Supabase on push to `main`

**Before merging to `main` (required):**

- Add these GitHub repository secrets: `SUPABASE_URL` (project ref), `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ACCESS_TOKEN`.

To run locally with Docker Compose (recommended):

1. Start Postgres and run the migration in a single step:

   ```bash
   docker compose up --abort-on-container-exit --exit-code-from migrate
   ```

2. If you prefer to run Postgres separately, you can still run the test script directly after starting the DB:

   ```bash
   docker run --rm -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15
   ./scripts/test_migrations.sh
   ```

Makefile convenience targets:

- `make migrate` — start Postgres and run migrations+tests (recommended)
- `make up` — start the compose services interactively
- `make down` — stop the compose services

Run a quick test:

```bash
make migrate
```


-- ==========================================
-- ProJob Shield – Full SQL Setup
-- Includes existing tables, triggers, RLS, and updated subscription tiers
-- ==========================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  avatar_url TEXT,
  phone TEXT,
  company_name TEXT,
  subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'starter', 'enterprise')),
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  subscription_status TEXT DEFAULT 'inactive',
  subscription_period_end TIMESTAMPTZ,
  role TEXT DEFAULT 'client' CHECK (role IN ('client', 'contractor', 'admin')),
  email_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  stripe_subscription_id TEXT UNIQUE,
  stripe_customer_id TEXT,
  status TEXT NOT NULL,
  price_id TEXT,
  quantity INTEGER DEFAULT 1,
  cancel_at_period_end BOOLEAN DEFAULT false,
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  canceled_at TIMESTAMPTZ,
  trial_start TIMESTAMPTZ,
  trial_end TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Invoices table
CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  stripe_invoice_id TEXT UNIQUE,
  stripe_subscription_id TEXT,
  amount_due INTEGER NOT NULL,
  amount_paid INTEGER DEFAULT 0,
  currency TEXT DEFAULT 'usd',
  status TEXT NOT NULL,
  invoice_pdf TEXT,
  hosted_invoice_url TEXT,
  period_start TIMESTAMPTZ,
  period_end TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Jobs table
CREATE TABLE IF NOT EXISTS public.jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  client_id UUID REFERENCES public.users(id),
  contractor_id UUID REFERENCES public.users(id),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'disputed', 'cancelled')),
  budget DECIMAL(10,2),
  currency TEXT DEFAULT 'USD',
  deadline TIMESTAMPTZ,
  location TEXT,
  category TEXT,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Proof entries table
CREATE TABLE IF NOT EXISTS public.proof_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id),
  type TEXT NOT NULL CHECK (type IN ('photo', 'video', 'document', 'signature', 'checklist', 'note')),
  title TEXT,
  description TEXT,
  file_url TEXT,
  file_type TEXT,
  file_size INTEGER,
  metadata JSONB DEFAULT '{}',
  location_lat DECIMAL(10,8),
  location_lng DECIMAL(11,8),
  location_address TEXT,
  captured_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proof_entries ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users
CREATE POLICY "Users can view own profile" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- RLS Policies for subscriptions
CREATE POLICY "Users can view own subscriptions" ON public.subscriptions
  FOR SELECT USING (auth.uid() = user_id);

-- RLS Policies for invoices
CREATE POLICY "Users can view own invoices" ON public.invoices
  FOR SELECT USING (auth.uid() = user_id);

-- RLS Policies for jobs
CREATE POLICY "Users can view their jobs" ON public.jobs
  FOR SELECT USING (auth.uid() = client_id OR auth.uid() = contractor_id);

CREATE POLICY "Clients can create jobs" ON public.jobs
  FOR INSERT WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can update their jobs" ON public.jobs
  FOR UPDATE USING (auth.uid() = client_id OR auth.uid() = contractor_id);

-- RLS Policies for proof_entries
CREATE POLICY "Users can view proofs for their jobs" ON public.proof_entries
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.jobs 
      WHERE jobs.id = proof_entries.job_id 
      AND (jobs.client_id = auth.uid() OR jobs.contractor_id = auth.uid())
    )
  );

CREATE POLICY "Users can create proofs" ON public.proof_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_stripe_customer ON public.users(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe ON public.subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_invoices_user ON public.invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_jobs_client ON public.jobs(client_id);
CREATE INDEX IF NOT EXISTS idx_jobs_contractor ON public.jobs(contractor_id);
CREATE INDEX IF NOT EXISTS idx_proof_entries_job ON public.proof_entries(job_id);

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, avatar_url, email_verified)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name'),
    NEW.raw_user_meta_data->>'avatar_url',
    (NEW.email_confirmed_at IS NOT NULL)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to sync email verification status
CREATE OR REPLACE FUNCTION public.handle_email_verification_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL AND (OLD.email_confirmed_at IS NULL) THEN
    UPDATE public.users
    SET 
      email_verified = true,
      updated_at = NOW()
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for email verification sync
DROP TRIGGER IF EXISTS on_auth_user_email_verified ON auth.users;
CREATE TRIGGER on_auth_user_email_verified
  AFTER UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_email_verification_sync();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_jobs_updated_at
  BEFORE UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ==========================================
-- Subscription Tiers Example
-- Starter: $29/month (up to 3 new projects/month)
-- Enterprise: $199/month (unlimited projects)
-- ==========================================

-- Add a trigger to enforce Starter plan 3 new projects/month limit
CREATE OR REPLACE FUNCTION public.starter_project_limit()
RETURNS TRIGGER AS $$
DECLARE
    project_count INT;
BEGIN
    IF (SELECT subscription_tier FROM public.users WHERE id = NEW.client_id) = 'starter' THEN
        SELECT COUNT(*) INTO project_count
        FROM public.jobs
        WHERE client_id = NEW.client_id
        AND created_at >= date_trunc('month', CURRENT_DATE);

        IF project_count >= 3 THEN
            RAISE EXCEPTION 'Starter plan allows only 3 new projects per month';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_starter_limit ON public.jobs;
CREATE TRIGGER check_starter_limit
BEFORE INSERT ON public.jobs
FOR EACH ROW
EXECUTE FUNCTION public.starter_project_limit();

