# AP02 P0 – Vorbereitung der ausführbaren Rollen-Migration

Stand: 24.10.2026  
Zielumgebung: DEV-Projekt `pzazqvvoruqnqhcorbwx`  
Branch: `feature/ap02-additive-team-roles`  
Status: **Vorbereitung – nicht deployen / nicht ausführen**

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

- [ ] SQL-Migration implementiert: neue Helferfunktionen, sichere Rollen-RPCs, RLS-Policies, Trigger, Audit-Log.
- [ ] Edge Function `invite-trainer` aus Live-Quelle in dieses Repository übernommen und auf additive Rollen umgestellt.
- [ ] Frontend auf Rollen-Arrays umgestellt: Laden, Anzeigen, Rolle hinzufügen/entfernen, letzter Admin, Einladung, E-Mail-Sichtbarkeit.
- [ ] Berechtigungen für Club Admin / Super Admin kontextgebunden integriert, ohne bestehende Team-Policies versehentlich zu erweitern.
- [ ] Konto-Löschung mit Rollen- und Vereinsdaten sowie Anonymisierung geklärt und getestet.
- [ ] Exakter Preflight: Rollen-Set-Diff, verwaiste IDs, Clubs-/Teams-Zuordnung, RLS-/Trigger-Inventar.
- [ ] Testmatrix auf DEV durchlaufen und nach jedem Schritt per SQL verifiziert.
- [ ] Rollback-Plan, der nicht versucht, additive Rollen in eine einzelne Legacy-Rolle zurückzuschreiben.

## Ausführungsreihenfolge

1. Nur auf diesem Feature-Branch arbeiten; `main` und PROD bleiben unverändert.
2. SQL und Frontend gemeinsam fertigstellen und als zusammenhängende Änderung reviewen.
3. Edge Function auf den neuen RPC-/Rollenpfad vorbereiten; noch nicht deployen.
4. DEV-Preflight ausführen und Ergebnis sichern.
5. Migration in DEV anwenden, danach unmittelbar Postflight und automatisierte Rollenprüfungen.
6. Edge Function deployen und Frontend in DEV testen.
7. Erst nach erfolgreicher manueller Testmatrix Release-Kandidat erstellen.

**Kein Cutover mit einer Mischphase, in der Datenbankfunktionen schon das neue Modell verwenden, die App aber weiterhin direkt `team_members.role` ändert.**
