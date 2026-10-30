# Geplante Tauchgänge: vollständige Liste

Date: 2026-10-20
Status: implemented, see PR #3560
Issue: #3551

## Problem

Im Planungs-Hub zeigt die Zeile "Tauchplan" (`_PlannerSection`,
`lib/features/planning/presentation/widgets/planning_list_content.dart:189-235`)
unterhalb der Werkzeug-Kachel die zuletzt bearbeiteten gespeicherten Tauchpläne.
Diese Liste ist auf die drei neuesten Einträge begrenzt:

```dart
final recentPlans =
    ref.watch(divePlanSummariesProvider).valueOrNull?.take(3).toList() ??
    const [];
```

Das `.take(3)` ist reiner UI-Code; der zugrunde liegende Provider
(`divePlanSummariesProvider`,
`lib/features/planner/presentation/providers/plan_repository_providers.dart:12-18`)
liefert bereits alle Pläne, sortiert nach `updatedAt` absteigend
(`DivePlanRepository.getAllPlanSummaries`,
`lib/features/planner/data/repositories/dive_plan_repository.dart:517-520`).
Divern mit mehr als drei gespeicherten Plänen fehlt ein Weg, alle zu sehen,
und keine Möglichkeit, die Liste selbst zu gruppieren oder zu sortieren.

Ein bestehendes `SavedPlansSheet`
(`lib/features/planner/presentation/widgets/saved_plans_sheet.dart`) zeigt
zwar bereits alle Pläne ungekürzt, ist aber ein Bottom Sheet ohne eigene
Route, dient einem anderen Zweck (Plan laden innerhalb des Dive-Planner-
Werkzeugs) und bleibt von diesem Konzept unberührt.

## Decisions

- **Neue, eigenständige Seite statt Sheet-Wiederverwendung.** Die
  vollständige Liste bekommt eine eigene Seite mit eigener Route, unabhängig
  vom bestehenden `SavedPlansSheet`. Das Sheet bleibt für seinen heutigen
  Zweck unverändert; es gibt also zwei Stellen im Code, die im Kern "alle
  Pläne" anzeigen, bewusst getrennt, um das bestehende Lade-Verhalten im
  Planner nicht zu verändern.
- **Zusätzlicher Menüpunkt, Vorschau wandert dorthin.** "Geplante
  Tauchgänge" erscheint als neue Zeile unterhalb der bestehenden
  "Tauchplan"-Zeile im Planungs-Hub. Die bestehende Zeile öffnet weiterhin
  direkt den Dive Planner, verliert aber ihre Vorschau der letzten 3 Pläne
  (`_PlannerSection` zeigt künftig nur noch die Werkzeug-Kachel selbst). Die
  neue Zeile übernimmt diese Vorschau (letzte 3 Pläne); ein Tap darauf öffnet
  die neue vollständige Seite. Damit zeigt keine der beiden Zeilen dieselben
  Einträge doppelt.
- **Neue Zeile immer sichtbar, auch ohne Pläne.** Die Zeile "Geplante
  Tauchgänge" erscheint unabhängig davon, ob bereits Pläne existieren
  (konsistent mit dem heutigen Verhalten der Planer-Kachel, die ebenfalls
  bei null Plänen sichtbar bleibt). Bei null Plänen zeigt die Zeile keine
  Vorschau-Einträge, ein Tap öffnet eine leere vollständige Liste.
- **Neue Seite nimmt immer das volle Fenster ein.** Die Seite erhält
  `PlanningToolPresentation.pushedPage`, wie der Dive Planner
  (`planning_tools.dart:14-19`), nicht `detailPane`. Begründung: eigene
  Steuerelemente für Gruppierung/Sortierung plus potenziell lange,
  gruppierte Liste passen nicht sinnvoll in die ca. 440px breite
  Detail-Spalte des Master-Detail-Layouts.
- **Gruppierung nach allen vier `PlanMode`-Werten einzeln.** Das Datenmodell
  kennt `enum PlanMode { oc, ccr, scr, pscr }`
  (`lib/features/planner/domain/entities/dive_plan.dart:14`). Alle vier
  Werte werden als eigene, separate Gruppen angezeigt; keine Zusammenfassung
  von SCR/PSCR mit OC/CCR.
