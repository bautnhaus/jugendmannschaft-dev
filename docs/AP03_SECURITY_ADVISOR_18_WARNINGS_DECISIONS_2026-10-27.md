# AP03 – Entscheidungsliste zu den 18 Supabase-Security-Advisor-Warnungen

**Stand:** 27.10.2026  
**Umgebung:** ausschließlich Supabase DEV, Projekt `pzazqvvoruqnqhcorbwx`  
**Zweck:** dauerhafte Ablage der gemeinsam einzeln geprüften 18 Warnungen, damit die Bewertung nicht erneut von vorn beginnt.  
**Geltungsbereich:** ausschließlich die 18 Advisor-Hinweise `authenticated_security_definer_function_executable`; keine allgemeine Sicherheitszertifizierung und keine PROD-Freigabe.

## Ergebnis

Die 18 Warnungen wurden einzeln besprochen und bewertet. Die Warnung entsteht, weil eine Funktion sowohl `SECURITY DEFINER` als auch für `authenticated` ausführbar ist. Das ist ein Prüfsignal, aber nicht automatisch eine Schwachstelle. Die Funktionen müssen für beabsichtigte App-Aktionen erreichbar bleiben, sofern ihre interne Autorisierung stimmt.

- **Warnungen 1–17:** Entscheidung „kein zusätzlicher Handlungsbedarf allein aufgrund dieses Advisor-Hinweises“. Die bestehende Funktion und ihr vorgesehener Zweck bleiben bestehen; keine pauschale Entziehung von EXECUTE-Rechten.
- **Warnung 18 – `save_player_with_positions(...)`:** gezielte Abweichung vom AP02-Super-Admin-Konzept gefunden und am 27.10.2026 in DEV korrigiert. Die Funktion erlaubt nun zusätzlich einen globalen Super-Admin ohne Teammitgliedschaft, wobei beim Bearbeiten die konkrete Team-ID angegeben werden muss. Die vorhandenen Prüfungen für Teamzugehörigkeit der Positionen, Eingabewerte und Verhinderung eines Teamwechsels bleiben erhalten.
- Nach der Korrektur wurde die Funktionsdefinition erneut aus DEV gelesen. EXECUTE bleibt für `authenticated` erlaubt und für `anon` nicht erlaubt.
- Die Advisor-Warnung für diese Funktion kann weiterhin erscheinen, weil die Funktion absichtlich von angemeldeten Nutzern aufgerufen werden darf. Das allein ist kein Grund, die Rechte erneut zu ändern.

## Einzelregister

| Nr. | Funktion | Entscheidung / Status |
|---:|---|---|
| 1 | `admin_add_club_member` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 2 | `admin_add_club_member_by_email` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 3 | `admin_add_team_role` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 4 | `admin_create_team` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 5 | `admin_remove_club_member` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 6 | `admin_remove_team_role` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 7 | `admin_set_club_member_role` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 8 | `admin_set_trainer_label` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 9 | `get_club_members` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 10 | `get_club_members_v2` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 11 | `get_club_players` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 12 | `get_team_trainers_v2` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 13 | `is_club_admin` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 14 | `is_club_member` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 15 | `is_super_admin` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 16 | `is_team_admin` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 17 | `is_team_member` | Kein zusätzlicher Handlungsbedarf allein aufgrund der Advisor-Warnung |
| 18 | `save_player_with_positions` | DEV-Korrektur angewendet; UI-/Rollenintegrationstest wegen fehlender Super-Admin-Frontendfunktionen bewusst auf die spätere Rollen-UI-Arbeit verschoben |

## Bewusst zurückgestellte Tests

Die Tests, die einen Super-Admin ohne Teammitgliedschaft beim Anlegen/Bearbeiten von Spielern erfordern, werden nicht durch Quick-and-dirty-UI oder künstliche Teammitgliedschaften ermöglicht. Sie werden gemeinsam mit der strukturell passenden Verwaltung für Super-Admin, Vereinsadmin und Mannschaftsrollen umgesetzt und dann in DEV getestet.

Bis dahin gilt:
- Die Datenbankkorrektur ist angewendet und die Funktionsdefinition wurde nachgelesen.
- Das fachliche Verhalten der Super-Admin-Spielerverwaltung ist **noch nicht durch Frontend-Integrationstests bestätigt**.
- Keine PROD-Änderung und keine Freigabe für PROD aus diesem Dokument.

## Abschlussregel für diese Warnungsrunde

Diese Liste ist das maßgebliche Entscheidungsregister für die 18 einzeln geprüften Advisor-Warnungen. Bei späteren Prüfungen wird sie wiederverwendet. Eine erneute Bewertung ist nur nötig, wenn sich eine der betroffenen Funktionsdefinitionen, Rollenregeln oder EXECUTE-Rechte wesentlich ändern.

## Abgrenzung zum gesamten AP03

Der Abschluss dieser Warnungsrunde bedeutet nicht automatisch, dass alle AP03-Sicherheitsprüfpunkte erledigt sind. Andere bereits dokumentierte Themen – insbesondere die Konsistenzprüfung von `matchday_attendance` beim DELETE und die Erzwingung der Vereinszugehörigkeit im Trainer-Einladungsprozess – sind getrennte Punkte. Sie sollen nicht in die 18 Warnungen hineingezogen oder durch deren Abschluss stillschweigend als erledigt markiert werden. Sie müssen entweder gezielt behoben oder ausdrücklich mit Risiko/Begründung in einen späteren Arbeitsschritt überführt werden, bevor AP03 insgesamt als abgeschlossen bezeichnet wird.
