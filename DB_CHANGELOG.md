# Jugendmannschaft – Datenbankänderungs- und Verifikationsprotokoll

**Stand:** 04.11.2026  
**Geltungsbereich:** Dokumentierte Änderungen und Prüfungen in Supabase DEV und PROD; die jeweilige Umgebung und Nachweisgrenze sind pro Eintrag maßgeblich.  
**Führende Fassung:** Branch `develop`. Dieses Dokument beschreibt Datenbankobjekte, historische Änderungen und Verifikationsbefunde; es ist kein vollständiges Ausführungsjournal. Jede tatsächlich ausgeführte schreibende SQL-Anweisung – auch manuell im Supabase SQL Editor und unabhängig davon, ob eine Migrationsdatei existiert – muss zusätzlich mit eigenem Ausführungsnachweis in `DB_MIGRATION_LOG.md` erfasst werden. DEV und PROD sind getrennt zu dokumentieren. Dieses Protokoll ist kein Live-Schema-Dump und ersetzt weder Originalmigrationen noch aktuelle Abfragen der Zielumgebung.

**Historischer Ausgangsstand:** 09.10.2026  
**Umgebung:** Supabase DEV  
**Zweck:** Dokumentation des nachweislich abgeglichenen DEV-Bestands als Grundlage für einen späteren kontrollierten PROD-Rollout. Dieses Protokoll dokumentiert die bekannten DEV-Änderungen bis 09.10.2026; es ist kein vollständiger Schema-, RLS- oder Policy-Abgleich.

## DB-DEV-001 – Schutz des letzten Administrators (E16.2)

- **Status:** In DEV implementiert und funktional getestet.
- **Tabelle:** `public.team_members`
- **Funktion:** `public.prevent_last_team_admin_removal()`
- **Trigger:** `prevent_last_team_admin_removal`
- **Ereignisse:** `AFTER DELETE OR UPDATE`, je Zeile
- **Triggertyp:** Constraint-Trigger, `DEFERRABLE INITIALLY DEFERRED`
- **Aktivierung:** aktiv (`tgenabled = 'O'`, immer aktiviert)
- **Funktion:** `SECURITY DEFINER`, `search_path` = `pg_catalog, public`
- **Rechte:** EXECUTE für `PUBLIC`, `anon` und `authenticated` nicht gewährt. ACL bestätigt EXECUTE für `postgres` und `service_role`.

### Zweck und Funktionsweise

Die Datenbank verhindert, dass die letzte Admin-Mitgliedschaft eines bestehenden Teams gelöscht oder herabgestuft wird. Die Regel ist unabhängig von Frontend-Prüfungen. Nicht-Admin-Mitgliedschaften werden nicht geprüft. Bei einem UPDATE, bei dem dieselbe Mitgliedschaft im selben Team Admin bleibt, wird die Prüfung übersprungen. Die Funktion sperrt die Teamzeile mit `FOR UPDATE`, prüft, ob das Team noch existiert, und lässt eine vollständige Teamlöschung zu. Andernfalls prüft sie, ob am Transaktionsende noch mindestens ein Admin vorhanden ist. Falls nicht, löst sie eine Exception mit SQLSTATE `23514` und folgender Meldung aus:

> Die letzte Admin-Mitgliedschaft einer Mannschaft kann nicht entfernt oder herabgestuft werden.

### In DEV ausgelesene Triggerdefinition

```sql
CREATE CONSTRAINT TRIGGER prevent_last_team_admin_removal
AFTER DELETE OR UPDATE ON public.team_members
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION prevent_last_team_admin_removal();
```

### In DEV ausgelesene Funktionsdefinition

```sql
CREATE OR REPLACE FUNCTION public.prevent_last_team_admin_removal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
    v_team_exists boolean;
    v_admin_exists boolean;
BEGIN
    IF OLD.role IS DISTINCT FROM 'admin' THEN
        RETURN NULL;
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.role = 'admin'
       AND NEW.team_id = OLD.team_id THEN
        RETURN NULL;
    END IF;

    PERFORM 1
    FROM public.teams
    WHERE id = OLD.team_id
    FOR UPDATE;
    v_team_exists := FOUND;

    IF NOT v_team_exists THEN
        RETURN NULL;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.team_members
        WHERE team_id = OLD.team_id
          AND role = 'admin'
    )
    INTO v_admin_exists;

    IF NOT v_admin_exists THEN
        RAISE EXCEPTION
            'Die letzte Admin-Mitgliedschaft einer Mannschaft kann nicht entfernt oder herabgestuft werden.'
            USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$function$;
```

### Verifikation und Testumfang

1. `pg_get_functiondef()` bestätigte die Funktionsdefinition.
2. Die Triggerabfrage bestätigte `AFTER DELETE OR UPDATE`, Constraint-Trigger, `DEFERRABLE`, `INITIALLY DEFERRED` und Aktivierung `O`.
3. Die Rechteabfrage bestätigte `SECURITY DEFINER`, keine EXECUTE-Rechte für `PUBLIC`, `anon` und `authenticated`; die ACL zeigte `postgres=X/postgres` und `service_role=X/postgres`.
4. Ein realer Löschversuch des einzigen Admin-Kontos über die DEV-App wurde mit der erwarteten Meldung abgewiesen.
5. Die anschließende Kontrolle bestätigte, dass alle drei Teammitgliedschaften erhalten blieben; Testrollen wurden wieder auf zwei Admins und einen Trainer gesetzt.
6. Ein gesonderter Parallelitätstest mit gleichzeitig laufenden Transaktionen wurde **nicht** durchgeführt. Die `FOR UPDATE`-Sperre ist vorhanden, ihre Wirkung unter tatsächlicher Konkurrenz ist aber nicht separat nachgewiesen.

**PROD:** Nicht übertragen. Vor einem Rollout sind Funktions-, Trigger-, Rechte- und Schema-Bestand in PROD separat zu prüfen. Diese Dokumentation ist ein Bestandsnachweis, keine freigegebene ausführbare Migration. Eine spätere Migration benötigt Review, DEV-Abgleich und ausdrückliche Freigabe.

## DB-DEV-002 – Erweiterung der Spielerstammdaten (E03)

- **Umgebung:** DEV
- **Status:** Spalten und Constraints direkt in DEV abgefragt
- **Tabelle:** `public.players`
- **Felder:** `birth_year` (Geburtsjahr, kein vollständiges Geburtsdatum) und `preferred_foot` (bevorzugter Fuß)
- **PROD:** Separat zu prüfen; keine PROD-Migration bestätigt.

### Tatsächliche Spaltenstruktur aus DEV

| Spalte | Datentyp | NULL erlaubt | Standardwert |
|---|---|---|---|
| `id` | `uuid` | Nein | `gen_random_uuid()` |
| `team_id` | `uuid` | Nein | keiner |
| `name` | `text` | Nein | keiner |
| `level` | `text` | Ja | keiner |
| `active` | `boolean` | Nein | `true` |
| `created_at` | `timestamp with time zone` | Nein | `now()` |
| `updated_at` | `timestamp with time zone` | Nein | `now()` |
| `photo_data` | `text` | Ja | keiner |
| `first_name` | `text` | Ja | keiner |
| `last_name` | `text` | Ja | keiner |
| `notes` | `text` | Ja | `''::text` |
| `birth_year` | `integer` | Ja | keiner |
| `preferred_foot` | `text` | Ja | keiner |

### Tatsächliche Constraints aus DEV

| Constraint | Typ | Regel |
|---|---|---|
| `players_birth_year_check` | CHECK | `birth_year IS NULL OR (birth_year >= 1900 AND birth_year <= EXTRACT(year FROM CURRENT_DATE)::integer)` |
| `players_level_check` | CHECK | `level IS NULL OR level = ANY (ARRAY['Einsteiger', 'Fortgeschritten', 'Stark', 'Profi'])` |
| `players_preferred_foot_check` | CHECK | `preferred_foot IS NULL OR preferred_foot = ANY (ARRAY['links', 'rechts', 'beidfüßig'])` |
| `players_team_id_fkey` | FOREIGN KEY | `team_id` → `teams(id) ON DELETE CASCADE` |
| `players_pkey` | PRIMARY KEY | `PRIMARY KEY (id)` |