- **Sortierung nach "Erstellung" nutzt `updatedAt`.** `DivePlanSummary`
  trägt heute nur `updatedAt`, kein `createdAt`
  (`dive_plan.dart:431-460`). Statt das Modell und die zugrunde liegende
  Query zu erweitern, wird "Erstellung" als Sortierkriterium auf das
  bestehende `updatedAt`-Feld abgebildet. Konsequenz: Ein Plan, der nach dem
  Anlegen nochmals bearbeitet wurde, erscheint bei dieser Sortierung an der
  Stelle seiner letzten Änderung, nicht seines ursprünglichen Anlagezeit-
  punkts. Das ist eine bewusst akzeptierte Näherung, keine exakte
  "Erstellungsdatum"-Sortierung.
- **Sortierfelder:** Datum (= `updatedAt`, als Näherung für Erstellung),
  Tauchtiefe, Bezeichnung — wie ursprünglich gewünscht. Kein zusätzliches
  Feld wie "Tauchzeit"/Laufzeit vorgesehen, da nicht angefragt.
- **Benutzer steuert Gruppierung und Sortierung unabhängig voneinander.**
  Wie beim bestehenden Vorbild bei Dive Sites (`SiteGroupBy` getrennt vom
  Sortierfeld) sind Gruppierung (nach `PlanMode`) und Sortierung (innerhalb
  jeder Gruppe) zwei unabhängige Einstellungen, nicht gekoppelt.

## Bestehende Infrastruktur als Vorbild

Zwei vorhandene, generische Muster im Code decken das Vorhaben ab, ohne dass
grundlegend neue Konzepte eingeführt werden müssen:

- **Sortierung:** `DiveSortField`-Enum + `SortState<T>`-Provider
  (`lib/core/constants/sort_options.dart`,
  `lib/features/dive_log/presentation/providers/dive_providers.dart:54-58`)
  zusammen mit dem generischen `SortBottomSheet<T extends Enum>`
  (`lib/shared/widgets/sort_bottom_sheet.dart`). Für diese Seite: ein neues
  `enum DivePlanSortField { date, depth, name }` nach demselben Muster, ein
  `StateProvider<SortState<DivePlanSortField>>` analog zu
  `diveSortProvider`, Wiederverwendung von `SortBottomSheet`.
