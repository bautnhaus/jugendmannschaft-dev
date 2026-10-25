# AP02 P0 – Vorbereitung der ausführbaren Rollen-Migration

Stand: 24.10.2026  
Zielumgebung: DEV-Projekt `pzazqvvoruqnqhcorbwx`  
Branch: `feature/ap02-additive-team-roles`  
Status: **Draft in Feature-Branch – noch nicht ausführungsfreigegeben**

## Konkrete Befunde aus dem aktuellen DEV-Stand

1. `team_members` ist weiterhin die operative Quelle der App:
   - `loadApp()` lädt den eigenen Teamzugang aus `team_members` und übernimmt `members[0].role`.
   - Die Trainerliste liest `team_members` direkt und fällt bei RPC-Fehlern auf diese Daten zurück.
   - Rollenänderung aktualisiert `team_members.role` und überschreibt damit die vorherige Rolle.
   - Entfernen löscht den Eintrag aus `team_members`.
   - Der Trainername `admin_label` liegt ebenfalls in `team_members`.
2. Die Edge Function `invite-trainer` prüft `team_members.role='admin'` und schreibt neue/eingeladene Nutzer in `team_members`. Ihre Live-Version stammt nicht aus dem GitHub-Pfad `supabase/functions/invite-trainer/index.ts`; der Deployment-Quellcode muss separat versioniert werden.
3. Der Ist-Abgleich zeigt aktuell für die vorhandenen Teammitglieder identische Rollen in `team_members` und `team_member_roles`. Es gibt derzeit keine Person mit mehreren Teamrollen. Das ist nur ein aktueller Datenstand, kein Beweis für zukünftige Gleichheit.
4. RLS für Trainings, Spieltage, Anwesenheit, Spieler und Teamzugriff ruft vielfach `is_team_member` bzw. `is_team_admin` auf. Diese Funktionen lesen aktuell das alte Ein-Rollen-Modell.
5. Bei `player_positions` gibt es je eine Mitgliedschafts- und eine Admin-Policy für INSERT und DELETE. Da permissive Policies mit ODER zusammengefasst werden, kann die Mitgliedschafts-Policy die Admin-Beschränkung aushebeln.
6. `delete_my_account()` löscht bisher nur `team_members`, `profiles` und `auth.users`; das neue Rollen-/Vereinsmodell und die gewünschte Anonymisierung sind darin noch nicht berücksichtigt.

## Zielentscheidung für den Cutover

- `team_member_roles` wird die **einzige Quelle der Teamrollen**.
- `team_members` bleibt vorerst nur als Team-Mitgliedschafts-/Metadatensatz bestehen, insbesondere für `admin_label`. Das Feld `role` darf nach dem Cutover **nicht mehr als Berechtigungsquelle** verwendet werden.
- Teammitgliedschaft wird aus `team_member_roles` abgeleitet. Der Benutzer darf mehrere Rollen für dasselbe Team haben.
- Alle Rollenänderungen erfolgen über abgesicherte RPCs. Kein direktes Update einer einzelnen `role`-Spalte mehr.
- Vor Entfernen einer Admin-Rolle oder Mitgliedschaft wird serverseitig geprüft, dass mindestens ein Team-Admin verbleibt.
- Die App darf keine unsichere Fallback-Logik mehr auf `team_members.role` nutzen, wenn die neue RPC fehlschlägt.

## Noch zwingend vor einer produktiven Ausführung

- [x] SQL-Kandidat vorbereitet: Rollen-Helfer, additive Rollen-RPCs, Rollen-RLS, Last-Admin-Trigger, Audit-Log und harter Rollen-Paritäts-Preflight. Noch nicht ausgeführt.
- [x] Edge Function `invite-trainer` als versionierte additive-Rollen-Fassung im Feature-Branch vorbereitet. Noch nicht deployt.
- [x] Frontend-Kandidat auf Rollen-Arrays umgestellt: Rollen laden, kombinierte Rollen anzeigen, Rollen einzeln hinzufügen/entfernen, Admin-Schutz und keine Legacy-Rollen-Fallbacks. Noch nicht im Browser getestet.
- [ ] Club Admin / Super Admin kontextgebundene Berechtigungen bleiben bewusst außerhalb dieses Teamrollen-Cutovers; dafür ist eine eigene, explizite Kontextauswahl erforderlich.
- [ ] Konto-Löschung mit Rollen- und Vereinsdaten sowie Anonymisierung bleibt separat offen.
- [ ] Vollständiger Preflight: Rollen-Set-Diff, verwaiste IDs, Clubs-/Teams-Zuordnung, RLS-/Trigger-Inventar. Die Live-Rollen stimmen aktuell überein; die Migration enthält zusätzlich einen harten Paritätsabbruch.
- [x] DEV-Testmatrix dokumentiert; [ ] Tests müssen noch auf DEV ausgeführt werden.
- [ ] Rollback-Plan finalisieren; er darf additive Rollen nicht in eine einzelne Legacy-Rolle zurückschreiben.

## Ausführungsreihenfolge

1. Nur auf diesem Feature-Branch arbeiten; `main` und PROD bleiben unverändert.
2. SQL und Frontend gemeinsam fertigstellen und als zusammenhängende Änderung reviewen.
3. Edge Function auf den neuen RPC-/Rollenpfad vorbereiten; noch nicht deployen.
4. DEV-Preflight ausführen und Ergebnis sichern.
5. Migration in DEV anwenden, danach unmittelbar Postflight und automatisierte Rollenprüfungen.
6. Edge Function deployen und Frontend in DEV testen.
7. Erst nach erfolgreicher manueller Testmatrix Release-Kandidat erstellen.

**Kein Cutover mit einer Mischphase, in der Datenbankfunktionen schon das neue Modell verwenden, die App aber weiterhin direkt `team_members.role` ändert.**

## Dateien im Feature-Branch

- `supabase/migrations/AP02_P0_TEAM_ROLE_CUTOVER_CANDIDATE.sql`
- `supabase/functions/invite-trainer/index.ts`
- `index.html`
- `docs/AP02_P0_DEV_TEST_MATRIX.md`

## Vor dem ersten DEV-Cutover noch erforderlich

1. Migration unabhängig gegen PostgreSQL/Supabase-Syntax und Trigger-/RLS-Abhängigkeiten validieren.
2. Edge Function auf erforderliche Umgebungsvariablen und Auth-JWT-Weitergabe prüfen.
3. Frontend-Syntax prüfen und die App im Browser auf DEV mit Admin- und Trainerkonto testen.
4. Erst dann Migration ausführen; anschließend Edge Function deployen und Frontend aus diesem Branch in DEV testen.
5. Club Admin / Super Admin und Kontolöschung nicht als erledigt markieren; diese Rechte sind nicht Bestandteil dieses Cutovers.
