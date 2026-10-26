-- AP03 hardening: pin the trigger function search_path.
-- Applied directly to the DEV Supabase project on 2026-10-26; this file records
-- the same change in version control for reproducibility.
ALTER FUNCTION public.set_updated_at() SET search_path = pg_catalog, public;