Die verbindliche Level-Reihenfolge ist **Einsteiger → Fortgeschritten → Stark → Profi**. Diese Begriffe entsprechen der vom Nutzer bestätigten Frontend-Terminologie und dem in DEV ausgelesenen CHECK-Constraint. Eine Datenbankänderung der Level-Bezeichnungen ist daher nicht erforderlich. Die vollständige Prüfung aller Frontend-Verwendungen wurde in diesem Schritt nicht wiederholt.

### Nachweisgrenze

Spalten und Constraints sind als aktueller DEV-Bestand ausgelesen. Die historische Reihenfolge und der exakte DDL-Text der ursprünglichen E03-Migrationen sind damit nicht rekonstruiert. Dieser Abschnitt ist daher ein Bestandsnachweis, kein ausführbares SQL-Migrationsskript. Vor einer PROD-Übernahme sind historische Änderungen soweit verfügbar zu rekonstruieren und DEV und PROD separat abzugleichen.

## Änderungsregister

| ID | Änderung | Umgebung | Status | PROD |
|---|---|---|---|---|
| DB-DEV-001 | Letzten Team-Admin gegen Entfernen/Herabstufen absichern (E16.2) | DEV | Implementiert und funktional getestet; Parallelitätstest offen | Nicht übertragen |
| DB-DEV-002 | Spielerprofil um Geburtsjahr und bevorzugten Fuß erweitert (E03); Spalten und Constraints abgeglichen | DEV | Bestandsdefinitionen abgefragt; historische Migration nicht vollständig rekonstruiert | Separat zu prüfen |

## Pflegekonvention

Jede Datenbankänderung erhält eine eindeutige ID, Datum, Umgebung, betroffene Objekte, Zweck, versioniertes SQL, Ausführungsergebnis, Tests und Rolloutstatus. DEV und PROD sind getrennt zu dokumentieren. Eine DEV-Änderung gilt nie automatisch als in PROD angewendet. Keine Zugangsdaten, Tokens oder Service-Role-Keys dokumentieren.


## DB-DEV-003 – E07 Trainingsverwaltung / Trainingsserien und Rückmeldungen

- **Umgebung:** DEV
- **Status:** Migration ausgeführt; Kernfunktionalität im DEV getestet
- **PROD:** Nicht übertragen

### Zweck

Erweiterung der Trainingsverwaltung um Trainingsserien, zusätzliche Termindaten und die persistente Erfassung geplanter Spieler-Rückmeldungen.

### Betroffene Objekte

- `public.training_series`
- `public.trainings`
- `public.training_responses`

### Ausgeführte Datenbankänderungen

`public.training_series` wurde als eigene Tabelle angelegt. Dokumentiert sind insbesondere:

- `id` als UUID-Primärschlüssel
- `team_id` mit Bezug zu `teams`
- `start_date`, `end_date`
- `start_time`
- `duration_minutes`
- `weekdays`
- `location`
- `created_at`, `updated_at`
- Prüfungen für Datumsbereich, Dauer und Wochentage

`public.trainings` wurde um folgende Felder erweitert:

- `start_time`
- `duration_minutes`
- `location`
- `status` mit Standard `planned`
- `note`
- `series_id` mit Bezug zu `training_series` und `ON DELETE SET NULL`

Für `training_series` wurden RLS sowie Select/Insert/Update/Delete-Policies auf Basis der Teammitgliedschaft eingerichtet und verifiziert.

Zusätzlich wurde `public.training_responses` angelegt mit:

- `training_id`
- `player_id`
- `status` mit `open`, `yes`, `no`
- `created_at`

Der Primärschlüssel besteht aus `training_id` und `player_id`. Für die Tabelle wurden Select/Insert/Update/Delete-Policies eingerichtet.

### Ausführung / Verifikation

Die E07-Migration wurde in DEV erfolgreich ausgeführt. Als sichtbarer Policy-Nachweis wurden die vier Policies von `training_series` für Delete, Insert, Select und Update bestätigt.

Die Spalten und Policies von `training_responses` wurden anschließend kontrolliert.

### Funktionaler DEV-Test

Über die DEV-App wurden Spieler-Rückmeldungen geändert. Anschließend wurde der aktuelle Frontendstand erneut geladen bzw. aktualisiert. Die gespeicherten Zu-/Absagen blieben erhalten.

Der zuletzt dokumentierte Testbestand enthielt 9 gespeicherte Rückmeldungen:

- 5 × `yes`
- 4 × `open`
- 0 × `no`

Dieser Bestand blieb beim anschließenden Frontend-Test unverändert.

Das Suchfeld der Trainings-Spielerliste wurde anschließend hinsichtlich der Darstellung auf iPhone Portrait und Landscape korrigiert und erneut geprüft.

### Offener technischer Punkt

Für `training_series.updated_at` ist weiterhin nicht abschließend verifiziert, ob ein `set_updated_at`-Trigger besteht.

Die Migration ist erfolgreich ausgeführt. Die Constraint-Erstellung ist nicht als beliebig wiederholbare Migration zu behandeln; vor einer erneuten Ausführung muss der tatsächliche DEV-Stand berücksichtigt werden.

- Nachtrag 29.10.2026: Das Vereinswappen wird nun nach erfolgreichem Upload sowohl in der Vereinsliste als auch im Vereinsdetail angezeigt. Die Darstellung verwendet `object-fit: contain` und einen transparenten Hintergrund, damit transparente PNGs nicht zugeschnitten oder mit einer deckenden Fläche überlagert werden. Commit: `0e1ca64e89ff4f56973ff6755b3e3ec01b847ecf` (Anzeige), danach wurden die Formular-Handler im selben Frontend wiederhergestellt und die Inline-JavaScript-Syntax erneut geprüft; Commit `158072225c9aecd071c515fb55eab95b943dc3b6`.

### PROD-Rollout

Keine Änderung an PROD. Vor einer PROD-Übernahme sind die exakten ausgeführten SQL-Anweisungen, der DEV-Teststatus und der PROD-Bestand getrennt abzugleichen.

## Änderungsregister – Ergänzung

| ID | Änderung | Umgebung | Status | PROD |
|---|---|---|---|---|
| DB-DEV-003 | E07: Trainingsserien, zusätzliche Trainingsfelder und persistente Trainings-Rückmeldungen | DEV | Migration ausgeführt; Kernfunktionalität und Persistenz im DEV getestet | Nicht übertragen |


## DB-DEV-004 – E07 Serienname und individuelle Termin-Overrides

- **Datum:** 09.10.2026 (Dokumentationsdatum; SQL-Ausführung zuvor in DEV bestätigt)
- **Umgebung:** Supabase DEV
- **Status:** SQL erfolgreich ausgeführt (`Success. No rows returned` laut Nutzer)
- **PROD:** Nicht übertragen

### Zweck

Seriennamen ermöglichen und individuell abweichende Werte eines Einzeltermins explizit kennzeichnen, damit spätere Serienänderungen individuelle Anpassungen respektieren können.

### Betroffene Objekte

- `public.training_series.name`
- `public.trainings.overrides`
- Constraint `trainings_overrides_object_chk`

### Ausgeführtes SQL

```sql
ALTER TABLE public.training_series
  ADD COLUMN name text;

ALTER TABLE public.trainings
  ADD COLUMN overrides jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.trainings
  ADD CONSTRAINT trainings_overrides_object_chk
  CHECK (jsonb_typeof(overrides) = 'object');
```

### Verifikation und fachliche Verwendung

- Die Ausführung in DEV wurde mit `Success. No rows returned` bestätigt.
- `overrides` ist ein JSONB-Objekt mit Standardwert `{}`; ein Beispiel für einen individuellen Ortswert ist `{"location": true}`.
- Wird ein Feld auf den Serienstandard zurückgesetzt, muss der zugehörige Override entfernt werden.
- Der Name der Serie kann als Standardname der zugehörigen Termine angezeigt werden; ein individuell abweichender Terminname soll bei Serienänderungen erhalten bleiben.
- Die Frontendlogik für Serienänderungen und die Anzeige des Trainingsnamens wurde anschließend mit der DEV-App getestet.

### PROD-Rollout

Nicht übertragen. Vor PROD sind die vorhandenen Spalten/Constraints separat zu prüfen und die Änderungen kontrolliert als Release-Migration zu übernehmen. Nicht blind erneut ausführen, da das `ADD CONSTRAINT` nicht mit `IF NOT EXISTS` abgesichert ist.

