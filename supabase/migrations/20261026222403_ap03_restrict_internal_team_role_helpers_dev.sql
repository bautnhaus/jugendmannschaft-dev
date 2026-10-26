-- AP03 DEV: prevent direct RPC access to helpers that accept arbitrary user IDs.
-- The one-argument helpers used directly by RLS remain unchanged.
REVOKE EXECUTE ON FUNCTION public.is_team_admin(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_team_member(uuid, uuid) FROM PUBLIC, anon, authenticated;
