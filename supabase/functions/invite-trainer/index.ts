import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://bautnhaus.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const respond = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200, headers: corsHeaders });
  if (req.method !== "POST") return respond({ error: "Nur POST-Anfragen sind erlaubt." }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const secretKeysRaw = Deno.env.get("SUPABASE_SECRET_KEYS");
    const publishableKeysRaw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
    let anonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
    if (!anonKey && publishableKeysRaw) {
      try { anonKey = JSON.parse(publishableKeysRaw).default || ""; } catch { /* handled below */ }
    }
    if (!url || !anonKey || !secretKeysRaw) {
      console.error("Erforderliche Supabase-Umgebungsvariablen fehlen.");
      return respond({ error: "Die Einladungsfunktion ist nicht korrekt konfiguriert." }, 500);
    }

    let secretKeys: Record<string, string>;
    try { secretKeys = JSON.parse(secretKeysRaw); }
    catch { return respond({ error: "Supabase Secret Key hat kein gültiges Format." }, 500); }
    const secretKey = secretKeys.default;
    if (!secretKey) return respond({ error: "Kein Standard-Secret-Key gefunden." }, 500);

    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return respond({ error: "Nicht angemeldet." }, 401);

    // This client preserves the caller's JWT so auth.uid() inside authorization
    // RPCs refers to the signed-in user, not the service role.
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const adminClient = createClient(url, secretKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return respond({ error: "Ungültige Anmeldung." }, 401);

    let body: { email?: string; role?: string; team_id?: string };
    try { body = await req.json(); }
    catch { return respond({ error: "Ungültige Anfrage-Daten." }, 400); }

    const email = String(body.email || "").trim().toLowerCase();
    const role = body.role === "admin" ? "admin" : body.role === "trainer" ? "trainer" : "";
    const teamId = String(body.team_id || "").trim();
    if (!email || !teamId || !role) {
      return respond({ error: "E-Mail-Adresse, Mannschaft und gültige Rolle fehlen." }, 400);
    }

    const { data: isAdmin, error: permissionError } = await userClient
      .rpc("is_team_admin", { p_team_id: teamId });
    if (permissionError) {
      console.error("Berechtigungsprüfung fehlgeschlagen:", permissionError);
      return respond({ error: "Die Berechtigung konnte nicht geprüft werden." }, 500);
    }
    if (!isAdmin) return respond({ error: "Nur ein Team-Admin kann Personen einladen." }, 403);

    // Search existing accounts. Supabase admin listUsers is paginated; inspect
    // up to 1000 accounts as the current implementation does. If this project
    // grows beyond that, replace with a dedicated server-side email lookup.
    const { data: existingUsers, error: listError } = await adminClient.auth.admin.listUsers({
      page: 1, perPage: 1000,
    });
    if (listError) {
      console.error("Vorhandene Benutzer konnten nicht geprüft werden:", listError);
      return respond({ error: "Vorhandene Benutzer konnten nicht geprüft werden." }, 500);
    }
    let targetUser = existingUsers.users.find((u) => u.email?.toLowerCase() === email) ?? null;
    let existingUser = Boolean(targetUser);

    if (!targetUser) {
      const { data: inviteData, error: inviteError } =
        await adminClient.auth.admin.inviteUserByEmail(email, {
          redirectTo: "https://bautnhaus.github.io/jugendmannschaft/",
        });
      if (inviteError || !inviteData.user) {
        console.error("Einladung fehlgeschlagen:", inviteError);
        return respond({ error: inviteError?.message || "Die Einladung konnte nicht verschickt werden." }, 500);
      }
      targetUser = inviteData.user;
    }

    // Add exactly one role; never upsert/overwrite the person's other role.
    // The RPC validates the caller's team-admin rights and inserts team membership.
    const { error: roleError } = await userClient.rpc("admin_add_team_role", {
      p_team_id: teamId,
      p_user_id: targetUser.id,
      p_role: role,
    });
    if (roleError) {
      console.error("Teamrolle konnte nicht gespeichert werden:", roleError);
      return respond({
        error: existingUser
          ? "Der vorhandene Benutzer konnte nicht hinzugefügt werden: " + roleError.message
          : "Einladung wurde versendet, aber die Teamrolle konnte nicht gespeichert werden. Bitte Admin kontaktieren.",
      }, 500);
    }

    return respond({
      success: true,
      existing_user: existingUser,
      message: existingUser
        ? "Der vorhandene Benutzer wurde der Mannschaft mit der ausgewählten Rolle hinzugefügt."
        : "Die Einladung wurde versendet und die Teamrolle wurde gespeichert.",
    });
  } catch (error) {
    console.error("Unerwarteter Fehler in invite-trainer:", error);
    return respond({ error: "Bei der Einladung ist ein unerwarteter Fehler aufgetreten." }, 500);
  }
});