## Änderungsregister – Ergänzung

| ID | Änderung | Umgebung | Status | PROD |
|---|---|---|---|---|
| DB-DEV-004 | E07: Serienname und JSONB-Overrides für individuelle Terminwerte | DEV | SQL-Ausführung und anschließender fachlicher DEV-Test bestätigt | Nicht übertragen |


## DB-DEV-005 – Vereins- und Mannschaftsanlage (2026-10-29)

**Umgebung:** Supabase DEV, Projekt `pzazqvvoruqnqhcorbwx`  
**Status:** Migration ausgeführt; Schema-/Rechteprüfung bestätigt.  
**PROD:** Nicht übertragen.

### Ausgeführte Migrationen

- `20261029045927_club_team_creation_and_club_context_20261029`
- `20261029050011_club_team_creation_20261029`

Beide Einträge wurden in `supabase_migrations.schema_migrations` nachgewiesen. Die zweite Ausführung war idempotent ausgelegt und bestätigte denselben Zielzustand.

### Schemaänderungen

**`public.clubs`**
- `short_name`, `crest_path`
- Heimspielstätte: `home_venue_name`, `home_venue_street`, `home_venue_postal_code`, `home_venue_city`, `home_venue_country`
- `training_location_differs`
- Abweichender Trainingsort: `training_venue_name`, `training_venue_street`, `training_venue_postal_code`, `training_venue_city`, `training_venue_country`
- Check-Constraint: bei abweichendem Trainingsort müssen alle Adressfelder vollständig sein.

**`public.teams`**
- `birth_cohorts`
- `abbreviation`

**Kontext und RPCs**
- Neue Tabelle `public.user_club_context`, RLS aktiviert, kein direkter Zugriff für `anon` oder `authenticated`.
- Neue Funktionen: `can_manage_club_context`, `select_club_context`, `get_selected_club_context`, `clear_club_context`, `admin_create_club`, `admin_update_club_crest`.
- `admin_create_team` erweitert um Jahrgänge, Kürzel und optionale Saison. Ein Super Admin wird dabei nicht automatisch als Vereins- oder Mannschaftsmitglied eingetragen; die Erstellung ist auf den ausdrücklich ausgewählten Vereinskontext begrenzt.
- Bei einer angegebenen Saison wird diese als aktive Saison der neuen Mannschaft angelegt.

**Storage**
- Bucket `club-assets`, öffentliches Lesen der Wappen, Dateigrößenlimit 2 MiB, erlaubte MIME-Typen PNG/JPEG/WebP.
- Upload, Lesen durch authentifizierte Nutzer, Aktualisierung und Löschen sind über Policies auf berechtigte Vereinsadmins bzw. den ausgewählten Super-Admin-Vereinskontext begrenzt.

### Nachprüfung

- Spalten in `clubs` und `teams` vorhanden.
- `user_club_context` vorhanden und RLS aktiviert.
- Neue administrative RPCs: EXECUTE für `authenticated`, nicht für `anon` oder `PUBLIC`; Berechtigungsprüfungen sind in den Funktionen enthalten.
- Storage-Bucket und vier Policies für SELECT/INSERT/UPDATE/DELETE vorhanden.
- Keine Vereins- oder Mannschaftsdatensätze wurden durch die Migration angelegt.
- Security Advisor meldet unter anderem den erwarteten Hinweis, dass `user_club_context` RLS ohne direkte Policies hat (Zugriff erfolgt absichtlich nur über SECURITY DEFINER-RPCs). Außerdem gibt es bereits bestehende Hinweise zu SECURITY DEFINER-Funktionen und mehrfach permissiven Policies; diese sind separat zu bewerten und wurden nicht pauschal geändert.

### Frontend

- DEV-Branch `develop`: Vereinsanlage und Mannschaftsanlage ergänzt.
- Syntaxprüfung der beiden Inline-Skripte: bestanden (das externe ES-Modul wurde für die lokale Parserprüfung ausgeklammert).
- Browser-/Praxistest noch ausstehend; insbesondere Formularablauf, Wappen-Upload, Saisonverknüpfung und Rollenverhalten müssen in DEV getestet werden.

### PROD-Rollout

Nicht übertragen. Für PROD ist eine separate, geprüfte Release-Migration erforderlich. Die zwei DEV-Migrationseinträge sind vor einem PROD-Cutover nicht blind auszuführen; das Ziel-Schema und Funktionssignaturen müssen zuerst geprüft werden.


## DB-DEV-006 – Admin-Auswahl bei Vereins- und Mannschaftsanlage (2026-10-29)

**Umgebung:** Supabase DEV, Projekt `pzazqvvoruqnqhcorbwx`  
**Migration:** `20261029051752_add_admin_selection_to_club_and_team_creation`  
**Status:** Migration ausgeführt; RPC-Signaturen und Frontend-Syntax geprüft. Praxistest im Browser steht noch aus.  
**PROD:** Unverändert.

### Datenbankänderungen

- `admin_list_club_admin_candidates()`: Nur für angemeldete Super Admins; liefert bestehende Konten, die noch keinem Verein zugeordnet sind und keine Super-Admin-Rolle haben.
- `admin_list_team_admin_candidates(p_club_id)`: Liefert nur Mitglieder des angegebenen Vereins; der Zugriff ist auf Super Admins mit ausgewähltem Vereinskontext oder echte Vereinsadmins dieses Vereins begrenzt.
- `admin_create_club(..., p_club_admin_user_id)`: verlangt einen gültigen, noch keinem Verein zugeordneten Benutzer und legt Verein, Vereinsmitgliedschaft sowie Rolle `club_admin` atomar an.
- `admin_create_team(..., p_team_admin_user_id)`: verlangt ein Mitglied des ausgewählten Vereins und legt Mannschaft sowie `admin`-Rollen in `team_members` und `team_member_roles` atomar an.
- Super Admins bleiben neutral und können nicht als Vereins- oder Mannschaftsadmin zugewiesen werden.
- Ausführungsrechte der neuen/angepassten RPCs: `authenticated`; `anon` und `PUBLIC` sind explizit ausgeschlossen.

### Frontend

- Vereinsformular: Pflichtauswahl „Vereinsadmin“, dynamisch aus der geschützten RPC geladen.
- Mannschaftsformular: Pflichtauswahl „Mannschaftsadmin“, dynamisch aus Mitgliedern des ausgewählten Vereins geladen.
- Beide Anlagefunktionen senden die ausgewählte Benutzer-ID mit; die Datenbank validiert sie erneut unabhängig vom Frontend.
- Syntaxprüfung der Inline-Skripte: bestanden.
- Security Advisor erneut ausgeführt. Bestehende Hinweise zu SECURITY DEFINER-Funktionen und den bewusst ohne direkte Policies betriebenen Kontexttabellen bleiben bestehen; keine pauschalen Sicherheitsänderungen vorgenommen.

### Noch offen

- DEV-Praxistest: gültige Vereinsadmin-Zuweisung, gültige Mannschaftsadmin-Zuweisung, Ablehnung eines Kontos aus einem anderen Verein, Ablehnung fehlender Admin-Auswahl und Neutralität des Super Admins.
- Keine Änderung an PROD.



---

## Release 1.5.2 – konsolidierter Datenbank- und Berechtigungsnachweis (02.11.2026)

**Deployment-Kontext:** Release 1.5.2 wurde laut Nutzerbestätigung am 02.11.2026 nach PROD deployed. Ein unabhängiger Post-Deploy-Smoke-Test ist nicht dokumentiert. Die folgenden Angaben geben dokumentierte frühere Ausführungen/Prüfungen wieder und sind keine erneute Live-Abfrage am 03.11.2026.

### DB-DEV/PROD-015 – Soft-Deaktivierung von Mannschaften
Laut Projektverlauf in DEV und PROD ausgeführt und verifiziert.

Dokumentierter SQL-Auszug:
```sql
ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true;
```

Zusätzlich wurde `public.remove_team(p_team_id uuid)` zur Soft-Deaktivierung von Mannschaften eingeführt/verwendet. **Die vollständige Originaldefinition ist in diesem Protokoll nicht enthalten.** Vor einer künftigen Änderung muss sie direkt aus der jeweiligen Zielumgebung, beispielsweise über `pg_get_functiondef()`, ausgelesen werden. Dieser Eintrag ersetzt nicht die Originalmigration.

