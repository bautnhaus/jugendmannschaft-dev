# AP02 – Testprotokoll Vereinsverwaltung

**Stand:** 26.10.2026  
**Umgebung:** DEV – Supabase-Projekt `pzazqvvoruqnqhcorbwx`  
**Arbeitsbranch:** `feature/ap02-club-frontend-dev`  
**Release-Status:** Nicht für PROD freigegeben. PR #2 bleibt Draft und wird nicht gemergt.

## 1. Ziel und Abschlussstatus von AP02

Die Vereinsverwaltung ermöglicht berechtigten Vereinsadmins die Einsicht in Vereinsmitglieder und Spieler, die Verwaltung von Vereinsrollen sowie das Entfernen von Mitgliedern unter Einhaltung der Schutzregeln.

**Produktentscheidung:** Ein Nutzer kann aktuell nur Mitglied in einem Verein sein. Mehrfachmitgliedschaften werden nicht umgesetzt und sind kein Bestandteil von AP02.

**Abschlussentscheidung:** AP02 wird für den aktuellen DEV-Umfang mit dokumentierten Testeinschränkungen abgeschlossen. Die offenen Tests AP02-T08 bis AP02-T10 werden nicht als bestanden gewertet und sind vor einer weitergehenden Freigabe gezielt nachzuholen. Dieser Abschluss ist keine PROD-Freigabe.

## 2. Manuelle Tests – Ergebnis

| ID | Test | Erwartetes Ergebnis | Ergebnis |
|---|---|---|---|
| AP02-T01 | Vereinsadmin öffnet die Mitgliederliste | Mitglieder werden angezeigt | **Bestanden** – vom Nutzer bestätigt |
| AP02-T02 | Vereinsadmin sieht Spieler nach Mannschaft | Spieler werden korrekt angezeigt; aktuell 22 Spieler im zugeordneten DEV-Team | **Bestanden** – vom Nutzer bestätigt |
| AP02-T03 | Mitgliederliste nach Mannschaft filtern | Filter funktioniert | **Bestanden** – vom Nutzer bestätigt |
| AP02-T04 | Vereinsrolle eines geeigneten Mitglieds ändern | Rolle wird gespeichert und bleibt nach Neuladen bestehen | **Bestanden** – vom Nutzer bestätigt; anschließend wurde die Teständerung wie vereinbart zurückgenommen |
| AP02-T05 | Mitglied mit vorhandener Mannschaftsrolle entfernen | Entfernung wird blockiert; verständlicher Hinweis auf zuerst zu entfernende Mannschaftsrollen erscheint | **Bestanden** – vom Nutzer bestätigt |
| AP02-T06 | Superadmin anmelden | Plattformverwaltung öffnet sich; es wird kein Verein automatisch ausgewählt | **Bestanden** – vom Nutzer bestätigt |
| AP02-T07 | Vereinsadmin nach vorheriger Superadmin-Sitzung anmelden | Es wird nur die Vereinsverwaltung angezeigt, nicht das zuvor sichtbare Plattformadmin-Panel | **Bestanden** – nach Korrektur vom Nutzer bestätigt |

## 3. Technische Prüfung der Schutzfunktionen

Am 26.10.2026 wurden die Definitionen und Ausführungsrechte der folgenden DEV-Datenbankfunktionen read-only geprüft:

- `get_club_members_v2`
- `get_club_players`
- `admin_set_club_member_role`
- `admin_remove_club_member`
- `admin_add_club_member`
- `is_club_admin`
- `is_club_member`

Feststellungen:

- Die Verwaltungsfunktionen prüfen serverseitig die angemeldete Identität und die Berechtigung für den angefragten Verein.
- Die Funktionen sind `SECURITY DEFINER`; ihr Berechtigungsmodell und Suchpfad bleiben Bestandteil der Sicherheitsprüfung.
- Anonyme Benutzer haben keine EXECUTE-Berechtigung auf die geprüften Verwaltungsfunktionen; `authenticated` hat EXECUTE.
- Rollenänderungen sind auf `member` und `club_admin` beschränkt.
- Im Code sind Schutzregeln vorgesehen, die das Herabstufen bzw. Entfernen des letzten Vereinsadmins und das Entfernen von Mitgliedern mit Mannschaftsrollen verhindern sollen.
- `club_members` hat `user_id` als Primärschlüssel. Damit kann ein Nutzer in der aktuellen Datenstruktur nur einmal als Vereinsmitglied eingetragen sein. `admin_add_club_member` prüft zusätzlich, ob der Nutzer bereits einem anderen Verein zugeordnet ist.
- Die globale Speicherung der Vereinsrolle in `club_member_roles` ist in Verbindung mit dieser Ein-Verein-pro-Nutzer-Regel der aktuelle Datenmodellansatz. Mehrfachmitgliedschaften und vereinsbezogene Rollen je Nutzer sind ausdrücklich nicht Teil des jetzigen Umfangs.