- **Gruppierung:** Das Gruppierungssystem von Dive Sites (`SiteGroupBy`,
  `_groupSites()`, `SiteOuterGroup`/`SiteSubGroup`,
  `lib/features/dive_sites/domain/utils/site_grouping.dart`) ist für
  dynamische, freitextbasierte Gruppen mit verschachtelten Untergruppen und
  Auf/Zu-Zuständen gebaut und damit zu schwer für diesen Fall. Vorbild ist
  stattdessen das leichtere Equipment-Muster
  (`lib/features/equipment/presentation/widgets/group_by_location_switch.dart`):
  eine einfache, feste Gruppierung nach `PlanMode` in Enum-Deklarations-
  reihenfolge (OC, CCR, SCR, PSCR), keine Verschachtelung, keine dynamische
  Gruppenanzahl. Leere Gruppen werden ausgeblendet. Gruppierung und
  Sortierung gelten nur für die Sitzung, analog zu `SiteGroupBy` ("Session-
  only, like the list's sort").
- **Fehlende Tiefenangabe beim Sortieren nach Tiefe:**
  `DivePlanSummary.maxDepth` ist nullable (ein Plan ohne berechnete Segmente
  hat `maxDepth == null`, `dive_plan_repository.dart:509,527`). Wie beim
  bestehenden Vorbild für Dives (`a.maxDepth ?? 0`, `dive_providers.dart:182`)
  wird eine fehlende Tiefe als 0 behandelt.
- **Gruppen-Beschriftung:** Kurzform wie im Bestandscode
  (`summary.mode.name.toUpperCase()`, `planning_list_content.dart:226`),
  keine ausgeschriebenen Namen.

## UI implications

- Neue Zeile "Geplante Tauchgänge" in
  `lib/features/planning/presentation/widgets/planning_list_content.dart`,
  unterhalb der bestehenden `_PlannerSection`-Zeile, mit den letzten 3
  Einträgen als Vorschau (gleiche Datenquelle,
  `divePlanSummariesProvider.take(3)`). `_PlannerSection` selbst verliert
  diese Vorschau (siehe Decisions oben), damit die Einträge nicht doppelt
  erscheinen.
- Neue Seite + Route (z. B. `/planning/dive-plans`, analog zum bestehenden
  `/planning/dive-planner`-Muster in
  `lib/core/router/app_router.dart:314-339`), erreichbar über einen Tap auf
  die neue Zeile.
- Auf der neuen Seite: Liste aller Pläne, standardmässig gruppiert nach
  `PlanMode` (vier feste Gruppen: OC, CCR, SCR, PSCR), innerhalb jeder Gruppe
  sortiert nach der aktuellen Sortierauswahl (Datum/Tiefe/Bezeichnung).
  Gruppierung und Sortierung über UI-Elemente wählbar, analog zu den
  bestehenden Mustern bei Dive Sites/Dive Log.
- Leere Gruppen (kein Plan eines bestimmten Modus vorhanden) werden nicht
  angezeigt; Details zur genauen Darstellung leerer Zustände sind nicht Teil
  dieses Konzepts.

## Revision (same session, after first implementation pass)

The desktop detail pane (`PlanningSummaryWidget`'s "Saved plans" section)
already showed every saved plan beside the hub, just without grouping or
sorting. Rather than maintain two separate full-list implementations, the
grouped/sortable list became one shared widget, `SavedPlansList`
(`lib/features/planner/presentation/widgets/saved_plans_list.dart`), used by
both surfaces:

- **Narrow window (phone-width):** the hub's own row, renamed from "Planned
  Dives" to **"Saved plans"** to match the desktop pane's label it now
  stands in for (reusing the existing `planning_summary_savedPlans` l10n key
  rather than a second, separately maintained string). Tapping it pushes
  `PlannedDivesPage`, an `AppBar` + sort action around `SavedPlansList`.
- **Desktop split view (master-detail breakpoint):** the row is hidden
  entirely. The signal is `PlanningListContent.onToolSelected == null`
  (already how this widget distinguishes narrow from split-view rendering,
  see its class doc), not a new breakpoint check. The detail pane already
  shows `SavedPlansList` inline (with a sort button next to the "SAVED
  PLANS" label instead of an app bar action), so the row would only
  duplicate it.
- **Sort state is shared by construction**, not by a deliberate
  synchronization decision: both surfaces render the same `SavedPlansList`
  widget reading the same `divePlanSortProvider`, and the two can never be
  visible at once (one layout excludes the other), so there is nothing to
  keep in sync.
- The desktop pane's previous `plans.take(8)` cap is removed now that the
  list is grouped; all saved plans show, same as the phone's full page.
- The `_PlannedDivesSection` hub-row widget only appears in the list when
  `onToolSelected == null`; the keyboard-navigation key list and the
  `_PlannerSection`/`_PlannedDivesSection` split from the first pass are
  otherwise unchanged (see Decisions above).

## Out of scope / open questions

- Exakte Route, Seitenname und genaue Platzierung im Routenbaum werden erst
  in einem Implementierungsplan festgelegt.
- Detailliertes visuelles Design der Gruppen-Header, Sortier-/Gruppier-
  Auswahl-UI (Icons, genaue Beschriftungen) ist hier nicht entworfen.
- Issue #3551 wurde erstellt und ist über PR #3560 umgesetzt (kein
  separater Implementierungsplan geschrieben; die Entscheidungen oben
  reichten für die Umsetzung).
- Ob die neue Seite künftig auch Lösch-/Bearbeiten-Aktionen direkt aus der
  Liste anbietet, ist nicht Teil dieser Anfrage und wird hier nicht
  entschieden.