Frontend-Verhalten laut Release-Dokumentation: aktive Mannschaften werden über `active = true` gefiltert; der Bestätigungs-/Hinweistext zur Deaktivierung wurde angepasst.

### DB-ACL-2026-11-02 – interne Funktionen in PROD
Laut Projektverlauf wurde folgende Berechtigungsbereinigung in PROD ausgeführt:

```sql
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.log_team_role_change() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prevent_last_team_admin_removal() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;
```

Laut damaliger Prüfung war EXECUTE für `PUBLIC`, `anon` und `authenticated` entzogen. Ein vollständiger Laufzeittest aller zugehörigen Trigger ist nicht als abgeschlossen dokumentiert. Bei einer künftigen Prüfung Triggerfunktion, Triggerdefinition und tatsächliche Triggerausführung getrennt bewerten; interne Triggerfunktionen sind nicht als App-RPC aufzurufen.

### Weitere im Verlauf geprüfte Berechtigungen und Objekte
- `public.admin_update_club_member_profile(uuid,uuid,text,text)`: laut früherer Prüfung in DEV und PROD kein EXECUTE für `anon`, EXECUTE für `authenticated`.
- `save_player_with_positions`: PROD-Definition laut früherer Prüfung ausgelesen und als passend beurteilt.
- 25 vom Frontend verwendete RPCs: laut früherem Abgleich in beiden Umgebungen vorhanden; Signaturen und SECURITY-DEFINER-Merkmale wurden verglichen.
- Relevante RLS-Policies sowie Storage-Buckets `club-assets` und `profile-avatars`: laut früherem Abgleich zwischen DEV und PROD geprüft.
- Diese Angaben sind historische Prüfvermerke. Sie stellen keine erneute Live-Verifikation zum 03.11.2026 dar.

### Historische Migrationspakete 1–14
Laut Projektverlauf wurden Pakete 1–9 sowie 10–14 manuell in PROD angewendet; Migration 14 wurde als ausgeführt/verifiziert gemeldet. Die vollständigen Original-SQL-Dateien und exakten Migrationsnamen sind in diesem Protokoll nicht enthalten. Sie müssen anhand der tatsächlichen Supabase-Migrationshistorie und der Originalquellen ergänzt bzw. belegt werden. Keine SQL-Definition aus dem Gedächtnis rekonstruieren.

### Pflicht vor der nächsten Datenbankänderung
1. Migrationseinträge in DEV und PROD read-only abfragen.
2. Tabellen/Spalten, Constraints, Indizes, Funktionen, Trigger, Grants, RLS-Policies und Storage-Policies in beiden Umgebungen vergleichen.
3. Originaldefinition und Abhängigkeiten jeder betroffenen Funktion sichern.
4. Fehlende Original-SQL-Quellen ausdrücklich als fehlend dokumentieren.
5. Erst nach ausdrücklicher Freigabe SQL ändern; aus diesem Protokoll folgt keine implizite Freigabe.


## Historischer PROD-SQL-Bestand – Migrationen 1–43 (03.11.2026)

Die 43 vom Nutzer bereitgestellten SQL-Originale wurden vollständig inventarisiert und bytegenau gegen die Quelldateien aus Sql.zip verglichen. Die einzelnen SHA-256-Prüfsummen und Kurzbeschreibungen stehen im Inventar docs/database/archive/PROD_Migrationen_01-43/MIGRATIONEN_01-43_Inventar.md; die Originaldateien und die technische Matrix befinden sich im Archivpaket docs/database/archive/PROD_Migrationen_01-43/PROD_Migrationen_01-43_Arbeitsstand.tar.xz.

Der Nutzer bestätigt, dass alle 43 Anfragen in PROD erfolgreich ausgeführt und im damaligen Chat geprüft wurden. Die Einzelabfragen und Resultate der Prüfungen sind im Archiv nicht enthalten und wurden nicht erneut eingesehen. Diese Dokumentation ist daher ein historischer Ausführungs- und Nutzerbestätigungsnachweis, kein aktueller Live-Schema- oder RLS/ACL-Abgleich. Siehe die 43 getrennten PROD-Datensätze in DB_MIGRATION_LOG.md.

## DB-DEV-007 – Gemeinsamer Abschluss der Mitglieder-/Trainer-Einladung

- **Umgebung:** Supabase DEV
- **Migrationsversion:** `20261103203047` (`r16_member_invitation_transaction_dev`)
- **Status:** Migration erfolgreich ausgeführt und Struktur-/Rechteverifikation abgeschlossen.
- **Funktion:** `public.admin_complete_member_invitation(p_user_id uuid, p_display_name text, p_club_id uuid, p_invited_role text, p_team_id uuid DEFAULT NULL)`
- **Rückgabe:** `jsonb`
- **Sicherheit:** `SECURITY DEFINER`, fester `search_path = pg_catalog, public, auth`; EXECUTE für `authenticated`, kein EXECUTE für `anon` oder `PUBLIC`.
- **Zweck:** Gemeinsamer transaktionaler Abschluss für die vier Zielrollen `member`, `club_admin`, `team_admin` und `trainer`. Die Funktion validiert Auth-Benutzer, Verein, optionale Mannschaft und Einladungsrolle; prüft die Berechtigung des einladenden Super Admins/Vereinsadmins/Mannschaftsadmins; verhindert abweichende Vereins- und zusätzliche Mannschaftszuordnungen; ergänzt die Vereinsmitgliedschaft automatisch; ergänzt gegebenenfalls Vereins- oder Mannschaftsrollen.
- **Profilname:** `profiles.display_name` wird nur gesetzt, wenn das Profil noch keinen persönlichen Namen enthält oder derzeit die E-Mail-Adresse als Fallback enthält. Ein bereits vorhandener persönlicher Name bleibt erhalten. `team_members.admin_label` wird durch diese Funktion nicht geschrieben.
- **Transaktions-/Parallelitätsverhalten:** Die Zielzeile in `auth.users` wird mit `FOR UPDATE` gesperrt. Ein vorhandenes Profil wird ebenfalls für die Dauer der Transaktion gesperrt. Die Datenbankänderungen der Funktion werden transaktional ausgeführt.
- **Verifikation:** Live-Definition über `pg_get_functiondef()` gelesen; `to_regprocedure()` bestätigt Existenz; `prosecdef = true`; EXECUTE-Prüfung ergab `authenticated=true`, `anon=false`, `PUBLIC=false`; Migration in Supabase-Historie vorhanden.
- **Nicht verifiziert:** Noch kein echter Funktionsaufruf für einen Benutzer aus einem der drei Kontexte; keine End-to-End-Einladung, keine E-Mail, keine parallele Konkurrenzprüfung. Die Funktion ist zunächst Backend-Grundlage und noch nicht an die App angebunden.
- **PROD:** Nicht ausgeführt. Keine PROD-Änderung.

**Wichtige Abgrenzung:** Diese Funktion legt keine Auth-Benutzer an und versendet keine Einladungs-E-Mails. Beides verbleibt in der nachfolgenden Edge-Function-Verarbeitung. Bei einem späteren Rollback ist vor dem Löschen zu prüfen, dass keine aufrufenden Edge Functions oder anderen Datenbankobjekte mehr davon abhängen.



## DB-DEV-008 – Vereinsmitglieder inklusive Profilnamen und Profilbilder auslesen

