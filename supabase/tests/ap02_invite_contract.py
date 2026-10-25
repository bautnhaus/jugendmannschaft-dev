from pathlib import Path

source = Path("supabase/functions/invite-trainer/index.ts").read_text()

required = {
    "only POST or preflight is accepted": 'if (req.method !== "POST")',
    "authorization bearer token is required": 'if (!authHeader?.startsWith("Bearer "))',
    "caller JWT is validated": "userClient.auth.getUser()",
    "requested role is allow-listed": 'body.role === "admin" ? "admin" : body.role === "trainer" ? "trainer" : ""',
    "team-admin authorization RPC is used": '.rpc("is_team_admin", { p_team_id: teamId })',
    "role is added with additive role RPC": '.rpc("admin_add_team_role", {',
    "request caller's JWT is used for role RPC": "const { error: roleError } = await userClient.rpc(",
    "service client is used only for admin auth operations": "adminClient.auth.admin.inviteUserByEmail",
}

missing = [label for label, fragment in required.items() if fragment not in source]
if missing:
    raise SystemExit("Invite function contract checks failed: " + "; ".join(missing))

if "add_team_member_by_email" in source or "get_team_trainers(" in source:
    raise SystemExit("Invite function still references a legacy single-role RPC")

admin_check = source.find('.rpc("is_team_admin", { p_team_id: teamId })')
invite_call = source.find("adminClient.auth.admin.inviteUserByEmail")
role_write = source.find('.rpc("admin_add_team_role", {')
if not (0 <= admin_check < invite_call < role_write):
    raise SystemExit("Expected order is authorization check, invitation, then additive role write")

print(f"Invite function contract checks passed ({len(required)} assertions plus ordering/legacy checks).")
