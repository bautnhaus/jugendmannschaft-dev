-- AP03 security corrections: enforce club membership, team boundaries and atomic player-position writes.
-- Intended for DEV first. Review before any PROD application.

CREATE OR REPLACE FUNCTION public.admin_add_team_role(
  p_team_id uuid,
  p_user_id uuid,
  p_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
DECLARE
  v_club_id uuid;
  v_existing_club_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_team_admin(auth.uid(), p_team_id) THEN
    RAISE EXCEPTION 'Nicht berechtigt' USING errcode = '42501';
  END IF;

  IF p_role NOT IN ('admin', 'trainer') THEN
    RAISE EXCEPTION 'Ungültige Teamrolle' USING errcode = '22023';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p_user_id) THEN
    RAISE EXCEPTION 'Benutzer nicht gefunden' USING errcode = '22023';
  END IF;

  SELECT t.club_id INTO v_club_id
  FROM public.teams t
  WHERE t.id = p_team_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Mannschaft nicht gefunden' USING errcode = '22023';
  END IF;

  IF v_club_id IS NOT NULL THEN
    SELECT cm.club_id INTO v_existing_club_id
    FROM public.club_members cm
    WHERE cm.user_id = p_user_id;

    IF v_existing_club_id IS NOT NULL AND v_existing_club_id <> v_club_id THEN
      RAISE EXCEPTION 'Benutzer ist bereits einem anderen Verein zugeordnet'
        USING errcode = '23514';
    END IF;

    -- A team invitation may add the target as a regular club member, never as club admin.
    INSERT INTO public.club_members(user_id, club_id)
    VALUES (p_user_id, v_club_id)
    ON CONFLICT (user_id) DO NOTHING;

    IF NOT EXISTS (
      SELECT 1 FROM public.club_members cm
      WHERE cm.user_id = p_user_id AND cm.club_id = v_club_id
    ) THEN
      RAISE EXCEPTION 'Vereinszugehörigkeit konnte nicht bestätigt werden'
        USING errcode = '23514';
    END IF;
  END IF;

  INSERT INTO public.team_members(team_id, user_id, role)
  VALUES (p_team_id, p_user_id, p_role)
  ON CONFLICT (team_id, user_id) DO NOTHING;

  INSERT INTO public.team_member_roles(team_id, user_id, role)
  VALUES (p_team_id, p_user_id, p_role)
  ON CONFLICT (team_id, user_id, role) DO NOTHING;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_add_team_role(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_add_team_role(uuid, uuid, text) TO authenticated;

-- A player's team_id is assigned at creation and cannot be changed through ordinary player edits.
CREATE OR REPLACE FUNCTION public.prevent_player_team_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF NEW.team_id IS DISTINCT FROM OLD.team_id THEN
    RAISE EXCEPTION 'Die Mannschaftszuordnung eines Spielers kann nicht direkt geändert werden.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS prevent_player_team_change ON public.players;
CREATE TRIGGER prevent_player_team_change
BEFORE UPDATE OF team_id ON public.players
FOR EACH ROW EXECUTE FUNCTION public.prevent_player_team_change();

-- Trainers may maintain positions for players in their own team, but cannot cross-link teams.
DROP POLICY IF EXISTS player_positions_insert ON public.player_positions;
CREATE POLICY player_positions_insert ON public.player_positions
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.players p
    JOIN public.positions pos ON pos.id = player_positions.position_id
    WHERE p.id = player_positions.player_id
      AND p.team_id = pos.team_id
      AND public.is_team_member(p.team_id)
  )
);

DROP POLICY IF EXISTS player_positions_delete ON public.player_positions;
CREATE POLICY player_positions_delete ON public.player_positions
FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.players p
    WHERE p.id = player_positions.player_id
      AND public.is_team_member(p.team_id)
  )
);

-- Matchday attendance DELETE must enforce the same player/matchday team consistency as INSERT.
DROP POLICY IF EXISTS matchday_attendance_delete ON public.matchday_attendance;
CREATE POLICY matchday_attendance_delete ON public.matchday_attendance
FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.matchdays m
    JOIN public.players p ON p.id = matchday_attendance.player_id
    WHERE m.id = matchday_attendance.matchday_id
      AND p.team_id = m.team_id
      AND public.is_team_member(m.team_id)
  )
);