- **Umgebung:** Supabase DEV
- **Status:** In Supabase DEV ausgeführt; Funktions- und Rechteverifikation erfolgreich. Funktionaler Frontendtest noch offen.
- **Anlass:** `get_club_members_v2(uuid)` gibt derzeit nur Benutzer-ID, E-Mail, Vereinsadmin-Status und Mannschaftsrollen zurück. Die Superadmin-Kartenansicht fragt Profilnamen nicht ab. Der bestehende direkte Profil-Lesezugriff im Bearbeitungsdialog wird durch die aktuelle `profiles_select`-Policy im ausgewählten Vereinskontext nicht freigegeben; der Frontend-Abfragefehler wird bisher nicht sichtbar behandelt.
- **Objekt:** Neue Funktion `public.get_club_members_v3(p_club_id uuid)`. Migration `20261104113632` (`club_member_profiles_read_v3_dev`).
- **Rückgabe:** `user_id`, `email`, `display_name`, `avatar_url`, `is_club_admin`, `teams`.
- **Sicherheitsmodell:** `SECURITY DEFINER`, fester `search_path = pg_catalog, public, auth`; vor jeder Rückgabe muss `auth.uid()` vorhanden sein und `public.can_manage_club_context(p_club_id)` erfolgreich sein. Profilfelder werden ausschließlich für Mitglieder des angegebenen Vereins zurückgegeben. EXECUTE wird explizit nur an `authenticated` vergeben; `PUBLIC` und `anon` werden entzogen.
- **Abgrenzung:** `get_club_members_v2` bleibt unverändert. Keine Tabellen-/Datenänderung, keine Erweiterung der `profiles`-RLS-Policies und keine Änderung bestehender Profile.
- **Frontend nach SQL-Freigabe:** Superadmin-Mitgliederliste zeigt `display_name` als Hauptzeile und E-Mail darunter; Avatar aus `avatar_url`; Bearbeitungsdialog nutzt die bereits geladene Profilinformation der Vereinsmitglied-RPC statt einer separaten, durch RLS blockierten Abfrage.
- **Ausführungsnachweis:** `DB_MIGRATION_LOG.md`, ID DB-MIG-2026-002. Supabase bestätigte die erfolgreiche Migration; versionierte Quelle: `supabase/migrations/20261104113632_club_member_profiles_read_v3_dev.sql`.
- **PROD:** Am 05.11.2026 nach separater Prüfung und Freigabe ebenfalls ausgeführt; Details siehe DB-MIG-2026-005 in `DB_MIGRATION_LOG.md`.
- **Verifikation:** Funktion vorhanden; Owner `postgres`; `SECURITY DEFINER`; `STABLE`; fester `search_path`; EXECUTE für `authenticated` (zusätzlich postgres/service_role), nicht für anon/PUBLIC. Bestehende `profiles`-Policies unverändert. Authentifizierte Positiv-/Negativtests und Frontend-Praxistest bleiben offen.



**Bereits versionierte Anwendungsschicht:** `index.html` ist in `develop` committed und wurde in den DEV-Spiegel `jugendmannschaft-dev/main` synchronisiert (Blob-SHA `ebf7363aa2df1f5b3fc465934e2fab8cea3ef0c1`); manueller UI-Test offen. `supabase/functions/invite-member/index.ts` und `supabase/functions/invite-trainer/index.ts` sind in `develop` versioniert, aber in Supabase DEV noch nicht deployed. Diese Anwendungsschicht ändert den Datenbankstatus nicht. `index.html` begrenzt den Vereinsmitglieder-Dialog auf eine tatsächliche Mannschaft und bewahrt bestehende Zuordnungen; `supabase/functions/invite-member/index.ts` lässt bestehende Superadmins als Zielpersonen zu; `supabase/functions/invite-trainer/index.ts` antwortet als Legacy-Endpunkt mit HTTP 410. Die Quellen liegen in `develop`. Diese Änderungen sind noch nicht in Supabase DEV aktiviert; daher gibt es dafür noch keinen Deployment-Nachweis in `SUPABASE_CHANGELOG.md`.
## DB-DEV-009 – Ein-Mannschaft-Regel und zusätzliche Verwaltungsrollen

**DEV-Ausführung:** in Supabase DEV erfolgreich ausgeführt am 04.11.2026. Supabase-Migrationsversion `20261104143331`, Name `db_dev_009_single_team_membership_guard`. **PROD-Ausführung:** separat am 05.11.2026 nach eigener Prüfung und Freigabe; Supabase-Migrationsversion `20261105093559`, Name `db_dev_009_single_team_membership_guard_prod`. Ausführungsnachweise: `DB_MIGRATION_LOG.md`, DB-MIG-2026-003 (DEV) und DB-MIG-2026-006 (PROD).

Das freigegebene Rollenmodell trennt tatsächliche Mannschaftszuordnung und zusätzliche Verwaltungsrechte:

- Ein Benutzer darf höchstens einer Mannschaft tatsächlich zugeordnet sein.
- Ein bereits bestehendes Mannschaftsmitglied kann nachträglich Superadmin, Vereinsadmin oder beides werden.
- Vorhandene Zuordnungen und Mannschaftsrollen bleiben bei Vergabe oder Entfernung dieser Zusatzrollen unverändert.
- Superadmins und Vereinsadmins dürfen in Mannschaftskontexten ihres Berechtigungsbereichs administrieren, ohne dort selbst Mitglied zu sein.
- Die Ein-Team-Regel beschränkt die Zuordnung der Zielperson, nicht den Handlungskontext des aufrufenden Administrators.

**Umgesetzte Datenbankänderungen:**
- Neue SECURITY-DEFINER-Triggerfunktion `public.enforce_single_team_membership()` mit festem `search_path = pg_catalog, public, auth`.
- Trigger `team_members_single_team_guard` und `team_member_roles_single_team_guard`, jeweils BEFORE INSERT OR UPDATE OF `user_id, team_id`.
- Neuer Index `idx_team_member_roles_user` auf `public.team_member_roles(user_id)`.
- Überarbeitete RPCs `admin_add_team_role`, `admin_create_team`, `admin_list_team_admin_candidates` und `admin_complete_member_invitation`.
- Der Schutz prüft beide Mannschaftszuordnungstabellen gemeinsam und sperrt die Auth-Benutzerzeile, um konkurrierende Zuordnungsversuche desselben Benutzers zu serialisieren.
- Bestehende RLS-Policies wurden nicht geändert. Es gibt keinen Trigger auf `global_user_roles`; die Vergabe von `super_admin` wird nicht durch den Teamzuordnungsschutz blockiert.
- Ein bestehendes Mannschaftsmitglied kann zusätzlich Vereinsadmin werden; bestehende Teamzuordnungen werden durch die Vereinsrollenfunktion nicht verändert. Eine UI/RPC zur Vergabe der globalen Superadmin-Rolle ist eine separate Aufgabe und nicht Bestandteil dieser Migration.

**Führende Spezifikation und Entwürfe in develop:**
- `docs/proposals/single-team-membership-guard/README.md`
- `docs/proposals/single-team-membership-guard/migration.sql`
- `docs/proposals/single-team-membership-guard/after_apply_verification.sql`

**Versionierte SQL-Quelle:** `supabase/migrations/20261104143331_db_dev_009_single_team_membership_guard.sql` (GitHub-Blob-SHA `b73af4ef0e45ce0d475f0498eb4bf8db31d0a09a`). Der separate Konzeptentwurf bleibt unter `docs/proposals/single-team-membership-guard/migration.sql`.

**Read-only Verifikation in DEV:**
- Beide neuen Trigger vorhanden und aktiviert; bestehende Audit- und Letzter-Admin-Trigger unverändert vorhanden.
- Index vorhanden.
- Mehrfachzuordnungen über beide Teamtabellen: 0 Benutzer.
- Angepasste RPCs besitzen `SECURITY DEFINER`, festen Suchpfad, EXECUTE für `authenticated`, kein EXECUTE für `anon`; die bestehenden Service-Role-Rechte bleiben erhalten.
- Triggerfunktion: EXECUTE für `anon` und `authenticated` entzogen; `service_role` besitzt weiterhin EXECUTE. Der Anwendungsclient ruft die Funktion nicht direkt auf; sie wird von den beiden Triggern verwendet.
- Keine RLS-Policy-Definition wurde durch die Migration geändert.
- Die aktuellen Tabellenbestände nach Ausführung sind in DB-MIG-2026-003 dokumentiert; die Migration selbst enthält keine Datenbereinigung oder Änderung bestehender Mitgliedschaftszeilen.

**Advisor-Nachprüfung:** Security Advisor meldet weiterhin allgemeine SECURITY-DEFINER-Warnungen, Hinweise auf die absichtlich ohne direkte Policies betriebenen Kontexttabellen und den Auth-Passwortschutz. Performance Advisor meldet allgemeine RLS-Initplan-/Mehrfach-Policy-Hinweise; der frisch angelegte Index ist unmittelbar nach Erstellung noch ungenutzt. Diese Themen sind getrennt zu bewerten und wurden nicht pauschal durch DB-DEV-009 verändert.