**Wichtige Abgrenzung:** Die Schutzlogik wurde im Datenbankcode geprüft. Das ist kein Ersatz für einen praktischen Integrationstest der tatsächlichen UI-/RPC-Verbindung.

## 4. Einordnung der Rollenmodellierung

Die Tabelle `club_member_roles` speichert `user_id` und `role`, ohne `club_id`. Für die aktuelle Produktentscheidung (ein Nutzer kann nur einem Verein angehören) ist das konsistent mit der bestehenden Struktur von `club_members`, deren Primärschlüssel `user_id` eine zweite Vereinsmitgliedschaft verhindert.

Daher wird **keine vorsorgliche Datenmodellmigration** zur Unterstützung von Mehrfachmitgliedschaften vorgenommen. Sollte sich die Produktentscheidung später ändern, müssen Mitgliedschafts- und Rollenmodell gemeinsam neu bewertet werden.

Globale Superadmins bleiben ein ausdrücklich vorgesehener Sonderfall: `is_club_admin` gibt für sie vereinsübergreifend true zurück. Die UI verlangt dennoch eine explizite Vereinsauswahl.

## 5. Offene Tests / bekannte Einschränkungen

| ID | Test | Status und nächster Schritt |
|---|---|---|
| AP02-T08 | Zugriff eines Vereinsadmins auf einen fremden Verein | **Offen – aktuell nicht durchführbar.** In DEV existiert nur ein Verein. Später mit einem sicher vorbereiteten zweiten Testverein prüfen. |
| AP02-T09 | Letzten Vereinsadmin herabstufen/entfernen | **Offen – nicht praktisch getestet.** Die Oberfläche bietet dem angemeldeten Vereinsadmin keine Funktion, die eigene Vereinsrolle zu ändern. Es wurde kein riskanter Umweg über direkte Datenbankänderungen oder das Entfernen anderer Admins versucht. Die Schutzlogik wurde im Datenbankcode geprüft. Für einen Integrationstest ist ein sicherer Testaufbau nötig. |
| AP02-T10 | Mitglied ohne Mannschaftsrollen erfolgreich entfernen | **Offen – nicht praktisch getestet.** Es gibt kein ausdrücklich entbehrliches Testkonto. Bestehende Mitglieder werden nicht allein zu Testzwecken entfernt. Der Test ist nach Einrichtung eines sicheren Testkontos nachzuholen. |

## 6. Bekannte DEV-Testbedingungen

- In der DEV-Datenbank existiert zum Prüfzeitpunkt ein Verein: `AP02 – Testverein DEV`.
- Das zugeordnete Team `Jugendmannschaft DEV` enthält 22 Spieler.
- Ein erfolgreicher UI-Test ersetzt keinen vollständigen Sicherheitstest.
- Die bereits abgestimmten UI/UX-Zielbilder bleiben verbindlich. Der UI-Abgleich ist weiterhin als separater Umsetzungsschritt eingeplant.

## 7. Abschluss und nächste Schritte

1. **AP02 für den aktuellen DEV-Umfang dokumentarisch abschließen**, mit den offenen Tests AP02-T08 bis AP02-T10 ausdrücklich als Einschränkungen.
2. Keine Testmitglieder ohne ausdrückliche Freigabe entfernen und keine Schutzregeln durch direkte Datenbankänderungen umgehen.
3. Danach gezielte AP03-Bestandsaufnahme durchführen: Rollenmatrix, Berechtigungsregeln, vorhandene Schutzmechanismen und verbleibende Lücken.
4. Anschließend die Verwaltungsseiten mit dem abgestimmten Ziel-UI vergleichen und UI/UX-Anpassungen planen.
5. Vor einer späteren Freigabe die offenen Integrationstests mit einem sicheren Testaufbau nachholen.

## 8. Release-/Branch-Schutz

Dieses Protokoll dokumentiert ausschließlich den DEV-Arbeitsstand. Es ist keine PROD-Freigabe. PR #2 bleibt offen und Draft; es wird nicht gemergt. PROD bleibt unverändert.