-- Atomic create/update of a player and all its position links.
CREATE OR REPLACE FUNCTION public.save_player_with_positions(
  p_player_id uuid,
  p_team_id uuid,
  p_name text,
  p_first_name text,
  p_last_name text,
  p_birth_year integer,
  p_preferred_foot text,
  p_level text,
  p_photo_data text,
  p_notes text,
  p_position_ids uuid[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_team_id uuid;
  v_player_id uuid;
  v_position_ids uuid[] := COALESCE(p_position_ids, ARRAY[]::uuid[]);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Nicht angemeldet' USING errcode = '42501';
  END IF;

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Name fehlt' USING errcode = '22023';
  END IF;
  IF p_level IS NOT NULL AND p_level NOT IN ('Einsteiger', 'Fortgeschritten', 'Stark', 'Profi') THEN
    RAISE EXCEPTION 'Ungültiges Level' USING errcode = '22023';
  END IF;
  IF p_preferred_foot IS NOT NULL AND p_preferred_foot NOT IN ('links', 'rechts', 'beidfüßig') THEN
    RAISE EXCEPTION 'Ungültiger bevorzugter Fuß' USING errcode = '22023';
  END IF;
  IF p_birth_year IS NOT NULL AND (p_birth_year < 1900 OR p_birth_year > EXTRACT(YEAR FROM CURRENT_DATE)::integer) THEN
    RAISE EXCEPTION 'Ungültiges Geburtsjahr' USING errcode = '22023';
  END IF;

  IF p_player_id IS NULL THEN
    v_team_id := p_team_id;
    IF v_team_id IS NULL OR NOT public.is_team_member(v_team_id) THEN
      RAISE EXCEPTION 'Keine Berechtigung für diese Mannschaft' USING errcode = '42501';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM unnest(v_position_ids) AS requested(position_id)
      LEFT JOIN public.positions pos ON pos.id = requested.position_id
      WHERE pos.id IS NULL OR pos.team_id <> v_team_id
    ) THEN
      RAISE EXCEPTION 'Mindestens eine Position gehört nicht zur Mannschaft' USING errcode = '23514';
    END IF;

    INSERT INTO public.players(team_id, name, first_name, last_name, birth_year, preferred_foot, level, photo_data, notes, active)
    VALUES (v_team_id, p_name, p_first_name, p_last_name, p_birth_year, p_preferred_foot, p_level, p_photo_data, p_notes, true)
    RETURNING id INTO v_player_id;
  ELSE
    SELECT p.team_id INTO v_team_id
    FROM public.players p
    WHERE p.id = p_player_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Spieler nicht gefunden' USING errcode = 'P0002';
    END IF;
    IF NOT public.is_team_member(v_team_id) THEN
      RAISE EXCEPTION 'Keine Berechtigung für diesen Spieler' USING errcode = '42501';
    END IF;
    IF p_team_id IS NOT NULL AND p_team_id <> v_team_id THEN
      RAISE EXCEPTION 'Die Mannschaftszuordnung eines Spielers kann nicht geändert werden' USING errcode = '42501';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM unnest(v_position_ids) AS requested(position_id)
      LEFT JOIN public.positions pos ON pos.id = requested.position_id
      WHERE pos.id IS NULL OR pos.team_id <> v_team_id
    ) THEN
      RAISE EXCEPTION 'Mindestens eine Position gehört nicht zur Mannschaft' USING errcode = '23514';
    END IF;

    UPDATE public.players
    SET name = p_name,
        first_name = p_first_name,
        last_name = p_last_name,
        birth_year = p_birth_year,
        preferred_foot = p_preferred_foot,
        level = p_level,
        photo_data = p_photo_data,
        notes = p_notes
    WHERE id = p_player_id;

    v_player_id := p_player_id;
  END IF;

  DELETE FROM public.player_positions WHERE player_id = v_player_id;

  INSERT INTO public.player_positions(player_id, position_id)
  SELECT v_player_id, requested.position_id
  FROM (
    SELECT DISTINCT unnest(v_position_ids) AS position_id
  ) requested;

  RETURN v_player_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.save_player_with_positions(uuid, uuid, text, text, text, integer, text, text, text, text, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_player_with_positions(uuid, uuid, text, text, text, integer, text, text, text, text, uuid[]) TO authenticated;