**Noch offen:** funktionale Positiv-/Negativtests über die App und manuelle Browserprüfung. Die beiden korrigierten Einladungs-Endpunkte wurden am 04.11.2026 separat in Supabase DEV auf Version 4 deployed; beide sind ACTIVE, verify_jwt=true, und die Live-Quelltexte stimmen bytegenau mit develop überein. Deployment-Nachweis: SUPABASE_CHANGELOG.md, SUPA-2026-001. PROD bleibt unverändert.


## DB-TEST-2026-004 – Serverseitiger Negativtest der Ein-Mannschaft-Regel (04.11.2026)

**Umgebung:** Supabase DEV, Projekt `pzazqvvoruqnqhcorbwx`. Kein PROD-Zugriff.

**Anlass/Freigabe:** Der Nutzer hat den serverseitigen Negativtest S4 ausdrücklich freigegeben und verlangt die Dokumentation von SQL-Eingriffen.

**Vorprüfung (read-only):**
- Die Trigger `team_members_single_team_guard` und `team_member_roles_single_team_guard` sind aktiv und greifen jeweils bei INSERT/UPDATE.
- Beide rufen `public.enforce_single_team_membership()` auf.
- Das vorhandene DEV-Testkonto ist jeweils genau der Mannschaft „DEV Mannschaft“ zugeordnet.
- „G-Junioren“ ist eine zweite Mannschaft desselben Vereins.

**Testausführung:** Ein einzelner anonymer PL/pgSQL-Testblock führte je einen INSERT-Versuch in `public.team_members` und `public.team_member_roles` für dasselbe Testkonto und die zweite Mannschaft aus. Die erwartete Check-Violation wurde in je einem separaten Exception-Block abgefangen. Ein unerwartet erfolgreicher INSERT hätte den gesamten Test mit Fehler beendet. Die beiden INSERT-Versuche wurden durch den Trigger mit SQLSTATE `23514` und der Meldung „Benutzer gehört bereits einer anderen Mannschaft an. Eine zweite Mannschaftszuordnung ist nicht möglich.“ abgewiesen.

**Nachprüfung (read-only):** In beiden Tabellen besteht weiterhin genau eine Zuordnung zur „DEV Mannschaft“; es besteht keine Zuordnung des Testkontos zu „G-Junioren“.

**Ergebnis:** Serverseitige Ein-Mannschaft-Sperre in beiden Tabellen bestanden.

**Änderungs-/Datenbilanz:** Keine Schemaänderung, keine Migration, keine dauerhafte Datenänderung, keine Rollenentfernung und keine Änderung bestehender Mitgliedschaftsdaten. Die SQL-Ausführung diente ausschließlich dem kontrollierten Negativtest. PROD und GitHub `main` blieben unangetastet.

## DB-MIG-2026-004 – Gemeinsamer Abschluss der Mitglieder-/Trainer-Einladung (PROD)

**Status: in Supabase PROD erfolgreich ausgeführt am 05.11.2026.** Supabase-Migrationsversion `20261105091350`, Name `r16_member_invitation_transaction_prod`. Ausführungsnachweis: `DB_MIGRATION_LOG.md`, DB-MIG-2026-004.

- Neue Funktion: `public.admin_complete_member_invitation(uuid,text,uuid,text,uuid)`.
- `SECURITY DEFINER`, fester `search_path = pg_catalog, public, auth`.
- EXECUTE für `authenticated` erteilt; EXECUTE für `PUBLIC` und `anon` entzogen.
- Read-only Verifikation bestätigt Funktion, Funktionssicherheit, Suchpfad und Rechte.
- Keine bestehenden Mitgliedschafts-/Rollendaten und keine RLS-Policies verändert.
- Die Funktion ist zunächst nur die Datenbankgrundlage. Die Einladung über die Edge Functions ist noch nicht freigegeben/deployed.
- **Historischer Stand zum Zeitpunkt dieser Migration:** DB-DEV-008 und DB-DEV-009 waren noch nicht in PROD ausgeführt. Beide wurden am 05.11.2026 nach separater Prüfung und Freigabe nachgezogen (DB-MIG-2026-005 und DB-MIG-2026-006 in `DB_MIGRATION_LOG.md`). Der neue Einladungsablauf bleibt dennoch bis zum Edge-Function-Deployment und den Praxistests deaktiviert.
- Versionierte SQL-Quelle: `supabase/migrations/20261105091350_r16_member_invitation_transaction_prod.sql`.


## PROD-Nachtrag 05.11.2026 – DB-DEV-008 und DB-DEV-009

Die PROD-Datenbankgrundlage für die Mitglieder-/Trainer-Einladung wurde am 05.11.2026 vervollständigt:

- **DB-DEV-008 / DB-MIG-2026-005:** `public.get_club_members_v3(uuid)` wurde in PROD angelegt und read-only auf Existenz, Rückgabetyp, SECURITY DEFINER, festen Suchpfad und ACL geprüft. `get_club_members_v2` und die bestehenden Profile-RLS-Policies blieben erhalten. Die Supabase-Migrationsversion wurde vom Werkzeug nicht zuverlässig zurückgegeben und wird deshalb nicht behauptet.
- **DB-DEV-009 / DB-MIG-2026-006:** Ein-Mannschaft-Trigger für `team_members` und `team_member_roles`, Index sowie vier angepasste Rollen-/Einladungs-RPCs wurden in PROD ausgeführt. Supabase-Migrationsversion `20261105093559`. Die Legacy-Rollenpriorität in `team_members.role` blieb erhalten. `admin_remove_team_role`, `prevent_last_team_admin_removal`, Audit-Trigger und bestehende RLS-Policies wurden nicht ersetzt.
- **Read-only Kontrolle:** beide Trigger und alle fünf Funktionen vorhanden; Rechte wie vorgesehen; Index vorhanden; bestehender Schutz des letzten Mannschaftsadmins weiterhin vorhanden; fünf bestehende RLS-Policies; keine Mehrfachzuordnungen; Tabellenbestand nach Migration: 5 Zeilen in `team_members` und 5 in `team_member_roles`.
- **Noch offen:** Deployment der Edge Functions in PROD und End-to-End-/UI-Praxistests. Bis dahin bleibt die neue Einladungsstrecke deaktiviert.

Die vollständigen Ausführungsdetails, Freigaben, SQL-Backup-Prüfsummen, Verifikationen und Nachweisgrenzen stehen in `DB_MIGRATION_LOG.md` unter DB-MIG-2026-005 und DB-MIG-2026-006.


## DB-PLAN-E05-001 – Technisches Zielschema für Trainingsereignisse und Sperren

- **Stand:** 08.11.2026, Revision 3 nach fachlicher und dokumentarischer Konsolidierung
- **Umgebung:** Ziel DEV; nicht ausgeführt
- **Status:** Entwurf / technisch noch nicht freigegeben
- **Geplante Objekte:** zehn neue Tabellen: `training_behavior_events`, `training_behavior_event_audit`, `training_suspensions`, `training_suspension_exceptions`, `training_suspension_audit`, `club_suspension_settings`, `team_suspension_game_type_settings`, `team_suspension_game_types`, `matchday_early_suspension_resets`, `matchday_early_suspension_reset_audit`.
- **SQL-Entwurf:** `docs/E05_SCHEMA_MIGRATION_DRAFT_2026-11-08.sql` (Review-Artefakt, nicht ausführbar als Migration / nicht freigegeben)
- **Zieldatenmodell:** `docs/E05_TECHNISCHES_ZIELDATENMODELL_2026-11-08.md` (Revision 3)
- **Reviewbericht:** `docs/E05_TECHNISCHER_REVIEW_SCHEMAFUNDAMENT_2026-11-08.md`
- **Sicherheitskonzept:** RLS auf allen neuen Tabellen, minimale SELECT-Grants, keine direkten Client-Schreibrechte. Schreibpfade nur über getrennte, auditierte RPCs.
- **Datenwirkung:** keine. Es wurden keine E05-Tabellen, Funktionen, Trigger, Policies, Grants oder Daten angelegt/geändert.
- **Testautomatisierung:** `.github/workflows/e05-schema-draft-test.yml` mit Fixture/Assertions unter `docs/e05-test/`; Ergebnis noch ausstehend.
- **Technischer Stand:** Die erste Prüfung identifizierte Fehler bei Spieler-/Actor-Snapshots, Team-Override, Sperrenursprung, Statusfluss und Team-/Saison-/Termin-Konsistenz. Modell und SQL-Entwurf wurden daraufhin überarbeitet. Das Zieldatenmodell liegt in Revision 3 vor. Statische Strukturprüfungen sind dokumentiert; ein isolierter PostgreSQL-17.6-GitHub-Actions-Test ist vorbereitet, sein erfolgreicher Lauf aber noch nicht verifiziert.
- **PROD:** nicht übertragen; keine Freigabe.
- **Dokumentationszuordnung:** Dieser Eintrag in `DB_CHANGELOG.md` ist das E05-Planungs-/Änderungsregister. `DB_MIGRATION_LOG.md` bleibt ausschließlich das Ausführungsjournal und erhält erst nach einem tatsächlichen SQL-Ausführungsversuch einen DEV-Datensatz. `SUPABASE_CHANGELOG.md` ist für diesen SQL-Vorschlag nicht einschlägig. Es wird kein separates E05-Ausführungsprotokoll parallel zu diesen führenden Dokumenten geführt.
- **Ausführungsjournal:** erst nach einem tatsächlichen Ausführungsversuch in `DB_MIGRATION_LOG.md` erfassen. Dieser Planungsdatensatz ist kein Ausführungsnachweis.

