# AP02 P0 – DEV-Testmatrix vor Freigabe

Diese Matrix ist Teil des Cutover-Kandidaten. Noch nicht auf PROD ausführen.

## A. Preflight – vor Migration

- [ ] Vergleich `team_members` gegen `team_member_roles` ist in beide Richtungen leer.
- [ ] Jeder `team_members`-Datensatz hat mindestens eine passende Rolle in `team_member_roles`.
- [ ] Jede Rolle in `team_member_roles` gehört zu einer existierenden Mannschaft und einem existierenden Benutzer.
- [ ] In jeder Mannschaft existiert mindestens ein `admin` in `team_member_roles`.
- [ ] Edge Function `invite-trainer`-Version und DEV-Frontend-Branch sind eindeutig dokumentiert.
- [ ] DEV-Backup/Export und Rückkehrschritt sind vorhanden.

## B. Datenbank nach Migration

- [ ] `is_team_member(team_id)` erkennt Trainer und Admins aus `team_member_roles`.
- [ ] `is_team_admin(team_id)` erkennt nur Team-Admins aus `team_member_roles`.
- [ ] Ein Nutzer mit Admin + Trainer hat zwei Zeilen in `team_member_roles`, aber nur eine Teammitgliedschaft.
- [ ] `admin_add_team_role` fügt eine Rolle hinzu, ohne die vorhandene zu überschreiben.
- [ ] `admin_remove_team_role` entfernt nur die angegebene Rolle.
- [ ] Entfernen der letzten Admin-Rolle wird serverseitig abgelehnt.
- [ ] Gleichzeitige Versuche, die letzten Admin-Rollen zu entfernen, können die Mannschaft nicht ohne Admin hinterlassen.
- [ ] Direkte REST-Schreibversuche auf `team_member_roles` werden abgelehnt.
- [ ] Direkte Änderungen an `team_members.role` werden abgelehnt.
- [ ] Änderung von `team_members.admin_label` durch Team-Admin funktioniert weiterhin.
- [ ] Audit-Log protokolliert Rolle, betroffene Person, handelnden Nutzer, Mannschaft, Aktion und Zeit.
- [ ] Trainer ohne Admin-Rolle können Rollenliste/E-Mail-Adressen nicht über die Admin-RPC abrufen.
- [ ] `player_positions`-INSERT/DELETE-Policies werden vor dem Cutover gesondert bereinigt; Mitgliedschaft allein darf die Admin-Grenze nicht umgehen.

## C. Frontend – DEV

- [ ] Trainer kann sich anmelden und sieht dieselbe Mannschaft und Daten wie zuvor.
- [ ] Admin kann sich anmelden und sieht Admin-Funktionen.
- [ ] Eigene Rollenanzeige zeigt `Admin + Trainer`, wenn beide Rollen bestehen.
- [ ] Admin kann einer Person die zweite Rolle hinzufügen, ohne die erste zu verlieren.
- [ ] Admin kann eine einzelne Rolle entfernen, ohne die andere zu verlieren.
- [ ] Letzter Admin kann nicht herabgestuft oder vollständig entfernt werden.
- [ ] Eine Person mit zwei Rollen kann vollständig entfernt werden, wenn ein weiterer Admin verbleibt.
- [ ] Trainername (`admin_label`) bleibt nach Rollenänderungen erhalten.
- [ ] Bei Fehler der neuen Rollen-RPCs gibt es keinen Rückfall auf die alte Rolle.
- [ ] Einladung an vorhandenen Benutzer ergänzt eine Rolle und überschreibt keine bestehende Rolle.
- [ ] Einladung an neuen Benutzer führt zu einer Teammitgliedschaft plus ausgewählter Rolle.
- [ ] Invite-Funktion lehnt nicht angemeldete Nutzer und Nicht-Admins ab.
- [ ] Trainings, Spieltage, Anwesenheit, Spieler, Positionen und Kaderempfehlung funktionieren weiter.

## D. Scope-Grenzen – nicht durch diese Migration freigeben

- Super Admin mit expliziter Team-/Vereinsauswahl.
- Club-Admin-Berechtigungen auf Vereinsdaten und E-Mail-Sichtbarkeit.
- Vereinsverwaltung / Vereinsmitgliedschaften und das Konfliktszenario „ein Nutzer, maximal eine Vereinsmitgliedschaft“.
- Vollständige Kontolöschung/Anonymisierung.
- Bereinigung aller `player_positions`-Policies.
- Archivierung/Wiederherstellung von Spielern.
- Release in PROD.

Diese Punkte benötigen eigene Änderungen und Tests. Der Kandidat erteilt Super Admin deshalb absichtlich keine impliziten teamweiten Rechte über die allgemeinen Team-Helferfunktionen.
