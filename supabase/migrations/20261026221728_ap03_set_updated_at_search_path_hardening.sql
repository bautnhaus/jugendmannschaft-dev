-- AP03 DEV: pin the search_path for the trigger utility function.
ALTER FUNCTION public.set_updated_at() SET search_path = pg_catalog, public;