Dies ist ein Planungsdatensatz und kein Nachweis entstandener Datenbankobjekte.

### Ergänzende Prüfnotiz E05 (08.11.2026)

Der technische Review des vorbereiteten E05-Schemafundaments ist in `docs/E05_TECHNISCHER_REVIEW_SCHEMAFUNDAMENT_2026-11-08.md` dokumentiert. Die dort referenzierte SQL-Datei ist weiterhin nur ein Review-Entwurf. **Es wurden keine E05-Datenbankobjekte angelegt oder geändert.** Dieser Hinweis ist kein neuer Eintrag im Register tatsächlich entstandener Datenbankobjekte.



## DB-MIG-2026-008 – E05 Package 10: Trainingsdatumsbasierte Kartenchronologie und Sperrenzuordnung (DEV)

- **Datum:** 11.11.2026
- **Status:** Erfolgreich in DEV ausgeführt; Migrationsversion 20261111161403.
- **Migration:** `supabase/migrations/20261111161403_e05_package_10_training_date_suspensions.sql`
- **Rollback:** `supabase/rollback/20261111090000_e05_package_10_training_date_suspensions_rollback.sql`
- **Prüfabfragen:** `docs/E05_PACKAGE_10_TEST_QUERIES.sql`
- **Freigabedokumentation:** `docs/E05_PACKAGE_10_GELBSPERREN_FREIGABE_2026-11-11.md`
- **Umfang:** Vier bestehende Funktionen ersetzt; keine Tabellen, Spalten, Trigger, RLS-Policies, Grants oder Spielarten-Einstellungen verändert.
- **Verifikation:** Migration registriert; Funktionen SECURITY DEFINER mit festem search_path; API-Grants unverändert; bestehende Vereins-/Mannschaftskonfiguration read-only geprüft.
- **Konfiguration:** Beide DEV-Mannschaften haben aktuell keine befüllte relevante Spielartenkonfiguration. Daher bleiben offene Sperren ohne automatische Zielzuordnung, bis die bereits vorhandene Einstellung gepflegt ist. Package 10 hat die Konfiguration nicht geändert.
- **Tests:** Statische und read-only Nachkontrollen abgeschlossen. Synthetische Funktionstests und Frontend-E2E stehen noch aus.
- **PROD:** Nicht ausgeführt, nicht freigegeben.



## DB-MIG-2026-009 – E05: Read-RPCs für sperrenrelevante Spielarten (DEV)

- Nach ausdrücklicher Freigabe wurden zwei eng begrenzte Lese-RPCs ergänzt: `get_club_suspension_game_types(uuid)` und `get_team_suspension_game_type_settings(uuid)`.
- Beide Funktionen sind `STABLE SECURITY DEFINER` mit festem Suchpfad und prüfen den Vereins- bzw. Mannschaftskontext serverseitig. EXECUTE ist ausschließlich `authenticated` erlaubt; `anon` und `PUBLIC` sind ausgeschlossen.
- Die Frontend-Verwaltung liest die Einstellungen jetzt über diese RPCs statt über direkte SELECTs. Damit wird der zuvor sichtbare Fehler `permission denied for table user_club_context` adressiert, ohne pauschale Tabellenrechte oder neue RLS-Policies einzuführen.
- Keine Tabellen, Daten, RLS-Policies, vorhandenen Funktionen oder bestehenden Grants geändert.
- Migration `20261111180619`, SQL-Quelle `supabase/migrations/20261111180619_e05_suspension_game_type_settings_read_rpcs.sql`; Rollback `supabase/rollback/20261111180619_e05_suspension_game_type_settings_read_rpcs_rollback.sql`.
- Frontend-Commit: `c64a4e2a90be1e48551346d9cf71b523a73c639a`. PROD und `main` unverändert.
- **Noch offen:** Browser-/Rollen-Praxistests und Negativtests; die Metadaten-/Grant-Prüfung ist bestanden.


## DB-MIG-2026-010 – E05: Alle Spieltage als Sperrziele (DEV, 12.11.2026)

- **Status:** Erfolgreich in Supabase DEV ausgeführt; Migration `20261112055415`, Name `e05_all_matchdays_suspension_targets`; Supabase meldete `success: true`.
- **Fachliche Regel:** Jeder geplante Spieltag ist unabhängig von `game_type` als Sperrziel zulässig, einschließlich `game_type IS NULL`. Die Sperrenableistung erfolgt weiterhin nur über tatsächlich abgeschlossene und zugeordnete Spieltage.
- **Betroffene Funktionen:** `e05_assign_player_suspensions`, `correct_suspension`, `serve_matchday_suspensions`.
- **Verifikation:** Signaturen, Eigentümer `postgres`, SECURITY DEFINER, Suchpfad `pg_catalog, public, auth` und bestehende EXECUTE-ACLs read-only geprüft. Keine Spielarten-Konfigurationsreferenzen/Filter mehr in den drei Funktionen. `anon` hat kein EXECUTE.
- **Chronologie:** Unverändert; Reconciliation nutzt weiterhin `training_date_snapshot ASC, id ASC`.
- **Datenumfang:** Keine Tabellen, Spalten, Daten, Trigger, RLS-Policies oder Grants geändert. Vereins-/Mannschaftseinstellungen bleiben gespeichert, werden von diesen Sperrenfunktionen aber nicht mehr ausgewertet.
- **Migration:** `supabase/migrations/20261112055415_e05_all_matchdays_suspension_targets.sql`.
- **Rollback:** `supabase/rollback/20261112055415_e05_all_matchdays_suspension_targets_rollback.sql`; vorbereitet, nicht ausgeführt oder live getestet.
- **Technische Spezifikation:** `docs/E05_DB_MIG_2026_010_SPIELARTENKONFIGURATION_ENTKOPPELN.md`.
- **Testumfang:** Read-only Funktions-/Metadatenprüfung abgeschlossen; synthetische fachliche Funktionstests und Frontend-E2E stehen noch aus.
- **DEV / PROD:** DEV umgesetzt. PROD und `main` unverändert. Frontend folgt als separater Schritt.


## 12.11.2026 – E05 Saisonzuordnung DEV korrigiert

- 8 saisonlose Spieltage und 12 saisonlose Trainings der DEV Mannschaft wurden nach ausdrücklicher Freigabe der aktiven Saison 2026/2027 zugeordnet.
- Vorher: 8/10 Spieltage und 12/15 Trainings ohne Saison; nachher: 0 ohne Saison. G-Junioren unverändert und vollständig zugeordnet.
- Ursache: Die Saison wurde nach den Terminen angelegt; Frontend übergab bei fehlender aktiver Saison `NULL`. Keine automatische DB-Zuordnung vorhanden.
- Reine Datenkorrektur (DML), keine Schemaänderung/Migration. PROD und `main` unverändert.
- Details und SQL-Nachweis: `docs/E05_DATA_REPAIR_SEASON_ASSIGNMENT_DEV_2026-11-12.md`.


