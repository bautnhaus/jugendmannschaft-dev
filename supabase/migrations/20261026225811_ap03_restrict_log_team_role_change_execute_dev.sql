-- AP03 DEV: this function is invoked by table triggers, not directly through the app RPC API.
REVOKE EXECUTE ON FUNCTION public.log_team_role_change() FROM PUBLIC, anon, authenticated;
