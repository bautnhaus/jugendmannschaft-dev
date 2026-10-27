-- AP03 DEV: trigger functions are not public RPC endpoints.
REVOKE EXECUTE ON FUNCTION public.protect_player_active_status() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.require_active_player_for_new_assignment() FROM PUBLIC, anon, authenticated;