## 12.11.2026 – E05 bestehende Sperrenzuordnungen in DEV korrigiert

- Tom Achtzehn Jahre: offene gelbe Sperre auf chronologisch fünfte aktive gelbe Karte (Trainingsdatum 09.11.2026) korrigiert und auf Spieltag 14.11.2026 (Flensburg) zugeordnet.
- Spieler Dreißig: offene rote Sperre ebenfalls auf 14.11.2026 (Flensburg) zugeordnet.
- Vorherige NULL-Zielzuordnungen durch Aufruf der bestehenden Reconciliation-/Assignment-Funktionen korrigiert; Audit-Einträge erzeugt.
- Keine direkte Tabellenänderung, keine Schemaänderung/Migration. PROD und `main` unverändert.
- Details: `docs/E05_SUSPENSION_REPAIR_DEV_2026-11-12.md`.


## 12.11.2026 – DB-MIG-2026-011 vorbereitet: Sperrprüfung Kaderempfehlung/Nominierung

- Freigabepaket auf `develop` vorbereitet: neue Sperren-Guard-Funktion, Trigger auf Empfehlungs- und Nominierungszeilen sowie Erweiterung der bestehenden Empfehlungs-RPC.
- Eine aktive Ausnahme für exakt den betroffenen Spieltag erlaubt weiterhin Empfehlung/Nominierung; Sperren-Lifecycle und bestehende Ausnahme-RPCs bleiben unverändert.
- Keine RLS-, Tabellen-, Daten- oder Frontendänderungen vorgesehen.
- **Nicht ausgeführt.** Supabase DEV wartet auf gesonderte Freigabe; PROD und `main` unverändert.
- Details: `docs/E05_DB_MIG_2026_011_SPERRPRUEFUNG_KADERNOMINIERUNG.md`.


## 12.11.2026 – DB-MIG-2026-011 vorbereitet (nicht ausgeführt)

- E05: Serverseitige Sperrenprüfung bei Kaderempfehlung und Nominierung vorbereitet.
- Regulär gesperrte Spieler werden für den konkret zugeordneten Spieltag abgewiesen; eine aktive, genau diesem Spieltag zugeordnete Ausnahme erlaubt die Teilnahme.
- Bestehende Ausnahme-RPCs, Tabellen, Daten, RLS-Policies und vorhandene Trigger bleiben unverändert.
- Dateien: `supabase/migrations/20261112191000_e05_suspension_nomination_guard.sql`, `supabase/rollback/20261112191000_e05_suspension_nomination_guard_rollback.sql`, `docs/E05_DB_MIG_2026_011_SPERRPRUEFUNG_KADERNOMINIERUNG.md`.
- Status: ausschließlich Entwurf zur gesonderten Freigabe. Supabase DEV nicht verändert; PROD und `main` unverändert.


## 12.11.2026 – DB-MIG-2026-011 in DEV ausgeführt

- E05: Serverseitige Sperrenprüfung bei Kaderempfehlung und Nominierung installiert.
- Regulär gesperrte Spieler werden für den konkret zugeordneten Spieltag abgewiesen; aktive Ausnahme für exakt diesen Spieltag erlaubt die Teilnahme.
- Technische Nachprüfung bestanden: Migration registriert, neuer Trigger vorhanden, vorhandene Trigger/RLS-Policies erhalten, Empfehlungs-RPC-Berechtigungen unverändert.
- Funktionale Praxistests stehen noch aus.
- PROD und GitHub `main` unverändert.
- Details: `docs/E05_DB_MIG_2026_011_SPERRPRUEFUNG_KADERNOMINIERUNG.md`.


## 12.11.2026 – E05 Sperrenprüfung: DB-Tests und Frontend-Anbindung

- Gesperrter direkter Nominierungs-INSERT wird serverseitig abgewiesen; ungesperrter INSERT-Positivtest innerhalb Transaktion zurückgerollt.
- Frontend auf `develop` bindet Sperrstatus, Ausschluss aus Empfehlung und begründungspflichtige Spieltagsausnahme an. Commit `32afa447a7b6e9baf46d1c55412fd03023c39339`.
- Browser-Praxistest und Widerruf-UI noch offen. PROD und `main` unverändert.


## E05 PROD Paket 3 – Freigabekandidat vorbereitet (14.11.2026)

- **Status:** vorbereitet auf GitHub `develop`; nicht in Supabase PROD ausgeführt und nicht als PROD-Migration registriert.
- **Ziel:** Sperrenfundament und automatische Sperrenauslösung nach den bereits in PROD ausgeführten Paketen 1 und 2.
- **DEV-Quelle:** `docs/E05_PAKET_03_SUSPENSION_TRIGGER_2026-11-08.sql` (Blob-SHA `74c77a6c3b1f346e404d88254533bf908a469662`) und DEV-Ausführungsprotokoll `docs/E05_PAKET_03_FREIGABE_UND_AUSFUEHRUNG_2026-11-08.md`.
- **PROD-Migration:** `supabase/migrations/20261114180000_e05_prod_paket_03_suspension_foundation.sql`.
- **Rollback:** `supabase/rollback/20261114180000_e05_prod_paket_03_suspension_foundation_rollback.sql`; guarded, ohne CASCADE, Abbruch bei Datenbestand oder installierten Folgepaketen; stellt die Paket-2-RPC wieder her.
- **Prüf-SQL:** `docs/prod-release/E05_PROD_PAKET_03_SPERRFUNDAMENT_2026-11-14_TESTQUERIES.sql`.
- **Isolierte Tests:** `docs/prod-release/test-package-03/` und `.github/workflows/e05-prod-package-03-test.yml`; PostgreSQL 17.6, keine Verbindung zu DEV/PROD.
- **Read-only PROD-Vorprüfung:** Paket 1/2 vorhanden; Sperrentabellen, Sperren-Audit, Sperren-Audit-Guard und Folgepaketobjekte fehlen; Rollen-/Kontext-Helfer und erforderliche Basistabellen/Felder vorhanden.
- **Betriebsgrenze:** Paket 3 aktiviert automatische Sperrenerzeugung, enthält aber noch keine Spieltagszuordnung, Ausnahmen, Widerruf, Korrektur oder spätere Trainingsdatum-Chronologie. Es ist kein vollständiger Trainerworkflow. Folgepakete bleiben separat vorzubereiten und freizugeben.
- **Freigabegrenze:** Nutzerfreigabe zur Vorbereitung liegt vor; PROD-Ausführungsfreigabe liegt nicht vor. Keine SQL-Ausführung in PROD oder DEV. GitHub `main` unverändert.
- **Nächste Gates:** CI-Ergebnis prüfen; SQL/rollback final reviewen; danach vollständiges Freigabepaket vorlegen. Erst nach separater ausdrücklicher Zustimmung unmittelbar vor Ausführung PROD-Preflight/Hash-Abgleich und Migration ausführen.


### E05 PROD Paket 3 – isolierter CI-Lauf erfolgreich (14.11.2026)

- **Workflow:** [Run 43620391604](https://github.com/bautnhaus/jugendmannschaft/actions/runs/43620391604), Commit `4b36272b781c3afa648abdd3dce7327728ebbdfb`, PostgreSQL 17.6, Ergebnis `success`.
- **Prüfumfang:** Baseline Paket 1/2, Paket-3-Migration, Struktur/RLS/Policies/ACL/Trigger, gelbe Karte 5 und rote Karte, Audit-Fehler mit atomarem Rollback, guarded Paket-3-Rollback und Wiederherstellung der Paket-2-RPC.
- **Vorherige Fehlversuche:** Drei Läufe scheiterten im Fixture-Bootstrap an doppelter Rollenerstellung (`anon` bereits vorhanden). Ursache korrigiert; der erfolgreiche Lauf wurde auf dem bereinigten Fixture vollständig ausgeführt.
- **Grenze:** isolierte PostgreSQL-17.6-Validierung, keine Verbindung zu Supabase PROD und kein Backup-/PITR-Nachweis.
- **Status:** CI-Gate bestanden. Paket 3 bleibt bis zur abschließenden SQL-/Rollback-Review und separaten Nutzerfreigabe nicht zur PROD-Ausführung freigegeben.
