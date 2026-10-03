# Planned Trip Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session (the build-feature workflow fixes Native execution). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every trip type the same six-tab page with a Prepare overview before departure, one gear-and-cylinders list, an itinerary that works off a boat, and a story that scrolls as one column with a map per day.

**Architecture:** `TripDetailPage` loses its two layouts and renders one `TripDetailTabs` widget (Overview, Itinerary, Gear, Checklist, Dives, Photos). The Overview tab picks a mode by date: `TripPrepareOverview` before the start date, the flattened `TripStoryView` from the first day on. New widgets are small files under `lib/features/trips/presentation/`; the old header cards, the pinned story band and the trip-level map are deleted at the end, once nothing imports them.

**Tech Stack:** Flutter, Riverpod (FutureProvider families), Drift (no schema change), flutter_map 8 with the app's `TileCacheService`, ARB localization in 11 locales, flutter_test widget tests.

**Spec:** `docs/superpowers/specs/2026-10-02-planned-trip-page-redesign-design.md`

## Global Constraints

- Issue #2845; the PR body says `Closes #2845` and `Closes #2658`.
- Every new string lands in all 11 ARB files (`lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`), inserted beside a neighbouring key of the same `trips_*` group in EACH file (every ARB is feature-grouped, not sorted). Informal register in de, es, it; es never uses "tú". `test/l10n/arb_parity_test.dart` fails on any missing key.
- After editing ARBs run `flutter gen-l10n` (the generated `lib/l10n/arb/app_localizations*.dart` files are tracked) and commit them with the ARB change.
- No em dashes anywhere, no emojis, no AI attribution in commits or the PR.
- Presentation code reads numbers only through `readNumber` (`lib/shared/widgets/forms/number_input_validation.dart`); `test/architecture/number_parsing_single_source_test.dart` guards it.
- `ListTile.trailing` may hold only fixed-width widgets (an `Icon`, an icon-only `IconButton` or `PopupMenuButton`); never text, a chip or a text button (`test/architecture/list_tile_trailing_width_test.dart`).
- Service status wording is composed only in `service_status_indicator.dart` and `trip_service_alert_list.dart` (`test/architecture/service_status_wording_single_source_test.dart`); the gear rows call a function exported from the latter.
- Dates render through `UnitFormatter` (`formatDate`, `formatMonthDay`), never `DateFormat` directly.
- Switch statements over `DayType` must stay exhaustive; the compiler enforces it.
- Before each commit: `dart format .`, `flutter analyze` (zero issues, infos included), the task's tests. After any task that adds a file under `lib/`: `flutter test test/architecture/`.
- Run tests with `TMPDIR=<scratchpad>/tmp flutter test <files>`; never pipe `flutter test` into `grep` (the exit code is lost); never run two test batches at once.
- Stage explicit paths with `git add <paths>`; never `git add -A` or `git add test`. The throwaway `test/tmp_shots/` directory is never committed.
- A test that replaces process-wide state (`DatabaseService`, `clock`) restores it in `addTearDown`.

## Rulings for review

Decisions the plan makes where the spec was silent; the reviewer may overturn them.

- R1: `setPlannedDives` also retypes a Rest row back to Dive day when a positive count is saved on it, so "Rest, 2 dives planned" cannot exist.
- R2: The gear row's service line reuses the existing trip-relative sentence (`trips_serviceAlert_dueBefore`: "{kind} due before {date}") instead of the spec's "due in 7 d", because the wording guard allows that sentence in exactly one file and the panel already used it.
- R3: The Overview summary rows put the summary in the `ListTile` subtitle, not in `trailing`, to satisfy the trailing-width guard.
- R4: `ItineraryDay.generateForTrip` keeps `tripType` optional, defaulting to `TripType.liveaboard`, so every existing caller and test keeps its behaviour until Task 7 removes the hero's button.
- R5: The Overview's Itinerary row counts "dives planned" as the sum of each row's `plannedDives` when set, else `trip.divesPerDayTarget` for a Dive-day row, else 0; the line is omitted when the sum is 0.

## Review Focus

Inputs the spec implies but no task's tests would otherwise exercise, with the test that pins each one added to its owning task:

1. A trip whose start date is today: Overview must be the Story (in progress), not Prepare. Task 5, test "a trip starting today shows the story".
2. Two dives on one day at the same site: both pins must be hittable and highlight different rows. Task 3, test "same-site dives get distinct pins".
3. A maritime day type on a resort trip (row synced from a liveaboard before the type changed): the sheet must list it and save without retyping. Task 2, test "a sea day on a resort trip keeps its type".
4. Rental cylinders on a trip with a packed cylinder item: the owned cylinder appears once, under Cylinders, and never under Packed. Task 6, test "an owned cylinder is listed once".
5. A one-day trip: Generate must produce a single Dive day off a boat (no Travel day sandwich). Task 1, test "a one-day resort trip is a single dive day".

---

### Task 1: Day types Travel and Rest, per-type generation, Rest typing on planned dives

**Files:**
- Modify: `lib/core/constants/enums.dart:676-690` (`enum DayType`)
- Modify: `lib/features/trips/presentation/helpers/day_type_l10n.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart:273-300` (`_dayTypeIcon`, `_dayTypeColor`)
- Modify: `lib/features/trips/domain/entities/itinerary_day.dart:45-85` (`generateForTrip`)
- Modify: `lib/features/trips/data/repositories/itinerary_day_repository.dart:158-230` (`setPlannedDives`)
- Modify: all 11 `lib/l10n/arb/app_*.arb` (two keys beside `trips_dayType_disembark`)
- Test: `test/features/trips/domain/entities/itinerary_day_test.dart`
- Test: `test/features/trips/data/repositories/itinerary_day_repository_test.dart`
- Test: `test/features/trips/presentation/helpers/day_type_l10n_test.dart` (create)

**Interfaces:**
- Produces: `DayType.travel`, `DayType.rest`; `ItineraryDay.generateForTrip({required String tripId, required DateTime startDate, required DateTime endDate, TripType tripType = TripType.liveaboard})`; l10n getters `trips_dayType_travel`, `trips_dayType_rest`.

- [ ] **Step 1: Write the failing generate tests**

Append inside `group('ItineraryDay.generateForTrip', ...)` in `test/features/trips/domain/entities/itinerary_day_test.dart` (add `import 'package:submersion/core/constants/enums.dart';` if the file lacks it; it already imports it for `DayType`):

```dart
    test('a resort trip travels on its first and last day', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2026, 10, 14),
        endDate: DateTime(2026, 10, 21),
        tripType: TripType.resort,
      );
      expect(days, hasLength(8));
      expect(days.first.dayType, DayType.travel);
      expect(days.last.dayType, DayType.travel);
      for (final d in days.sublist(1, 7)) {
        expect(d.dayType, DayType.diveDay);
      }
    });

    test('a one-day resort trip is a single dive day', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2026, 10, 14),
        endDate: DateTime(2026, 10, 14),
        tripType: TripType.dayTrip,
      );
      expect(days.single.dayType, DayType.diveDay);
    });

    test('a two-day shore trip is two dive days', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2026, 10, 14),
        endDate: DateTime(2026, 10, 15),
        tripType: TripType.shore,
      );
      expect(days.map((d) => d.dayType), [DayType.diveDay, DayType.diveDay]);
    });

    test('a liveaboard keeps embark and disembark at every length', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2026, 10, 14),
        endDate: DateTime(2026, 10, 15),
        tripType: TripType.liveaboard,
      );
      expect(days.map((d) => d.dayType), [DayType.embark, DayType.disembark]);
    });
```

- [ ] **Step 2: Run them to see them fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/domain/entities/itinerary_day_test.dart`
Expected: compile error, `tripType` is not a named parameter and `DayType.travel` is undefined.

- [ ] **Step 3: Add the enum values and the generation rule**

In `lib/core/constants/enums.dart`, replace the `DayType` value list:

```dart
enum DayType {
  diveDay('Dive Day'),
  seaDay('Sea Day'),
  portDay('Port Day'),
  embark('Embark'),
  disembark('Disembark'),

  /// A land trip's first and last day: getting there and back (#2845).
  travel('Travel'),

  /// A day planned at no dives (#2658).
  rest('Rest');
```

In `lib/features/trips/domain/entities/itinerary_day.dart`, replace `generateForTrip`:

```dart
  /// Generate itinerary days for a trip date range. A liveaboard opens with
  /// Embark and closes with Disembark; every other type travels on its first
  /// and last day, with Dive days between. A land trip of one or two days has
  /// no middle to travel around, so it gets Dive days only.
  static List<ItineraryDay> generateForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    TripType tripType = TripType.liveaboard,
  }) {
    const uuid = Uuid();
    final now = DateTime.now();
    // Use calendar arithmetic to avoid DST issues
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = (end.difference(start).inHours / 24).round() + 1;
    final liveaboard = tripType == TripType.liveaboard;
    final days = <ItineraryDay>[];

    for (int i = 0; i < totalDays; i++) {
      final first = i == 0;
      final last = i == totalDays - 1;
      final DayType type;
      if (liveaboard) {
        type = first
            ? DayType.embark
            : last
            ? DayType.disembark
            : DayType.diveDay;
      } else if (totalDays <= 2) {
        type = DayType.diveDay;
      } else {
        type = first || last ? DayType.travel : DayType.diveDay;
      }

      days.add(
        ItineraryDay(
          id: uuid.v4(),
          tripId: tripId,
          dayNumber: i + 1,
          date: DateTime(start.year, start.month, start.day + i),
          dayType: type,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return days;
  }
```

`enums.dart` is already imported there for `DayType`; `TripType` lives in the same file.

In `lib/features/trips/presentation/helpers/day_type_l10n.dart`, add two cases to the switch:

```dart
      case DayType.travel:
        return l10n.trips_dayType_travel;
      case DayType.rest:
        return l10n.trips_dayType_rest;
```

In `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart`, add to `_dayTypeIcon`:

```dart
      case DayType.travel:
        return Icons.flight_takeoff;
      case DayType.rest:
        return Icons.beach_access;
```

and to `_dayTypeColor`:

```dart
      case DayType.travel:
        return colorScheme.tertiary;
      case DayType.rest:
        return colorScheme.onSurfaceVariant;
```

- [ ] **Step 4: Add the two ARB keys to all 11 files**

In `lib/l10n/arb/app_en.arb`, directly after the `"trips_dayType_disembark": "Disembark",` line:

```json
  "trips_dayType_travel": "Travel",
  "trips_dayType_rest": "Rest",
```

In each other locale, after that locale's `trips_dayType_disembark` line:

| locale | travel | rest |
| --- | --- | --- |
| ar | "سفر" | "راحة" |
| de | "Anreise" | "Ruhetag" |
| es | "Viaje" | "Descanso" |
| fr | "Voyage" | "Repos" |
| he | "נסיעה" | "מנוחה" |
| hu | "Utazás" | "Pihenőnap" |
| it | "Viaggio" | "Riposo" |
| nl | "Reisdag" | "Rustdag" |
| pt | "Viagem" | "Descanso" |
| zh | "旅行" | "休息" |

Then run `flutter gen-l10n`.

- [ ] **Step 5: Run the generate tests and the ARB parity test**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/domain/entities/itinerary_day_test.dart test/l10n/arb_parity_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing repository tests**

Append inside `group('planned dives (fill forecast)', ...)` in `test/features/trips/data/repositories/itinerary_day_repository_test.dart`:

```dart
      test('a day with no row planned at 0 is typed Rest (#2658)', () async {
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: 0,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.rest);
        expect(day.plannedDives, 0);
      });

      test('a dive day planned at 0 becomes a Rest day', () async {
        await repository.saveAll([
          createTestDay(dayNumber: 3, date: DateTime(2025, 3, 3)),
        ]);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: 0,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.rest);
      });

      test('a Rest day planned at 2 becomes a dive day again (R1)', () async {
        await repository.saveAll([
          createTestDay(
            dayNumber: 3,
            date: DateTime(2025, 3, 3),
            dayType: DayType.rest,
          ),
        ]);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: 2,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.diveDay);
        expect(day.plannedDives, 2);
      });

      test('a port day planned at 0 keeps its type', () async {
        await repository.saveAll([
          createTestDay(
            dayNumber: 4,
            date: DateTime(2025, 3, 4),
            dayType: DayType.portDay,
          ),
        ]);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 4),
          plannedDives: 0,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.portDay);
      });
```

- [ ] **Step 7: Run them to see them fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/data/repositories/itinerary_day_repository_test.dart`
Expected: the first two fail with `DayType.diveDay` where `DayType.rest` was expected; the third fails with `DayType.rest`.

- [ ] **Step 8: Retype in setPlannedDives**

In `lib/features/trips/data/repositories/itinerary_day_repository.dart`, inside `setPlannedDives`, replace the `if (existing.isNotEmpty) { ... }` update block with one that also retypes:

```dart
        if (existing.isNotEmpty) {
          await (_db.update(
            _db.tripItineraryDays,
          )..where((t) => t.id.isIn(existing))).write(
            TripItineraryDaysCompanion(
              plannedDives: Value(plannedDives),
              updatedAt: Value(now),
            ),
          );
          // A plan of none is a rest day, and a rest day planned again is a
          // dive day (#2658). Any other type says what the day is for and
          // keeps it.
          final retype = switch (plannedDives) {
            0 => (from: DayType.diveDay, to: DayType.rest),
            final n? when n > 0 => (from: DayType.rest, to: DayType.diveDay),
            _ => null,
          };
          if (retype != null) {
            await (_db.update(_db.tripItineraryDays)..where(
                  (t) =>
                      t.id.isIn(existing) & t.dayType.equals(retype.from.name),
                ))
                .write(
                  TripItineraryDaysCompanion(dayType: Value(retype.to.name)),
                );
          }
          written = existing;
        } else if (plannedDives != null) {
```

and in the insert branch add the type to the companion, after `date: day.millisecondsSinceEpoch,`:

```dart
                  dayType: Value(
                    plannedDives == 0 ? DayType.rest.name : DayType.diveDay.name,
                  ),
```

Add `import 'package:submersion/core/constants/enums.dart';` to the repository if it is not already imported (check the file head).

- [ ] **Step 9: Write the l10n coverage test**

Create `test/features/trips/presentation/helpers/day_type_l10n_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every DayType value has a label in every locale (#2845 added Travel and
/// Rest).
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('every day type has a label in $locale', (tester) async {
      final labels = <DayType, String>{};
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              for (final type in DayType.values) {
                labels[type] = type.localizedName(context);
              }
              return const SizedBox();
            },
          ),
        ),
      );
      for (final type in DayType.values) {
        expect(labels[type], isNotEmpty, reason: '$type in $locale');
      }
      expect(labels.values.toSet(), hasLength(DayType.values.length),
          reason: 'two day types share a label in $locale');
    });
  }
}
```

- [ ] **Step 10: Run the task's tests, format, analyze**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/domain/entities/itinerary_day_test.dart test/features/trips/data/repositories/itinerary_day_repository_test.dart test/features/trips/presentation/helpers/day_type_l10n_test.dart test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart test/features/trips/domain/entities/trip_story_day_test.dart test/l10n/arb_parity_test.dart`
Expected: PASS. Then `dart format .` and `flutter analyze` (zero issues).

- [ ] **Step 11: Commit**

```bash
git add lib/core/constants/enums.dart lib/features/trips/domain/entities/itinerary_day.dart lib/features/trips/presentation/helpers/day_type_l10n.dart lib/features/trips/presentation/widgets/trip_itinerary_tab.dart lib/features/trips/data/repositories/itinerary_day_repository.dart lib/l10n/arb test/features/trips/domain/entities/itinerary_day_test.dart test/features/trips/data/repositories/itinerary_day_repository_test.dart test/features/trips/presentation/helpers/day_type_l10n_test.dart
git commit -m "feat(trips): Travel and Rest day types, per-type itinerary generation"
```

---
### Task 2: Itinerary tab for every trip type

**Files:**
- Create: `lib/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart` (build, empty state, `_ItineraryDayCard`)
- Modify: `lib/features/trips/presentation/widgets/itinerary_day_edit_sheet.dart`
- Modify: all 11 ARB files (six keys beside `trips_itinerary_daySaveError`)
- Test: `test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart`
- Test: `test/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button_test.dart` (create)

**Interfaces:**
- Consumes: `ItineraryDay.generateForTrip(..., tripType:)` from Task 1; `tripByIdProvider(tripId)`, `itineraryDaysProvider(tripId)`, `numberedItineraryDaysProvider(tripId)`, `divesForTripProvider(tripId)`, `itineraryDayRepositoryProvider`.
- Produces: `TripItineraryGenerateButton({required Trip trip, required List<ItineraryDay> days})` (shows "Generate itinerary" when `days` is empty, "Fill in missing days" when some trip dates lack a row, nothing when every date has one); `showItineraryDayEditSheet({required BuildContext context, required ItineraryDay day, required String tripId, required bool isLiveaboard})`.
- l10n keys: `trips_itinerary_empty`, `trips_itinerary_fillMissing`, `trips_itinerary_plannedDives` (plural), `trips_itinerary_plannedDives_label`, `trips_itinerary_location_label`, `trips_itinerary_plannedDives_invalid`. Reuses `trips_story_generateItinerary` and `trips_story_generateItineraryError`.

- [ ] **Step 1: Add the ARB keys to all 11 files**

`app_en.arb`, after `"trips_itinerary_daySaveError": ...`:

```json
  "trips_itinerary_empty": "No itinerary yet. Generate one from the trip dates, or add days as you go.",
  "trips_itinerary_fillMissing": "Fill in missing days",
  "trips_itinerary_plannedDives": "{count, plural, =1{1 dive planned} other{{count} dives planned}}",
  "@trips_itinerary_plannedDives": {"placeholders": {"count": {"type": "int"}}},
  "trips_itinerary_plannedDives_label": "Planned dives",
  "trips_itinerary_plannedDives_invalid": "Enter a whole number of dives, or leave it blank.",
  "trips_itinerary_location_label": "Location",
```

Other locales, same six message keys (copy the `@` entry verbatim), after each file's `trips_itinerary_daySaveError`:

| key | de | es | fr | it | nl | pt |
| --- | --- | --- | --- | --- | --- | --- |
| empty | "Noch keine Reiseroute. Erstelle eine aus den Reisedaten oder füge Tage nach und nach hinzu." | "Aún no hay itinerario. Genera uno a partir de las fechas del viaje o añade días sobre la marcha." | "Pas encore d'itinéraire. Générez-en un à partir des dates du voyage, ou ajoutez des jours au fur et à mesure." | "Nessun itinerario ancora. Generane uno dalle date del viaggio o aggiungi i giorni man mano." | "Nog geen reisschema. Maak er een van de reisdata, of voeg dagen toe terwijl je gaat." | "Ainda sem itinerário. Gere um a partir das datas da viagem ou adicione dias à medida que avança." |
| fillMissing | "Fehlende Tage ergänzen" | "Completar los días que faltan" | "Compléter les jours manquants" | "Completa i giorni mancanti" | "Ontbrekende dagen aanvullen" | "Preencher dias em falta" |
| plannedDives | "{count, plural, =1{1 Tauchgang geplant} other{{count} Tauchgänge geplant}}" | "{count, plural, =1{1 inmersión planificada} other{{count} inmersiones planificadas}}" | "{count, plural, =1{1 plongée prévue} other{{count} plongées prévues}}" | "{count, plural, =1{1 immersione pianificata} other{{count} immersioni pianificate}}" | "{count, plural, =1{1 duik gepland} other{{count} duiken gepland}}" | "{count, plural, =1{1 mergulho planeado} other{{count} mergulhos planeados}}" |
| plannedDives_label | "Geplante Tauchgänge" | "Inmersiones planificadas" | "Plongées prévues" | "Immersioni pianificate" | "Geplande duiken" | "Mergulhos planeados" |
| plannedDives_invalid | "Gib eine ganze Zahl an Tauchgängen ein oder lass das Feld leer." | "Introduce un número entero de inmersiones o déjalo en blanco." | "Saisissez un nombre entier de plongées, ou laissez vide." | "Inserisci un numero intero di immersioni o lascia vuoto." | "Voer een heel aantal duiken in, of laat het leeg." | "Introduza um número inteiro de mergulhos ou deixe em branco." |
| location_label | "Ort" | "Lugar" | "Lieu" | "Luogo" | "Locatie" | "Local" |

| key | ar | he | hu | zh |
| --- | --- | --- | --- | --- |
| empty | "لا يوجد برنامج رحلة بعد. أنشئ واحدًا من تواريخ الرحلة، أو أضف الأيام تباعًا." | "אין עדיין מסלול. צרו אחד מתאריכי הטיול, או הוסיפו ימים תוך כדי." | "Még nincs útiterv. Készíts egyet az utazás dátumaiból, vagy adj hozzá napokat menet közben." | "还没有行程。根据旅行日期生成一个，或随时添加天数。" |
| fillMissing | "إكمال الأيام الناقصة" | "השלמת ימים חסרים" | "Hiányzó napok kitöltése" | "补全缺少的天数" |
| plannedDives | "{count, plural, =1{غوصة واحدة مخططة} other{{count} غوصات مخططة}}" | "{count, plural, =1{צלילה אחת מתוכננת} other{{count} צלילות מתוכננות}}" | "{count, plural, =1{1 tervezett merülés} other{{count} tervezett merülés}}" | "{count, plural, =1{计划 1 次潜水} other{计划 {count} 次潜水}}" |
| plannedDives_label | "الغوصات المخططة" | "צלילות מתוכננות" | "Tervezett merülések" | "计划潜水次数" |
| plannedDives_invalid | "أدخل عددًا صحيحًا من الغوصات، أو اتركه فارغًا." | "הזינו מספר שלם של צלילות, או השאירו ריק." | "Adj meg egy egész számot, vagy hagyd üresen." | "请输入整数的潜水次数，或留空。" |
| location_label | "الموقع" | "מיקום" | "Helyszín" | "地点" |

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing generate-button tests**

Create `test/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _RecordingRepo extends ItineraryDayRepository {
  final saved = <ItineraryDay>[];
  @override
  Future<void> saveAll(List<ItineraryDay> days) async => saved.addAll(days);
}

Trip _trip(TripType type) => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: DateTime(2026, 10, 14),
  endDate: DateTime(2026, 10, 17),
  tripType: type,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ItineraryDay _row(DateTime date) => ItineraryDay(
  id: 'r-${date.day}',
  tripId: 'trip-1',
  dayNumber: 1,
  date: date,
  dayType: DayType.portDay,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<_RecordingRepo> _pump(
  WidgetTester tester, {
  required Trip trip,
  required List<ItineraryDay> days,
}) async {
  final repo = _RecordingRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [itineraryDayRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TripItineraryGenerateButton(trip: trip, days: days),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('with no rows it offers Generate and writes every day typed '
      'for the trip', (tester) async {
    final repo = await _pump(tester, trip: _trip(TripType.resort), days: []);
    expect(find.text('Generate itinerary'), findsOneWidget);
    await tester.tap(find.text('Generate itinerary'));
    await tester.pumpAndSettle();
    expect(repo.saved.map((d) => d.dayType), [
      DayType.travel,
      DayType.diveDay,
      DayType.diveDay,
      DayType.travel,
    ]);
  });

  testWidgets('a liveaboard generates embark and disembark', (tester) async {
    final repo = await _pump(
      tester,
      trip: _trip(TripType.liveaboard),
      days: [],
    );
    await tester.tap(find.text('Generate itinerary'));
    await tester.pumpAndSettle();
    expect(repo.saved.first.dayType, DayType.embark);
    expect(repo.saved.last.dayType, DayType.disembark);
  });

  testWidgets('with some rows it offers Fill in missing days and adds only '
      'the missing dates', (tester) async {
    final repo = await _pump(
      tester,
      trip: _trip(TripType.resort),
      days: [_row(DateTime(2026, 10, 15))],
    );
    expect(find.text('Generate itinerary'), findsNothing);
    expect(find.text('Fill in missing days'), findsOneWidget);
    await tester.tap(find.text('Fill in missing days'));
    await tester.pumpAndSettle();
    expect(repo.saved.map((d) => d.date.day), [14, 16, 17]);
  });

  testWidgets('with every date covered it renders nothing', (tester) async {
    await _pump(
      tester,
      trip: _trip(TripType.resort),
      days: [
        for (var d = 14; d <= 17; d++) _row(DateTime(2026, 10, d)),
      ],
    );
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
```

- [ ] **Step 3: Run it to see it fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button_test.dart`
Expected: compile error, `trip_itinerary_generate_button.dart` does not exist.

- [ ] **Step 4: Create the button**

Create `lib/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripItineraryGenerateButton');

/// Fills the itinerary from the trip's dates, typed for the trip
/// (ItineraryDay.generateForTrip). With no rows it reads "Generate
/// itinerary"; with some dates missing, "Fill in missing days"; with every
/// date covered it renders nothing. Only the missing dates are written, so
/// a day the diver already planned keeps its row.
class TripItineraryGenerateButton extends ConsumerStatefulWidget {
  final Trip trip;
  final List<ItineraryDay> days;

  const TripItineraryGenerateButton({
    super.key,
    required this.trip,
    required this.days,
  });

  @override
  ConsumerState<TripItineraryGenerateButton> createState() =>
      _TripItineraryGenerateButtonState();
}

class _TripItineraryGenerateButtonState
    extends ConsumerState<TripItineraryGenerateButton> {
  bool _saving = false;

  Set<DateTime> get _covered => {
    for (final d in widget.days)
      if (widget.trip.containsDate(d.date)) tripDay(d.date),
  };

  List<ItineraryDay> _missing() {
    final covered = _covered;
    return ItineraryDay.generateForTrip(
      tripId: widget.trip.id,
      startDate: widget.trip.startDate,
      endDate: widget.trip.endDate,
      tripType: widget.trip.tripType,
    ).where((d) => !covered.contains(tripDay(d.date))).toList();
  }

  Future<void> _generate() async {
    // A second tap while the first save is in flight would insert the days
    // twice: the table has no (trip, date) uniqueness.
    if (_saving) return;
    setState(() => _saving = true);
    final tripId = widget.trip.id;
    try {
      await ref.read(itineraryDayRepositoryProvider).saveAll(_missing());
      ref.invalidate(itineraryDaysProvider(tripId));
      ref.invalidate(tripStoryProvider(tripId));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to generate trip itinerary',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_story_generateItineraryError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_missing().isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final label = widget.days.isEmpty
        ? l10n.trips_story_generateItinerary
        : l10n.trips_itinerary_fillMissing;
    return OutlinedButton.icon(
      key: const Key('trip-itinerary-generate'),
      icon: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.event_note, size: 18),
      label: Text(label),
      onPressed: _saving ? null : _generate,
    );
  }
}
```

- [ ] **Step 5: Run the button tests**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing tab tests**

Append to `test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart` (inside `main`, after the last test). The `_trip` helper there builds a liveaboard; add a second helper beside it:

```dart
Trip _resortTrip() => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: DateTime(2026, 3, 6),
  endDate: DateTime(2026, 3, 10),
  tripType: TripType.resort,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);
```

and these tests:

```dart
  testWidgets('an empty itinerary explains itself and offers Generate', (
    tester,
  ) async {
    await _pumpTab(tester, trip: _resortTrip(), days: const []);
    expect(
      find.text(
        'No itinerary yet. Generate one from the trip dates, or add days as '
        'you go.',
      ),
      findsOneWidget,
    );
    expect(find.text('Generate itinerary'), findsOneWidget);
    expect(find.text('No dives'), findsNothing);
  });

  testWidgets('a partial itinerary offers Fill in missing days above the '
      'list', (tester) async {
    await _pumpTab(tester, trip: _resortTrip(), days: staleRows);
    expect(find.text('Fill in missing days'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
  });

  testWidgets('a day ahead with a plan says how many dives', (tester) async {
    final planned = _row('p', DateTime(2026, 3, 9), 4).copyWith(
      plannedDives: 3,
    );
    await _pumpTab(tester, trip: _resortTrip(), days: [planned]);
    expect(find.text('3 dives planned'), findsOneWidget);
  });

  testWidgets('off a boat the sheet labels the place Location and offers '
      'land day types', (tester) async {
    await _pumpTab(tester, trip: _resortTrip(), days: staleRows);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Port / Anchorage'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    expect(find.text('Travel').hitTestable(), findsOneWidget);
    expect(find.text('Rest').hitTestable(), findsOneWidget);
    expect(find.text('Embark').hitTestable(), findsNothing);
  });

  testWidgets('on a boat the sheet keeps Port / Anchorage and the maritime '
      'types', (tester) async {
    await _pumpTab(tester, trip: _trip(DateTime(2026, 3, 6)), days: staleRows);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.text('Port / Anchorage'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    expect(find.text('Embark').hitTestable(), findsOneWidget);
    expect(find.text('Travel').hitTestable(), findsOneWidget);
  });

  testWidgets('a sea day on a resort trip keeps its type', (tester) async {
    final sea = ItineraryDay(
      id: 'sea',
      tripId: 'trip-1',
      dayNumber: 2,
      date: DateTime(2026, 3, 7),
      dayType: DayType.seaDay,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final repo = _RecordingItineraryRepo();
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: [sea],
      extra: [itineraryDayRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    // The dropdown shows the stored value even though a resort trip does
    // not offer it.
    expect(find.text('Sea Day'), findsWidgets);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.updated.single.dayType, DayType.seaDay);
  });

  testWidgets('the sheet saves planned dives, and 0 types the day Rest', (
    tester,
  ) async {
    final repo = _RecordingItineraryRepo();
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      extra: [itineraryDayRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('itinerary-planned-dives')), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.updated.single.plannedDives, 0);
    expect(repo.updated.single.dayType, DayType.rest);
  });

  testWidgets('a non-number in planned dives is refused in place', (
    tester,
  ) async {
    final repo = _RecordingItineraryRepo();
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      extra: [itineraryDayRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('itinerary-planned-dives')),
      'two',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a whole number of dives, or leave it blank.'),
      findsOneWidget,
    );
    expect(repo.updated, isEmpty);
  });
```

Add the recording repository next to `_FailingItineraryRepo`:

```dart
class _RecordingItineraryRepo extends ItineraryDayRepository {
  final updated = <ItineraryDay>[];
  @override
  Future<void> updateDay(ItineraryDay day) async => updated.add(day);
}
```

- [ ] **Step 7: Run them to see them fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart`
Expected: the new tests fail ("No dives" found, no Generate button, no `Location` label, no planned-dives field).

- [ ] **Step 8: Rework the tab**

In `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart`:

Add imports:

```dart
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart';
```

Replace `build` so the trip is loaded alongside the days:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(numberedItineraryDaysProvider(tripId));
    final divesAsync = ref.watch(divesForTripProvider(tripId));
    // The trip types the days Generate writes and labels the sheet's place
    // field; a trip that is gone shows the list without the button.
    final trip = ref.watch(tripByIdProvider(tripId)).value;

    return daysAsync.when(
      skipLoadingOnReload: true,
      data: (days) => divesAsync.when(
        data: (dives) => _buildTimeline(context, ref, days, dives, trip),
        loading: () => const Center(child: CircularProgressIndicator()),
        // The repositories log the failure; the diver gets a plain line.
        error: (_, _) =>
            Center(child: Text(context.l10n.trips_itinerary_error_loading)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(context.l10n.trips_itinerary_error_loading)),
    );
  }
```

Replace `_buildTimeline`'s signature and its empty branch, and give the list a header slot:

```dart
  Widget _buildTimeline(
    BuildContext context,
    WidgetRef ref,
    List<ItineraryDay> days,
    List<Dive> dives,
    Trip? trip,
  ) {
    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.trips_itinerary_empty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (trip != null) ...[
                const SizedBox(height: 16),
                TripItineraryGenerateButton(trip: trip, days: days),
              ],
            ],
          ),
        ),
      );
    }

    // Group dives by date (year-month-day key)
    final divesByDate = <String, List<Dive>>{};
    for (final dive in dives) {
      final key = _dateKey(dive.dateTime);
      divesByDate.putIfAbsent(key, () => []).add(dive);
    }

    // Sort each group by time (creating sorted copies to avoid mutation)
    final sortedDivesByDate = divesByDate.map(
      (key, group) => MapEntry(
        key,
        List<Dive>.of(group)..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
      ),
    );

    // The fill-in button renders nothing once every date has a row.
    final header = trip == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TripItineraryGenerateButton(trip: trip, days: days),
            ),
          );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length + (header == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (header != null) {
          if (index == 0) return header;
          index -= 1;
        }
        final day = days[index];
        final dayDives = sortedDivesByDate[_dateKey(day.date)] ?? [];
        return _ItineraryDayCard(
          day: day,
          dives: dayDives,
          tripId: tripId,
          isLiveaboard: trip?.isLiveaboard ?? false,
        );
      },
    );
  }
```

In `_ItineraryDayCard`, add the field and constructor parameter:

```dart
  final bool isLiveaboard;

  const _ItineraryDayCard({
    required this.day,
    required this.dives,
    required this.tripId,
    required this.isLiveaboard,
  });
```

pass it to the sheet:

```dart
          onTap: () => showItineraryDayEditSheet(
            context: context,
            day: day,
            tripId: tripId,
            isLiveaboard: isLiveaboard,
          ),
```

and, directly before the `// Dives for this day` block, add the planned line:

```dart
                // A day ahead with a plan: the count the forecast uses.
                if (dives.isEmpty && (day.plannedDives ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Text(
                      context.l10n.trips_itinerary_plannedDives(
                        day.plannedDives!,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
```

- [ ] **Step 9: Rework the sheet**

In `lib/features/trips/presentation/widgets/itinerary_day_edit_sheet.dart`:

Add `import 'package:submersion/shared/widgets/forms/number_input_validation.dart';`.

Change the entry point:

```dart
Future<void> showItineraryDayEditSheet({
  required BuildContext context,
  required ItineraryDay day,
  required String tripId,
  required bool isLiveaboard,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ItineraryDayEditSheet(
      day: day,
      tripId: tripId,
      isLiveaboard: isLiveaboard,
    ),
  );
}
```

Add `final bool isLiveaboard;` to `_ItineraryDayEditSheet` and `required this.isLiveaboard` to its constructor.

In the state, add a controller and an error:

```dart
  late TextEditingController _plannedDivesController;
  String? _plannedDivesError;
```

initialise it in `initState` after `_notesController`:

```dart
    _plannedDivesController = TextEditingController(
      text: widget.day.plannedDives?.toString() ?? '',
    );
```

dispose it, and replace the body of `_save` up to the repository call:

```dart
  Future<void> _save() async {
    // Blank derives the count; 0 is a rest day; a word is refused in place.
    final int? plannedDives;
    switch (readNumber(
      _plannedDivesController.text,
      integer: true,
      allowNegative: false,
    )) {
      case NumberValue(:final value):
        plannedDives = value.toInt();
      case NumberBlank():
        plannedDives = null;
      case NumberInvalid():
        setState(
          () => _plannedDivesError =
              context.l10n.trips_itinerary_plannedDives_invalid,
        );
        return;
    }
    setState(() {
      _isSaving = true;
      _plannedDivesError = null;
    });

    try {
      final portName = _portNameController.text.trim();
      final notes = _notesController.text.trim();
      // Saving a day as Rest plans it at none (#2658).
      final dayType = _selectedDayType;
      final updatedDay = widget.day.copyWith(
        dayType: dayType,
        portName: portName.isEmpty ? null : portName,
        notes: notes,
        plannedDives: dayType == DayType.rest ? 0 : plannedDives,
      );
```

The rest of `_save` (repository call, invalidate, pop, error snackbar) is unchanged.

In `build`, the dropdown's items become the types the trip offers plus the stored value:

```dart
            // Land types for every trip, the maritime ones on a boat; a row
            // carrying a type the trip no longer offers keeps it listed so
            // Save does not retype it.
            DropdownButtonFormField<DayType>(
              initialValue: _selectedDayType,
              decoration: InputDecoration(
                labelText: l10n.trips_itinerary_dayType_label,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final type in _offeredTypes())
                  DropdownMenuItem<DayType>(
                    value: type,
                    child: Text(type.localizedName(context)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDayType = value);
                }
              },
            ),
```

with this method on the state:

```dart
  List<DayType> _offeredTypes() {
    const land = [DayType.travel, DayType.diveDay, DayType.rest];
    const sea = [
      DayType.embark,
      DayType.disembark,
      DayType.seaDay,
      DayType.portDay,
    ];
    final offered = [...land, if (widget.isLiveaboard) ...sea];
    if (!offered.contains(_selectedDayType)) offered.add(_selectedDayType);
    return offered;
  }
```

The port field's label becomes:

```dart
                labelText: widget.isLiveaboard
                    ? l10n.trips_itinerary_portName_label
                    : l10n.trips_itinerary_location_label,
```

and directly after the notes field (before the Save button's `SizedBox(height: 24)`), add:

```dart
            const SizedBox(height: 16),

            // Planned dives: the per-day override the fill forecast reads.
            TextFormField(
              key: const Key('itinerary-planned-dives'),
              controller: _plannedDivesController,
              decoration: InputDecoration(
                labelText: l10n.trips_itinerary_plannedDives_label,
                border: const OutlineInputBorder(),
                errorText: _plannedDivesError,
              ),
              keyboardType: TextInputType.number,
            ),
```

- [ ] **Step 10: Run the tab tests, format, analyze, guards**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart test/features/trips/presentation/widgets/itinerary/ test/features/trips/presentation/pages/trip_detail_page_test.dart test/l10n/arb_parity_test.dart`
Expected: PASS. Then `dart format .`, `flutter analyze`, `TMPDIR=$SCR/tmp flutter test test/architecture/`.

- [ ] **Step 11: Commit**

```bash
git add lib/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart lib/features/trips/presentation/widgets/trip_itinerary_tab.dart lib/features/trips/presentation/widgets/itinerary_day_edit_sheet.dart lib/l10n/arb test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart test/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button_test.dart
git commit -m "feat(trips): itinerary generation, planned dives and land day types for every trip type"
```

---
### Task 3: One map point per dive, the day map, pin-to-row highlight

**Files:**
- Modify: `lib/features/trips/domain/entities/trip_story_day.dart:167-186` (`TripStoryMapPoint`)
- Modify: `lib/features/trips/domain/services/trip_story_builder.dart:172-187` (dive points)
- Create: `lib/features/trips/presentation/widgets/story/trip_day_map.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`
- Modify: all 11 ARB files (three keys beside `trips_story_map_semantics`)
- Test: `test/features/trips/domain/services/trip_story_builder_test.dart:289-325`
- Test: `test/features/trips/presentation/widgets/story/trip_day_map_test.dart` (create)
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`

**Interfaces:**
- Produces: `TripStoryMapPoint({latitude, longitude, dayIndex, label, siteId, diveId, diveNumber})` with `bool get isDive => diveId != null`; `TripDayMap({required TripStoryDay day, required List<TripStoryMapPoint> points, String? highlightedDiveId, ValueChanged<String?>? onDiveTap, VoidCallback? onExpand})`; `TripStoryDayCard({required TripStoryDay day, required String tripId, List<TripStoryMapPoint> mapPoints = const [], void Function(TripStoryDay day, List<TripStoryMapPoint> points)? onExpandMap})`.
- l10n: `trips_story_dayMap_semantics` ("Map of day {number}"), `trips_story_dayMap_expand` ("View fullscreen map"), `trips_story_dayMap_divePin` ("Dive {number}").
- Ruling R6: `TripStoryMapGeometry.nearestPointForDay` stays (the weather backfill reads it); the spec's deletion is withdrawn. With per-dive points it still returns the day's first point.

- [ ] **Step 1: Write the failing builder test**

In `test/features/trips/domain/services/trip_story_builder_test.dart`, replace the test `'collects unique day site points and itinerary ports in order'` with:

```dart
    test('collects one point per dive and the itinerary port, in order', () {
      const site = DiveSite(
        id: 'site-a',
        name: 'Blue Corner',
        location: GeoPoint(12.1, -68.2),
      );
      final story = buildTripStory(
        trip: _trip(),
        dives: [
          _dive('d1', DateTime(2026, 3, 8, 9), site: site),
          _dive('d2', DateTime(2026, 3, 8, 11), site: site), // same site
        ],
        itineraryDays: [
          ItineraryDay(
            id: 'itin-1',
            tripId: 'trip-1',
            dayNumber: 1,
            date: DateTime(2026, 3, 7),
            dayType: DayType.embark,
            portName: 'Kralendijk',
            latitude: 12.15,
            longitude: -68.27,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      final points = story.mapGeometry.points;
      expect(points, hasLength(3));
      expect(points[0].label, 'Kralendijk');
      expect(points[0].dayIndex, 0);
      expect(points[0].isDive, isFalse);
      // One pin per dive, numbered like the day card's rows.
      expect(points[1].diveId, 'd1');
      expect(points[1].diveNumber, 1);
      expect(points[1].siteId, 'site-a');
      expect(points[2].diveId, 'd2');
      expect(points[2].diveNumber, 2);
      expect(points[2].dayIndex, 1);
    });
```

- [ ] **Step 2: Run it to see it fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/domain/services/trip_story_builder_test.dart`
Expected: compile error, `isDive`, `diveId` undefined.

- [ ] **Step 3: Extend the point and the builder**

In `lib/features/trips/domain/entities/trip_story_day.dart`, replace `TripStoryMapPoint`:

```dart
/// A mappable point contributed by a story day: an itinerary location, or
/// one dive at a site (one point per dive, so a pin can name a dive).
class TripStoryMapPoint extends Equatable {
  final double latitude;
  final double longitude;
  final int dayIndex;
  final String? siteId;
  final String label;

  /// The dive this point stands for; null for an itinerary location.
  final String? diveId;

  /// The number the day card shows for that dive (its logged number, else
  /// its position in the day), so the pin and the row read the same.
  final int? diveNumber;

  const TripStoryMapPoint({
    required this.latitude,
    required this.longitude,
    required this.dayIndex,
    required this.label,
    this.siteId,
    this.diveId,
    this.diveNumber,
  });

  bool get isDive => diveId != null;

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    dayIndex,
    siteId,
    label,
    diveId,
    diveNumber,
  ];
}
```

In `lib/features/trips/domain/services/trip_story_builder.dart`, replace the dive-site loop (from `final seenSiteIds = <String>{};` to the end of that `for`) with:

```dart
    // One point per dive with a located site, numbered as the day card
    // numbers its rows, so a pin on the day map names one dive.
    for (final (index, dive) in dayDives.indexed) {
      final site = dive.site;
      final location = site?.location;
      if (site == null || location == null) continue;
      mapPoints.add(
        TripStoryMapPoint(
          latitude: location.latitude,
          longitude: location.longitude,
          dayIndex: i,
          siteId: site.id,
          label: site.name,
          diveId: dive.id,
          diveNumber: dive.diveNumber ?? index + 1,
        ),
      );
    }
```

Update the comment above the itinerary point from `// Map geometry: itinerary port first, then unique dive sites in order.` to `// Map geometry: itinerary location first, then one point per dive.`

- [ ] **Step 4: Run the builder tests and the weather backfill tests**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/domain/services/trip_story_builder_test.dart test/features/trips/domain/services/trip_day_weather_backfill_test.dart test/features/trips/domain/entities/trip_story_day_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the ARB keys**

`app_en.arb`, after `"trips_story_map_semantics": ...`:

```json
  "trips_story_dayMap_semantics": "Map of day {number}",
  "@trips_story_dayMap_semantics": {"placeholders": {"number": {"type": "int"}}},
  "trips_story_dayMap_expand": "View fullscreen map",
  "trips_story_dayMap_divePin": "Dive {number}",
  "@trips_story_dayMap_divePin": {"placeholders": {"number": {"type": "int"}}},
```

Other locales, after each file's `trips_story_map_semantics`:

| locale | dayMap_semantics | dayMap_expand | dayMap_divePin |
| --- | --- | --- | --- |
| ar | "خريطة اليوم {number}" | "عرض الخريطة بملء الشاشة" | "غوصة {number}" |
| de | "Karte von Tag {number}" | "Karte im Vollbild anzeigen" | "Tauchgang {number}" |
| es | "Mapa del día {number}" | "Ver mapa a pantalla completa" | "Inmersión {number}" |
| fr | "Carte du jour {number}" | "Afficher la carte en plein écran" | "Plongée {number}" |
| he | "מפת יום {number}" | "הצגת מפה במסך מלא" | "צלילה {number}" |
| hu | "{number}. nap térképe" | "Térkép teljes képernyőn" | "{number}. merülés" |
| it | "Mappa del giorno {number}" | "Mostra la mappa a schermo intero" | "Immersione {number}" |
| nl | "Kaart van dag {number}" | "Kaart op volledig scherm" | "Duik {number}" |
| pt | "Mapa do dia {number}" | "Ver mapa em ecrã inteiro" | "Mergulho {number}" |
| zh | "第 {number} 天地图" | "全屏查看地图" | "第 {number} 次潜水" |

Run `flutter gen-l10n`.

- [ ] **Step 6: Write the failing day map tests**

Create `test/features/trips/presentation/widgets/story/trip_day_map_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_map.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

TripStoryDay _day() => TripStoryDay(
  date: DateTime(2026, 3, 8),
  dayNumber: 2,
  dives: const [],
  media: const [],
  sightings: const [],
  kind: TripStoryDayKind.past,
);

const _port = TripStoryMapPoint(
  latitude: 12.15,
  longitude: -68.27,
  dayIndex: 1,
  label: 'Kralendijk',
);
const _dive1 = TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.2,
  dayIndex: 1,
  label: 'Blue Corner',
  siteId: 'site-a',
  diveId: 'd1',
  diveNumber: 1,
);
const _dive2 = TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.2,
  dayIndex: 1,
  label: 'Blue Corner',
  siteId: 'site-a',
  diveId: 'd2',
  diveNumber: 2,
);

Future<List<String?>> _pump(
  WidgetTester tester, {
  required List<TripStoryMapPoint> points,
  String? highlighted,
  VoidCallback? onExpand,
}) async {
  final taps = <String?>[];
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 180,
            child: TripDayMap(
              day: _day(),
              points: points,
              highlightedDiveId: highlighted,
              onDiveTap: taps.add,
              onExpand: onExpand,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return taps;
}

void main() {
  testWidgets('draws a pin per dive numbered like the rows, and the port', (
    tester,
  ) async {
    await _pump(tester, points: [_port, _dive1, _dive2]);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.bySemanticsLabel('Dive 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Dive 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Kralendijk'), findsOneWidget);
    expect(find.bySemanticsLabel('Map of day 2'), findsOneWidget);
  });

  testWidgets('tapping a dive pin reports its dive', (tester) async {
    final taps = await _pump(tester, points: [_dive1]);
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pump();
    expect(taps, ['d1']);
  });

  testWidgets('tapping the highlighted pin clears the highlight', (
    tester,
  ) async {
    final taps = await _pump(tester, points: [_dive1], highlighted: 'd1');
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pump();
    expect(taps, [null]);
  });

  testWidgets('same-site dives get distinct pins', (tester) async {
    await _pump(tester, points: [_dive1, _dive2]);
    final a = tester.getCenter(find.byKey(const Key('day-map-pin-d1')));
    final b = tester.getCenter(find.byKey(const Key('day-map-pin-d2')));
    expect((a.dx - b.dx).abs(), greaterThanOrEqualTo(14));
    expect(a.dy, b.dy);
  });

  testWidgets('the port pin is not a button', (tester) async {
    final taps = await _pump(tester, points: [_port]);
    expect(find.byKey(const Key('day-map-pin-port-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('day-map-pin-port-0')));
    await tester.pump();
    expect(taps, isEmpty);
  });

  testWidgets('the expand button shows only with a handler', (tester) async {
    await _pump(tester, points: [_dive1]);
    expect(find.byTooltip('View fullscreen map'), findsNothing);
    var expanded = 0;
    await _pump(tester, points: [_dive1], onExpand: () => expanded++);
    await tester.tap(find.byTooltip('View fullscreen map'));
    expect(expanded, 1);
  });
}
```

- [ ] **Step 7: Run them to see them fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/story/trip_day_map_test.dart`
Expected: compile error, `trip_day_map.dart` does not exist.

- [ ] **Step 8: Create the day map**

Create `lib/features/trips/presentation/widgets/story/trip_day_map.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_camera_fit.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One story day's map: its itinerary location and one pin per dive, fitted
/// to the day's points (issue #2845). Tapping a dive pin reports the dive
/// through [onDiveTap] (null when the highlighted pin is tapped again); an
/// [onExpand] handler adds the fullscreen button.
class TripDayMap extends ConsumerStatefulWidget {
  final TripStoryDay day;
  final List<TripStoryMapPoint> points;
  final String? highlightedDiveId;
  final ValueChanged<String?>? onDiveTap;
  final VoidCallback? onExpand;

  const TripDayMap({
    super.key,
    required this.day,
    required this.points,
    this.highlightedDiveId,
    this.onDiveTap,
    this.onExpand,
  });

  /// Zoomed out further the world shrinks to a strip; matches the other
  /// embedded detail maps.
  static const double minZoom = 2.0;

  /// A lone site gets a close view rather than a dot in an ocean.
  static const double singlePointZoom = 13.0;

  /// Pixels between pins that share a spot, so each can be hit.
  static const double stackOffset = 14.0;

  @override
  ConsumerState<TripDayMap> createState() => _TripDayMapState();
}

class _TripDayMapState extends ConsumerState<TripDayMap> {
  final MapController _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Horizontal offsets for pins on the same spot: 0, +14, -14, +28, ...
  Map<int, double> _stackOffsets() {
    final seen = <String, int>{};
    final offsets = <int, double>{};
    for (final (i, p) in widget.points.indexed) {
      final key = '${p.latitude},${p.longitude}';
      final n = seen.update(key, (v) => v + 1, ifAbsent: () => 0);
      final step = (n + 1) ~/ 2 * TripDayMap.stackOffset;
      offsets[i] = n == 0 ? 0 : (n.isOdd ? step : -step);
    }
    return offsets;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final maxZoom = ref.watch(mapTileMaxZoomProvider);
    final urlTemplate = ref.watch(mapTileUrlProvider);
    final latLngs = [
      for (final p in widget.points) LatLng(p.latitude, p.longitude),
    ];
    final offsets = _stackOffsets();

    return Semantics(
      label: l10n.trips_story_dayMap_semantics(widget.day.dayNumber),
      child: Stack(
        children: [
          TrackpadZoomMap(
            controller: _controller,
            minZoom: TripDayMap.minZoom,
            maxZoom: maxZoom,
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCameraFit: WorldCameraFit(
                  points: latLngs,
                  padding: const EdgeInsets.all(32),
                  maxZoom: maxZoom,
                  singlePointZoom: TripDayMap.singlePointZoom,
                ),
                minZoom: TripDayMap.minZoom,
                maxZoom: maxZoom,
                cameraConstraint: worldMapCameraConstraint,
                // Pans and zooms like the other embedded maps; north stays
                // up.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: urlTemplate,
                  userAgentPackageName: 'app.submersion',
                  maxZoom: maxZoom,
                  tileProvider: TileCacheService.instance.tileProviderFor(
                    urlTemplate: urlTemplate,
                  ),
                ),
                MarkerLayer(
                  markers: [
                    for (final (i, point) in widget.points.indexed)
                      Marker(
                        point: LatLng(point.latitude, point.longitude),
                        // 48x48 meets the touch-target guideline; the dot
                        // stays 28x28 inside it.
                        width: 48,
                        height: 48,
                        child: Transform.translate(
                          offset: Offset(offsets[i]!, 0),
                          child: point.isDive
                              ? _DivePin(
                                  point: point,
                                  highlighted:
                                      point.diveId == widget.highlightedDiveId,
                                  onTap: widget.onDiveTap == null
                                      ? null
                                      : () => widget.onDiveTap!(
                                          point.diveId ==
                                                  widget.highlightedDiveId
                                              ? null
                                              : point.diveId,
                                        ),
                                )
                              : _PlacePin(point: point, index: i),
                        ),
                      ),
                  ],
                ),
                const MapAttribution(),
              ],
            ),
          ),
          if (widget.onExpand != null)
            PositionedDirectional(
              top: 4,
              end: 4,
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                child: IconButton(
                  key: const Key('day-map-expand'),
                  tooltip: l10n.trips_story_dayMap_expand,
                  icon: const Icon(Icons.fullscreen),
                  onPressed: widget.onExpand,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A dive's pin: the day card's number in a circle. Dimmed when another
/// dive on the day is highlighted.
class _DivePin extends StatelessWidget {
  final TripStoryMapPoint point;
  final bool highlighted;
  final VoidCallback? onTap;

  const _DivePin({
    required this.point,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: highlighted,
      label: context.l10n.trips_story_dayMap_divePin(point.diveNumber ?? 0),
      child: GestureDetector(
        key: Key('day-map-pin-${point.diveId}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlighted ? colorScheme.tertiary : colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.onPrimary, width: 2),
            ),
            child: Text(
              '${point.diveNumber ?? ''}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The itinerary location's flag; informative, not a button.
class _PlacePin extends StatelessWidget {
  final TripStoryMapPoint point;
  final int index;

  const _PlacePin({required this.point, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: point.label,
      child: Center(
        key: Key('day-map-pin-port-$index'),
        child: Icon(
          Icons.flag,
          size: 24,
          color: colorScheme.secondary,
          shadows: const [Shadow(blurRadius: 4)],
        ),
      ),
    );
  }
}
```

Check `worldMapCameraConstraint` is exported by `world_copies.dart` (the old `TripStoryMap` imported it from there). If `TrackpadZoomMap`'s constructor differs from `(controller, minZoom, maxZoom, child)`, match the old `TripStoryMap` usage exactly.

- [ ] **Step 9: Run the day map tests**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/story/trip_day_map_test.dart`
Expected: PASS. If `find.bySemanticsLabel` fails for the pins, enable semantics in the test with `final handle = tester.ensureSemantics(); addTearDown(handle.dispose);` at the top of `_pump`.

- [ ] **Step 10: Write the failing day card tests**

In `test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`, extend `pumpCard` with map points and an expand recorder:

```dart
Future<void> pumpCard(
  WidgetTester tester,
  TripStoryDay day, {
  List<Override> extra = const [],
  List<TripStoryMapPoint> mapPoints = const [],
  void Function(TripStoryDay, List<TripStoryMapPoint>)? onExpandMap,
}) async {
```

and pass `mapPoints: mapPoints, onExpandMap: onExpandMap` to `TripStoryDayCard`. Add `import 'package:flutter_map/flutter_map.dart';` and `import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';`. Then add tests:

```dart
  TripStoryMapPoint _pin(String diveId, int number) => TripStoryMapPoint(
    latitude: 12.1,
    longitude: -68.2,
    dayIndex: 1,
    label: 'Blue Corner',
    siteId: 'site-a',
    diveId: diveId,
    diveNumber: number,
  );

  testWidgets('a day with map points opens with its map', (tester) async {
    await pumpCard(
      tester,
      _pastDay(dives: [_dive('d1'), _dive('d2')]),
      mapPoints: [_pin('d1', 1), _pin('d2', 2)],
    );
    expect(find.byType(FlutterMap), findsOneWidget);
    final map = tester.getRect(find.byType(FlutterMap));
    final band = tester.getRect(find.byKey(const Key('day-summary-band')));
    expect(map.height, 180);
    expect(map.bottom, lessThanOrEqualTo(band.top));
  });

  testWidgets('a day with no map points shows no map', (tester) async {
    await pumpCard(tester, _pastDay(dives: [_dive('d1')]));
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('tapping a pin highlights its row, tapping again clears it', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _pastDay(dives: [_dive('d1'), _dive('d2')]),
      mapPoints: [_pin('d1', 1), _pin('d2', 2)],
    );
    bool highlighted(String id) => tester
        .widgetList<DiveListItem>(find.byType(DiveListItem))
        .firstWhere((w) => w.summary.id == id)
        .isHighlighted;
    expect(highlighted('d1'), isFalse);
    await tester.tap(find.byKey(const Key('day-map-pin-d2')));
    await tester.pumpAndSettle();
    expect(highlighted('d2'), isTrue);
    expect(highlighted('d1'), isFalse);
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pumpAndSettle();
    expect(highlighted('d1'), isTrue);
    expect(highlighted('d2'), isFalse);
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pumpAndSettle();
    expect(highlighted('d1'), isFalse);
  });

  testWidgets('the expand button hands the day and its points up', (
    tester,
  ) async {
    TripStoryDay? expandedDay;
    await pumpCard(
      tester,
      _pastDay(dives: [_dive('d1')]),
      mapPoints: [_pin('d1', 1)],
      onExpandMap: (day, points) => expandedDay = day,
    );
    await tester.tap(find.byKey(const Key('day-map-expand')));
    expect(expandedDay?.dayNumber, 2);
  });
```

Use the file's existing day and dive helpers (`_pastDay`, `_dive` or whatever the file names them; read the top of the file and match). `DiveSummary` exposes `id`; if the field is named differently, assert on `w.fullDive?.id`.

- [ ] **Step 11: Run them to see them fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`
Expected: compile error, `mapPoints` is not a parameter.

- [ ] **Step 12: Put the map in the day card**

In `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`:

Add the import `import 'package:submersion/features/trips/presentation/widgets/story/trip_day_map.dart';`.

Turn the widget into a `ConsumerStatefulWidget`:

```dart
/// One day chapter of the trip story: the day's own map when it has points
/// (#2845), the summary band, the dive rows, photos and sightings.
class TripStoryDayCard extends ConsumerStatefulWidget {
  final TripStoryDay day;
  final String tripId;

  /// The day's map points (`TripStoryMapGeometry.pointsForDay`); none hides
  /// the map.
  final List<TripStoryMapPoint> mapPoints;

  /// Opens the day's map fullscreen; null hides the expand button.
  final void Function(TripStoryDay day, List<TripStoryMapPoint> points)?
  onExpandMap;

  const TripStoryDayCard({
    super.key,
    required this.day,
    required this.tripId,
    this.mapPoints = const [],
    this.onExpandMap,
  });

  @override
  ConsumerState<TripStoryDayCard> createState() => _TripStoryDayCardState();
}

class _TripStoryDayCardState extends ConsumerState<TripStoryDayCard> {
  /// The dive whose row a pin tap lit up; cleared by the same pin, another
  /// pin, or opening the row.
  String? _highlightedDiveId;
  final Map<String, GlobalKey> _rowKeys = {};

  TripStoryDay get day => widget.day;
  String get tripId => widget.tripId;
  bool get _isPlanned => day.kind == TripStoryDayKind.future;

  void _onPinTap(String? diveId) {
    setState(() => _highlightedDiveId = diveId);
    final keyContext = diveId == null ? null : _rowKeys[diveId]?.currentContext;
    if (keyContext == null) return;
    Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );
  }

  @override
  Widget build(BuildContext context) {
```

(the former `build(BuildContext context, WidgetRef ref)` body follows, with `ref` now the state's field). Inside it:

- Change `hasBody` to also count the map: `widget.mapPoints.isNotEmpty ||` as its first operand.
- As the first child of the card's `Column` (before `if (day.dives.isNotEmpty) ...[`), add:

```dart
              if (widget.mapPoints.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 180,
                    child: TripDayMap(
                      day: day,
                      points: widget.mapPoints,
                      highlightedDiveId: _highlightedDiveId,
                      onDiveTap: _onPinTap,
                      onExpand: widget.onExpandMap == null
                          ? null
                          : () => widget.onExpandMap!(day, widget.mapPoints),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
```

- In the `day.dives.mapIndexed(...)` row builder, wrap each `DiveListItem` so it carries a key and the highlight:

```dart
                ...day.dives.mapIndexed(
                  (index, dive) => KeyedSubtree(
                    key: _rowKeys.putIfAbsent(dive.id, GlobalKey.new),
                    child: DiveListItem(
                      summary: DiveSummary.fromDive(dive),
                      diveTypeLabelResolver: diveTypeLabelResolver,
                      diveTypeShortLabelResolver: diveTypeShortLabelResolver,
                      diveTypeListVisibilityPredicate:
                          diveTypeListVisibilityPredicate,
                      // The story already holds the full Dive; pass it so the
                      // configurable card can resolve fields absent from the
                      // summary (tanks, SAC, buddies, weights).
                      fullDive: dive,
                      diveNumber: dive.diveNumber ?? index + 1,
                      isHighlighted: dive.id == _highlightedDiveId,
                      onTap: () {
                        if (_highlightedDiveId == dive.id) {
                          setState(() => _highlightedDiveId = null);
                        }
                        context.push('/dives/${dive.id}');
                      },
                    ),
                  ),
                ),
```

- The rest of the body (summary band, photos, sightings, planned extras) is unchanged except that every `day.` and `tripId` reference now resolves through the getters above.

- [ ] **Step 13: Run the card tests, the story view tests, format, analyze, guards**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/story/ test/features/trips/presentation/widgets/trip_overview_tab_test.dart test/features/trips/domain/ test/l10n/arb_parity_test.dart`
Expected: PASS (the story view still passes `TripStoryDayCard(day:, tripId:)` with no points, so nothing else changes yet). Then `dart format .`, `flutter analyze`, `TMPDIR=$SCR/tmp flutter test test/architecture/`.

- [ ] **Step 14: Commit**

```bash
git add lib/features/trips/domain/entities/trip_story_day.dart lib/features/trips/domain/services/trip_story_builder.dart lib/features/trips/presentation/widgets/story/trip_day_map.dart lib/features/trips/presentation/widgets/story/trip_story_day_card.dart lib/l10n/arb test/features/trips/domain/services/trip_story_builder_test.dart test/features/trips/presentation/widgets/story/trip_day_map_test.dart test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart
git commit -m "feat(trips): a map per story day with one pin per dive"
```

---
### Task 4: The fullscreen day map page

**Files:**
- Create: `lib/features/trips/presentation/pages/trip_day_map_page.dart`
- Test: `test/features/trips/presentation/pages/trip_day_map_page_test.dart` (create)

**Interfaces:**
- Consumes: `TripDayMap` from Task 3; `DiveListItem`, `DiveSummary.fromDive`, `watchDiveTypeLabelResolver(ref, l10n)`, `watchDiveTypeShortLabelResolver(ref, l10n)`, `watchDiveTypeListVisibilityPredicate(ref)`; `UnitFormatter.formatMonthDay`; l10n `trips_story_dayLabel(number)`.
- Produces: `TripDayMapPage({required TripStoryDay day, required List<TripStoryMapPoint> points})` and `void showTripDayMapPage(BuildContext context, {required TripStoryDay day, required List<TripStoryMapPoint> points})` which pushes it with a `MaterialPageRoute`. Task 7 wires `TripStoryView` to it.

- [ ] **Step 1: Write the failing page tests**

Create `test/features/trips/presentation/pages/trip_day_map_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/pages/trip_day_map_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _site = DiveSite(
  id: 'site-a',
  name: 'Blue Corner',
  location: GeoPoint(12.1, -68.2),
);

Dive _dive(String id, int hour) => Dive(
  id: id,
  dateTime: DateTime(2026, 3, 8, hour),
  maxDepth: 20,
  site: _site,
);

TripStoryDay _day() => TripStoryDay(
  date: DateTime(2026, 3, 8),
  dayNumber: 2,
  dives: [_dive('d1', 9), _dive('d2', 14)],
  media: const [],
  sightings: const [],
  kind: TripStoryDayKind.past,
);

TripStoryMapPoint _pin(String id, int number) => TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.2,
  dayIndex: 1,
  label: 'Blue Corner',
  siteId: 'site-a',
  diveId: id,
  diveNumber: number,
);

Future<void> _pump(WidgetTester tester) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TripDayMapPage(
          day: _day(),
          points: [_pin('d1', 1), _pin('d2', 2)],
        ),
      ),
      GoRoute(
        path: '/dives/:id',
        builder: (_, state) =>
            Scaffold(body: Text('DIVE ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('titles the page with the day and fills it with the map', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Day 2 · Mar 8'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('day-map-expand')), findsNothing);
    expect(find.byType(DiveListItem), findsNothing);
  });

  testWidgets('tapping a pin docks that dive, tapping it again undocks', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('day-map-pin-d2')));
    await tester.pumpAndSettle();
    final docked = tester.widget<DiveListItem>(find.byType(DiveListItem));
    expect(docked.summary.id, 'd2');
    expect(docked.isHighlighted, isTrue);
    await tester.tap(find.byKey(const Key('day-map-pin-d2')));
    await tester.pumpAndSettle();
    expect(find.byType(DiveListItem), findsNothing);
  });

  testWidgets('tapping the docked row opens the dive', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DiveListItem));
    await tester.pumpAndSettle();
    expect(find.text('DIVE d1'), findsOneWidget);
  });
}
```

If the month-day format under `MockSettingsNotifier` differs from `Mar 8`, read the expected string with `UnitFormatter(const AppSettings()).formatMonthDay(DateTime(2026, 3, 8))` in the test rather than guessing.

- [ ] **Step 2: Run it to see it fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/pages/trip_day_map_page_test.dart`
Expected: compile error, the page file does not exist.

- [ ] **Step 3: Create the page**

Create `lib/features/trips/presentation/pages/trip_day_map_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Pushes the day's map fullscreen, the way the dive site page does.
void showTripDayMapPage(
  BuildContext context, {
  required TripStoryDay day,
  required List<TripStoryMapPoint> points,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TripDayMapPage(day: day, points: points),
    ),
  );
}

/// One story day's map on its own page (#2845). Tapping a dive pin docks
/// that dive's row at the bottom; tapping the row opens the dive.
class TripDayMapPage extends ConsumerStatefulWidget {
  final TripStoryDay day;
  final List<TripStoryMapPoint> points;

  const TripDayMapPage({super.key, required this.day, required this.points});

  @override
  ConsumerState<TripDayMapPage> createState() => _TripDayMapPageState();
}

class _TripDayMapPageState extends ConsumerState<TripDayMapPage> {
  String? _dockedDiveId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final day = widget.day;
    final docked = _dockedDiveId == null
        ? null
        : day.dives.where((d) => d.id == _dockedDiveId).firstOrNull;
    final dockedIndex = docked == null ? -1 : day.dives.indexOf(docked);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l10n.trips_story_dayLabel(day.dayNumber)} · '
          '${units.formatMonthDay(day.date)}',
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: TripDayMap(
              day: day,
              points: widget.points,
              highlightedDiveId: _dockedDiveId,
              onDiveTap: (id) => setState(() => _dockedDiveId = id),
            ),
          ),
          if (docked != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: DiveListItem(
                      summary: DiveSummary.fromDive(docked),
                      diveTypeLabelResolver: watchDiveTypeLabelResolver(
                        ref,
                        l10n,
                      ),
                      diveTypeShortLabelResolver:
                          watchDiveTypeShortLabelResolver(ref, l10n),
                      diveTypeListVisibilityPredicate:
                          watchDiveTypeListVisibilityPredicate(ref),
                      fullDive: docked,
                      diveNumber: docked.diveNumber ?? dockedIndex + 1,
                      isHighlighted: true,
                      onTap: () => context.push('/dives/${docked.id}'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

`firstOrNull` needs `package:collection/collection.dart`; add the import.

- [ ] **Step 4: Run the page tests, format, analyze, guards**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/pages/trip_day_map_page_test.dart`
Expected: PASS. Then `dart format .`, `flutter analyze`, `TMPDIR=$SCR/tmp flutter test test/architecture/`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/pages/trip_day_map_page.dart test/features/trips/presentation/pages/trip_day_map_page_test.dart
git commit -m "feat(trips): fullscreen page for a story day's map"
```

---

### Task 5: The Prepare overview

**Files:**
- Create: `lib/features/trips/presentation/widgets/trip_detail_tabs.dart` (the `TripDetailTab` enum only; Task 7 adds the widget)
- Create: `lib/features/trips/presentation/widgets/overview/trip_overview_summary_card.dart`
- Create: `lib/features/trips/presentation/widgets/overview/trip_prepare_overview.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_hero.dart` (`showEmptyState`)
- Modify: `lib/features/trips/presentation/widgets/trip_overview_tab.dart` (mode switch)
- Modify: all 11 ARB files (keys beside `trips_detail_tab_dives`)
- Test: `test/features/trips/presentation/widgets/overview/trip_overview_summary_card_test.dart` (create)
- Test: `test/features/trips/presentation/widgets/trip_overview_tab_test.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`

**Interfaces:**
- Consumes: `tripChecklistProvider`, `tripGearProvider`, `tripCylinderStatesProvider`, `tripServiceAlertsProvider`, `tripServiceAlertItemCount`, `tripServiceAlertsAnyOverdue`, `itineraryDaysProvider`, `TripStoryHero`.
- Produces: `enum TripDetailTab { overview, itinerary, gear, checklist, dives, photos }`; `TripOverviewSummaryCard({required Trip trip, ValueChanged<TripDetailTab>? onOpenTab})` (with no handler it calls `DefaultTabController.of(context).animateTo(tab.index)`); `TripPrepareOverview({required TripStory story, ValueChanged<TripDetailTab>? onOpenTab})`; `TripStoryHero(..., bool showEmptyState = true)`; `TripOverviewTab({required TripWithStats tripWithStats, ValueChanged<TripDetailTab>? onOpenTab})`.
- l10n keys: `trips_overview_checklist_progress` ("{done} of {total} done"), `trips_overview_checklist_dueSoon` (plural), `trips_overview_checklist_overdue` (plural), `trips_overview_gear_packed` (plural), `trips_overview_gear_cylinders` (plural), `trips_overview_gear_serviceAlerts` (plural), `trips_overview_itinerary_days` (plural), `trips_overview_itinerary_divesPlanned` (plural), `trips_overview_itinerary_none` ("Not planned yet"), `trips_overview_plan` ("Plan"), `trips_overview_plan_divesPerDay` ("{count} dives/day"), `trips_overview_plan_sharing` (plural "{count} share cylinders"), `trips_overview_plan_notSet` ("Not set").

- [ ] **Step 1: Add the ARB keys**

`app_en.arb`, after `"trips_detail_tab_dives": "Dives",`:

```json
  "trips_overview_checklist_progress": "{done} of {total} done",
  "@trips_overview_checklist_progress": {"placeholders": {"done": {"type": "int"}, "total": {"type": "int"}}},
  "trips_overview_checklist_dueSoon": "{count, plural, =1{1 due this week} other{{count} due this week}}",
  "@trips_overview_checklist_dueSoon": {"placeholders": {"count": {"type": "int"}}},
  "trips_overview_checklist_overdue": "{count, plural, =1{1 overdue} other{{count} overdue}}",
  "@trips_overview_checklist_overdue": {"placeholders": {"count": {"type": "int"}}},
  "trips_overview_gear_packed": "{count, plural, =0{Nothing packed} =1{1 item packed} other{{count} items packed}}",
  "@trips_overview_gear_packed": {"placeholders": {"count": {"type": "int"}}},
  "trips_overview_gear_cylinders": "{count, plural, =1{1 cylinder} other{{count} cylinders}}",
  "@trips_overview_gear_cylinders": {"placeholders": {"count": {"type": "int"}}},
  "trips_overview_gear_serviceAlerts": "{count, plural, =1{1 service alert} other{{count} service alerts}}",
  "@trips_overview_gear_serviceAlerts": {"placeholders": {"count": {"type": "int"}}},
  "trips_overview_itinerary_days": "{count, plural, =1{1 day} other{{count} days}}",
  "@trips_overview_itinerary_days": {"placeholders": {"count": {"type": "int"}}},
  "trips_overview_itinerary_divesPlanned": "{count, plural, =1{1 dive planned} other{{count} dives planned}}",
  "@trips_overview_itinerary_divesPlanned": {"placeholders": {"count": {"type": "int"}}},
  "trips_overview_itinerary_none": "Not planned yet",
  "trips_overview_plan": "Plan",
  "trips_overview_plan_divesPerDay": "{count} dives/day",
  "@trips_overview_plan_divesPerDay": {"placeholders": {"count": {"type": "int"}}},
  "trips_overview_plan_sharing": "{count, plural, =1{1 diver} other{{count} divers}} share cylinders",
  "@trips_overview_plan_sharing": {"placeholders": {"count": {"type": "int"}}},
  "trips_overview_plan_notSet": "Not set",
```

Translate each into the ten other locales in the same register as their `trips_detail_tab_*` neighbours (de/es/it informal, es without "tú"); the plural shapes follow each locale's existing `trips_cylinders_summaryUnfilled` and `trips_gear_packedFromSet` entries. Run `flutter gen-l10n`, then `TMPDIR=$SCR/tmp flutter test test/l10n/arb_parity_test.dart`.

- [ ] **Step 2: Create the tab enum**

Create `lib/features/trips/presentation/widgets/trip_detail_tabs.dart`:

```dart
/// The trip page's tabs, in display order (#2845). Every trip type shows all
/// six; the index doubles as the TabController index.
enum TripDetailTab { overview, itinerary, gear, checklist, dives, photos }
```

- [ ] **Step 3: Write the failing summary card tests**

Create `test/features/trips/presentation/widgets/overview/trip_overview_summary_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_overview_summary_card.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

final _now = DateTime.now();
DateTime _days(int n) => DateTime(_now.year, _now.month, _now.day + n);

Trip _trip({int? perDay = 3, int sharing = 2}) => Trip(
  id: 't1',
  name: 'Bonaire',
  startDate: _days(12),
  endDate: _days(19),
  divesPerDayTarget: perDay,
  diversSharingCylinders: sharing,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

TripChecklistItem _todo(String id, {bool done = false, DateTime? due}) =>
    TripChecklistItem(
      id: id,
      tripId: 't1',
      title: id,
      isDone: done,
      dueDate: due,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

TripCylinderState _slot(String id) => foldCylinderState(
  cylinder: TripCylinder(
    id: id,
    tripId: 't1',
    label: id,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  events: const [],
  uses: const [],
);

ItineraryDay _day(int offset, {int? planned, DayType type = DayType.diveDay}) =>
    ItineraryDay(
      id: 'i$offset',
      tripId: 't1',
      dayNumber: offset + 1,
      date: _days(12 + offset),
      dayType: type,
      plannedDives: planned,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

DueClock _alert(String itemId, ServiceClockSeverity severity) {
  final t0 = DateTime(2025, 1, 1);
  return (
    item: EquipmentItem(id: itemId, name: itemId, type: EquipmentType.regulator),
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's-$itemId',
        equipmentId: itemId,
        serviceKindId: 'k',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'k',
        name: 'Annual service',
        defaultIntervalDays: 365,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: _days(14),
      severity: severity,
      now: _now,
    ),
  );
}

Future<List<TripDetailTab>> _pump(
  WidgetTester tester, {
  Trip? trip,
  List<TripChecklistItem>? checklist,
  List<EquipmentItem>? gear,
  List<TripCylinderState>? slots,
  List<DueClock>? alerts,
  List<ItineraryDay>? days,
  bool loading = false,
}) async {
  final opened = <TripDetailTab>[];
  final never = Completer<List<TripChecklistItem>>().future;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        tripChecklistProvider('t1').overrideWith(
          (ref) => loading ? never : Future.value(checklist ?? const []),
        ),
        tripGearProvider('t1').overrideWith((ref) async => gear ?? const []),
        tripCylinderStatesProvider(
          't1',
        ).overrideWith((ref) async => slots ?? const []),
        tripServiceAlertsProvider(
          't1',
        ).overrideWith((ref) async => alerts ?? const []),
        itineraryDaysProvider('t1').overrideWith((ref) async => days ?? const []),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TripOverviewSummaryCard(
            trip: trip ?? _trip(),
            onOpenTab: opened.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('the checklist row counts done items and the week ahead', (
    tester,
  ) async {
    await _pump(
      tester,
      checklist: [
        _todo('a', done: true),
        _todo('b', due: _days(5)),
        _todo('c', due: _days(-1)),
        _todo('d'),
      ],
    );
    expect(find.text('1 of 4 done · 1 due this week · 1 overdue'), findsOneWidget);
  });

  testWidgets('the gear row counts packed items, cylinders and alerts', (
    tester,
  ) async {
    await _pump(
      tester,
      gear: const [
        EquipmentItem(id: 'g1', name: 'Reg', type: EquipmentType.regulator),
        EquipmentItem(id: 'g2', name: 'Fins', type: EquipmentType.fins),
      ],
      slots: [_slot('c1'), _slot('c2'), _slot('c3')],
      alerts: [_alert('g1', ServiceClockSeverity.dueSoon)],
    );
    expect(
      find.text('2 items packed · 3 cylinders · 1 service alert'),
      findsOneWidget,
    );
  });

  testWidgets('the itinerary row sums planned dives and falls back to the '
      'per-day target', (tester) async {
    await _pump(
      tester,
      days: [
        _day(0, type: DayType.travel),
        _day(1, planned: 2),
        _day(2),
        _day(3, type: DayType.rest),
      ],
    );
    // 2 planned, plus the target of 3 on the derived dive day.
    expect(find.text('4 days · 5 dives planned'), findsOneWidget);
  });

  testWidgets('with no itinerary the row says so', (tester) async {
    await _pump(tester);
    expect(find.text('Not planned yet'), findsOneWidget);
  });

  testWidgets('the plan row reads the planning numbers, or Not set', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('3 dives/day · 2 divers share cylinders'), findsOneWidget);
    await _pump(tester, trip: _trip(perDay: null, sharing: 1));
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('a row whose data has not loaded shows its label alone', (
    tester,
  ) async {
    await _pump(tester, loading: true);
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.textContaining('of'), findsNothing);
  });

  testWidgets('each row opens its tab', (tester) async {
    final opened = await _pump(tester);
    await tester.tap(find.text('Checklist'));
    await tester.tap(find.text('Gear'));
    await tester.tap(find.text('Itinerary'));
    expect(opened, [
      TripDetailTab.checklist,
      TripDetailTab.gear,
      TripDetailTab.itinerary,
    ]);
  });
}
```

Add `import 'dart:async';` for `Completer`.

- [ ] **Step 4: Run it to see it fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/overview/trip_overview_summary_card_test.dart`
Expected: compile error, the card file does not exist.

- [ ] **Step 5: Create the summary card**

Create `lib/features/trips/presentation/widgets/overview/trip_overview_summary_card.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Prepare overview's one card (#2845): a row per thing to prepare,
/// each a one-line summary that opens its tab. A row whose data has not
/// loaded shows its label alone rather than a zero.
class TripOverviewSummaryCard extends ConsumerWidget {
  final Trip trip;

  /// Where a row goes; without one the page's DefaultTabController is used.
  final ValueChanged<TripDetailTab>? onOpenTab;

  const TripOverviewSummaryCard({
    super.key,
    required this.trip,
    this.onOpenTab,
  });

  void _open(BuildContext context, TripDetailTab tab) {
    final handler = onOpenTab;
    if (handler != null) {
      handler(tab);
    } else {
      DefaultTabController.of(context).animateTo(tab.index);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    final today = tripDay(clock.now());

    final checklist = ref.watch(tripChecklistProvider(trip.id)).value;
    final gear = ref.watch(tripGearProvider(trip.id)).value;
    final slots = ref.watch(tripCylinderStatesProvider(trip.id)).value;
    final alerts = ref.watch(tripServiceAlertsProvider(trip.id)).value;
    final days = ref.watch(itineraryDaysProvider(trip.id)).value;

    // Checklist: done count, then what presses within a week or is late.
    List<InlineSpan>? checklistSpans;
    if (checklist != null) {
      final open = checklist.where((i) => !i.isDone);
      final overdue = open
          .where((i) => i.dueDate != null && tripDay(i.dueDate!).isBefore(today))
          .length;
      final dueSoon = open.where((i) {
        final due = i.dueDate;
        if (due == null) return false;
        final d = tripDay(due);
        return !d.isBefore(today) &&
            !d.isAfter(DateTime(today.year, today.month, today.day + 7));
      }).length;
      final done = checklist.where((i) => i.isDone).length;
      checklistSpans = [
        TextSpan(
          text: l10n.trips_overview_checklist_progress(done, checklist.length),
        ),
        if (dueSoon > 0)
          TextSpan(
            text: ' · ${l10n.trips_overview_checklist_dueSoon(dueSoon)}',
            style: TextStyle(color: status.warn.onContainer),
          ),
        if (overdue > 0)
          TextSpan(
            text: ' · ${l10n.trips_overview_checklist_overdue(overdue)}',
            style: TextStyle(color: theme.colorScheme.error),
          ),
      ];
    }

    // Gear: packed items, slots, and the alert count tinted by the worst.
    List<InlineSpan>? gearSpans;
    if (gear != null && slots != null) {
      final alertCount = alerts == null ? 0 : tripServiceAlertItemCount(alerts);
      gearSpans = [
        TextSpan(text: l10n.trips_overview_gear_packed(gear.length)),
        if (slots.isNotEmpty)
          TextSpan(
            text: ' · ${l10n.trips_overview_gear_cylinders(slots.length)}',
          ),
        if (alertCount > 0)
          TextSpan(
            text: ' · ${l10n.trips_overview_gear_serviceAlerts(alertCount)}',
            style: TextStyle(
              color: tripServiceAlertsAnyOverdue(alerts!)
                  ? theme.colorScheme.error
                  : status.warn.onContainer,
            ),
          ),
      ];
    }

    // Itinerary: rows, and the dives they plan (R5: a set count, else the
    // per-day target on a dive day, else nothing).
    List<InlineSpan>? itinerarySpans;
    if (days != null) {
      if (days.isEmpty) {
        itinerarySpans = [TextSpan(text: l10n.trips_overview_itinerary_none)];
      } else {
        var planned = 0;
        for (final d in days) {
          planned +=
              d.plannedDives ??
              (d.dayType == DayType.diveDay ? (trip.divesPerDayTarget ?? 0) : 0);
        }
        itinerarySpans = [
          TextSpan(text: l10n.trips_overview_itinerary_days(days.length)),
          if (planned > 0)
            TextSpan(
              text: ' · ${l10n.trips_overview_itinerary_divesPlanned(planned)}',
            ),
        ];
      }
    }

    // Plan: the edit page's planning numbers.
    final planParts = [
      if (trip.divesPerDayTarget != null)
        l10n.trips_overview_plan_divesPerDay(trip.divesPerDayTarget!),
      if (trip.diversSharingCylinders > 1)
        l10n.trips_overview_plan_sharing(trip.diversSharingCylinders),
    ];
    final planSpans = [
      TextSpan(
        text: planParts.isEmpty
            ? l10n.trips_overview_plan_notSet
            : planParts.join(' · '),
      ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _Row(
            icon: Icons.checklist,
            label: l10n.trips_detail_tab_checklist,
            summary: checklistSpans,
            onTap: () => _open(context, TripDetailTab.checklist),
          ),
          _Row(
            icon: Icons.luggage_outlined,
            label: l10n.trips_detail_tab_gear,
            summary: gearSpans,
            onTap: () => _open(context, TripDetailTab.gear),
          ),
          _Row(
            icon: Icons.event_note,
            label: l10n.trips_detail_tab_itinerary,
            summary: itinerarySpans,
            onTap: () => _open(context, TripDetailTab.itinerary),
          ),
          _Row(
            icon: Icons.tune,
            label: l10n.trips_overview_plan,
            summary: planSpans,
            onTap: () => context.push('/trips/${trip.id}/edit'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<InlineSpan>? summary;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.label,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      // The summary is the subtitle, never the trailing slot: a trailing
      // widget takes its width before the title is laid out.
      subtitle: summary == null
          ? null
          : Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                children: summary,
              ),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
```

`trips_detail_tab_gear` does not exist yet: add it in Step 1's ARB batch, beside `trips_detail_tab_dives` ("Gear"; de "Ausrüstung", es "Equipo", fr "Matériel", it "Attrezzatura", nl "Uitrusting", pt "Equipamento", ar "المعدات", he "ציוד", hu "Felszerelés", zh "装备"). `StatusColors.of(context).warn.onContainer` is what the alerts panel used for the warn tint; keep the same.

- [ ] **Step 6: Run the card tests**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/overview/trip_overview_summary_card_test.dart`
Expected: PASS.

- [ ] **Step 7: Write the failing hero and overview tests**

In `test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`, give `pumpHero` a `bool showEmptyState = true` parameter passed through to `TripStoryHero(..., showEmptyState: showEmptyState)`, and add:

```dart
  testWidgets('showEmptyState false keeps the countdown and drops the '
      'empty state', (tester) async {
    final trip = _trip(start: _daysFrom(DateTime.now(), 12), end: _daysFrom(DateTime.now(), 19));
    await pumpHero(tester, _story(trip), showEmptyState: false);
    expect(find.text('12 days until departure'), findsOneWidget);
    expect(find.text('No dives or itinerary yet'), findsNothing);
  });
```

In `test/features/trips/presentation/widgets/trip_overview_tab_test.dart`, add imports for `TripPrepareOverview`, `TripStoryView`, `trip_detail_tabs.dart`, `package:clock/clock.dart`, and these tests (the file's `_trip` is dated 2026-03-25 to 26; wrap the pump in `withClock`):

```dart
  testWidgets('before departure the overview is the Prepare page', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 3, 13)), () async {
      await pumpTab(tester, extra: [
        tripStoryProvider('trip-1').overrideWith(
          (ref) async => buildTripStory(
            trip: _trip,
            dives: const [],
            itineraryDays: const [],
            mediaByDiveId: const {},
            sightingsByDiveId: const {},
            checklistItems: const [],
            today: DateTime(2026, 3, 13),
          ),
        ),
        ...prepareOverrides(),
      ]);
    });
    expect(find.byType(TripPrepareOverview), findsOneWidget);
    expect(find.byType(TripStoryView), findsNothing);
    expect(find.text('12 days until departure'), findsOneWidget);
    expect(find.text('Total Dives'), findsNothing);
  });

  testWidgets('a trip starting today shows the story', (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 3, 25, 9)), () async {
      await pumpTab(tester, extra: [
        tripStoryProvider('trip-1').overrideWith(
          (ref) async => buildTripStory(
            trip: _trip,
            dives: const [],
            itineraryDays: const [],
            mediaByDiveId: const {},
            sightingsByDiveId: const {},
            checklistItems: const [],
            today: DateTime(2026, 3, 25),
          ),
        ),
        ...prepareOverrides(),
      ]);
    });
    expect(find.byType(TripStoryView), findsOneWidget);
    expect(find.byType(TripPrepareOverview), findsNothing);
  });
```

with a helper at file level that stubs the summary card's providers:

```dart
List<Override> prepareOverrides() => [
  tripChecklistProvider('trip-1').overrideWith((ref) async => const []),
  tripGearProvider('trip-1').overrideWith((ref) async => const []),
  tripCylinderStatesProvider('trip-1').overrideWith((ref) async => const []),
  tripServiceAlertsProvider('trip-1').overrideWith((ref) async => const []),
  itineraryDaysProvider('trip-1').overrideWith((ref) async => const []),
];
```

(import those providers). The `clock` package is already a dependency (`Trip.isUpcoming` uses it).

- [ ] **Step 8: Run them to see them fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/story/trip_story_hero_test.dart test/features/trips/presentation/widgets/trip_overview_tab_test.dart`
Expected: compile errors (`showEmptyState`, `TripPrepareOverview`).

- [ ] **Step 9: The hero flag, the Prepare overview, the mode switch**

In `lib/features/trips/presentation/widgets/story/trip_story_hero.dart`:

```dart
class TripStoryHero extends ConsumerWidget {
  final TripStory story;
  final VoidCallback? onScanForDives;

  /// The Prepare overview (#2845) has its own rows under the hero, so it
  /// turns the empty state off.
  final bool showEmptyState;

  const TripStoryHero({
    super.key,
    required this.story,
    this.onScanForDives,
    this.showEmptyState = true,
  });
```

and change `if (story.isEmpty) ...[` to `if (showEmptyState && story.isEmpty) ...[`.

Create `lib/features/trips/presentation/widgets/overview/trip_prepare_overview.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_overview_summary_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Overview before departure (#2845): the hero with its countdown, one
/// summary card whose rows open the other tabs, and the notes. No map, no
/// stats, no story: there is nothing to tell yet.
class TripPrepareOverview extends StatelessWidget {
  final TripStory story;
  final ValueChanged<TripDetailTab>? onOpenTab;

  const TripPrepareOverview({super.key, required this.story, this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final trip = story.trip;
    final theme = Theme.of(context);
    return ListView(
      key: const Key('trip-prepare-overview'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TripStoryHero(story: story, showEmptyState: false),
        ),
        TripOverviewSummaryCard(trip: trip, onOpenTab: onOpenTab),
        if (trip.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.trips_detail_sectionTitle_notes,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(trip.notes),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

In `lib/features/trips/presentation/widgets/trip_overview_tab.dart`, add imports for `package:clock/clock.dart`, `trip_prepare_overview.dart` and `trip_detail_tabs.dart`, add the field:

```dart
  /// Where the Prepare overview's rows go (Task 7 wires the tab row).
  final ValueChanged<TripDetailTab>? onOpenTab;

  const TripOverviewTab({
    super.key,
    required this.tripWithStats,
    this.onOpenTab,
  });
```

and replace the trailing `return TripStoryView(...)` with:

```dart
    // Before the first day there is nothing to tell: the page prepares.
    // From the first day on, in progress or past, it tells the story.
    if (trip.startsAfter(clock.now())) {
      return TripPrepareOverview(story: story, onOpenTab: onOpenTab);
    }
    return TripStoryView(
      story: story,
      stats: tripWithStats,
      onScanForDives: () => scanForTripDives(context, ref, trip),
    );
```

- [ ] **Step 10: Run the tests, format, analyze, guards**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/overview/ test/features/trips/presentation/widgets/story/trip_story_hero_test.dart test/features/trips/presentation/widgets/trip_overview_tab_test.dart test/features/trips/presentation/pages/trip_detail_page_test.dart test/l10n/arb_parity_test.dart`
Expected: PASS. Then `dart format .`, `flutter analyze`, `TMPDIR=$SCR/tmp flutter test test/architecture/`.

- [ ] **Step 11: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_detail_tabs.dart lib/features/trips/presentation/widgets/overview lib/features/trips/presentation/widgets/story/trip_story_hero.dart lib/features/trips/presentation/widgets/trip_overview_tab.dart lib/l10n/arb test/features/trips/presentation/widgets/overview test/features/trips/presentation/widgets/story/trip_story_hero_test.dart test/features/trips/presentation/widgets/trip_overview_tab_test.dart
git commit -m "feat(trips): Prepare overview before departure"
```

---
### Task 6: The Gear tab and the in-progress Cylinders summary card

**Files:**
- Create: `lib/features/trips/domain/services/trip_cylinder_drafts.dart`
- Modify: `lib/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart` (`rentalOnly`, use the drafts helper)
- Modify: `lib/features/trips/presentation/widgets/trip_service_alert_list.dart` (export `tripServiceAlertSubtitle`)
- Modify: `lib/features/trips/presentation/widgets/trip_scrubber_margin_details.dart` (export `tripScrubberMarginMinutes`)
- Create: `lib/features/trips/presentation/widgets/gear/trip_gear_add_sheet.dart`
- Create: `lib/features/trips/presentation/widgets/gear/trip_packed_item_row.dart`
- Create: `lib/features/trips/presentation/widgets/gear/trip_cylinder_slot_row.dart`
- Create: `lib/features/trips/presentation/widgets/gear/trip_gear_tab.dart`
- Create: `lib/features/trips/presentation/widgets/trip_cylinders_summary_card.dart`
- Modify: all 11 ARB files (keys beside `trips_gear_packedFromSet`)
- Test: `test/features/trips/domain/services/trip_cylinder_drafts_test.dart` (create)
- Test: `test/features/trips/presentation/widgets/gear/trip_gear_tab_test.dart` (create)
- Test: `test/features/trips/presentation/widgets/trip_cylinders_summary_card_test.dart` (create)

**Interfaces:**
- Consumes: `tripGearProvider`, `tripCylinderStatesProvider`, `tripCylindersProvider`, `tripServiceAlertsProvider`, `tripScrubberMarginsProvider`, `tripFillForecastProvider`, `tripEquipmentRepositoryProvider.pack/unpack`, `tripCylinderRepositoryProvider.createCylinders`, `equipmentRepositoryProvider.usableSetMemberIds`, `validatedCurrentDiverIdProvider`, `EquipmentPickerSheet`, `EquipmentSetPickerSheet`, `showAddTripCylindersSheet`, `tripCylinderCounts`, `tripCylinderStatusColor`, `tripCylinderStatusLabel`, `tripCylinderMixLabel`, `TripFillForecastText`, `equipmentTypeIcon`, `EquipmentTypeDisplay.localizedName`.
- Produces: `TripCylinder tripCylinderDraftFromEquipment(EquipmentItem item, {required String tripId, required int sortOrder, required DateTime now})`; `int nextTripCylinderSortOrder(List<TripCylinder> existing)`; `showAddTripCylindersSheet(context, {tripId, existing, bool rentalOnly = false})`; `String tripServiceAlertSubtitle(BuildContext context, UnitFormatter units, ServiceClockStatus status)`; `String tripScrubberMarginMinutes(double value)`; `Future<void> showTripGearAddSheet(BuildContext context, {required Trip trip, required List<EquipmentItem> packed, required List<TripCylinder> slots})`; `TripPackedItemRow({required EquipmentItem item, DueClock? alert, ScrubberMargin? margin, required Future<void> Function() onUnpack})`; `TripCylinderSlotRow({required TripCylinderState state, required bool started, required UnitFormatter units, required VoidCallback onTap})`; `TripGearTab({required Trip trip})`; `TripCylindersSummaryCard({required Trip trip})`.
- l10n keys: `trips_gear_add_action` ("Add"), `trips_gear_add_fromEquipment` ("From my equipment"), `trips_gear_add_fromSet` ("An equipment set"), `trips_gear_add_rental` ("Rental cylinders"), `trips_gear_section_packed` ("Packed"), `trips_gear_section_cylinders` ("Cylinders"), `trips_gear_empty_upcoming` ("Nothing packed yet. Add the gear you'll bring and the cylinders you'll dive from."), `trips_gear_empty_past` ("Nothing was packed for this trip."), `trips_gear_slot_rental` ("Rental"), `trips_gear_slot_own` ("My equipment"), `trips_gear_openBoard` ("Open board"), `trips_gear_addedSummary` ("{packed, plural, =0{} =1{Packed 1 item} other{Packed {packed} items}}{cylinders, plural, =0{} =1{, added 1 cylinder} other{, added {cylinders} cylinders}}"). Reuses `trips_gear_remove`, `trips_gear_failed`, `trips_gear_packedFromSet`, `trips_scrubber_bannerMargin`.

- [ ] **Step 1: Add the ARB keys**

`app_en.arb`, after `"trips_gear_packedFromSet": ...` and its `@` entry:

```json
  "trips_gear_add_action": "Add",
  "trips_gear_add_fromEquipment": "From my equipment",
  "trips_gear_add_fromSet": "An equipment set",
  "trips_gear_add_rental": "Rental cylinders",
  "trips_gear_section_packed": "Packed",
  "trips_gear_section_cylinders": "Cylinders",
  "trips_gear_empty_upcoming": "Nothing packed yet. Add the gear you'll bring and the cylinders you'll dive from.",
  "trips_gear_empty_past": "Nothing was packed for this trip.",
  "trips_gear_slot_rental": "Rental",
  "trips_gear_slot_own": "My equipment",
  "trips_gear_openBoard": "Open board",
```

Translate into the ten other locales beside each file's `trips_gear_packedFromSet`, in the register of the neighbouring `trips_gear_*` keys. Run `flutter gen-l10n` and the parity test.

- [ ] **Step 2: Write the failing drafts tests**

Create `test/features/trips/domain/services/trip_cylinder_drafts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_drafts.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1);

  TripCylinder slot(int order) => TripCylinder(
    id: 'c$order',
    tripId: 't1',
    sortOrder: order,
    createdAt: now,
    updatedAt: now,
  );

  test('the next sort order follows the highest, gaps included', () {
    expect(nextTripCylinderSortOrder(const []), 0);
    expect(nextTripCylinderSortOrder([slot(0), slot(4)]), 5);
  });

  test('an owned cylinder becomes a linked slot labelled by its mark', () {
    const item = EquipmentItem(
      id: 'e1',
      name: 'Faber 12',
      type: EquipmentType.tank,
      attributes: {'identifier': 'S/N 4411'},
    );
    final draft = tripCylinderDraftFromEquipment(
      item,
      tripId: 't1',
      sortOrder: 3,
      now: now,
    );
    expect(draft.equipmentId, 'e1');
    expect(draft.label, 'S/N 4411');
    expect(draft.sortOrder, 3);
    expect(draft.tripId, 't1');
  });

  test('with no mark the slot takes the item name', () {
    const item = EquipmentItem(id: 'e1', name: 'Faber 12', type: EquipmentType.tank);
    expect(
      tripCylinderDraftFromEquipment(item, tripId: 't1', sortOrder: 0, now: now)
          .label,
      'Faber 12',
    );
  });
}
```

If `EquipmentItem` stores the identifier differently from an `attributes` map (check `EquipmentAttrKeys.identifier` and the constructor), build the fixture the way `test/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet_test.dart` builds an owned tank.

- [ ] **Step 3: Run it to see it fail, then create the helper**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/domain/services/trip_cylinder_drafts_test.dart`
Expected: compile error.

Create `lib/features/trips/domain/services/trip_cylinder_drafts.dart`:

```dart
import 'dart:math';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

/// The board position after the last slot: deletions leave gaps, so the
/// count of slots could land a new one above an existing one.
int nextTripCylinderSortOrder(List<TripCylinder> existing) => existing.isEmpty
    ? 0
    : existing.map((c) => c.sortOrder).reduce(max) + 1;

/// A slot for one of the diver's own cylinders: linked to the item, named
/// by its mark (else its name), carrying the item's specs. Shared by the
/// Cylinders sheet and the Gear tab's Add (#2845).
TripCylinder tripCylinderDraftFromEquipment(
  EquipmentItem item, {
  required String tripId,
  required int sortOrder,
  required DateTime now,
}) {
  final mark = item.identifier?.trim() ?? '';
  return TripCylinder(
    id: '',
    tripId: tripId,
    equipmentId: item.id,
    label: mark.isEmpty ? item.name : mark,
    volume: item.volumeL,
    workingPressure: item.workingPressureBar,
    material: item.tankMaterial,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}
```

In `add_trip_cylinders_sheet.dart`, replace the `start` computation in `_save` with `final start = nextTripCylinderSortOrder(widget.existing);`, replace the owned-draft construction loop body with `drafts.add(tripCylinderDraftFromEquipment(picks[i], tripId: widget.tripId, sortOrder: start + i, now: now));`, drop the now-unused `dart:math` import if nothing else uses `max`, and import the helper. Add `rentalOnly`:

```dart
Future<void> showAddTripCylindersSheet(
  BuildContext context, {
  required String tripId,
  required List<TripCylinder> existing,
  bool rentalOnly = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddTripCylindersSheet(
      tripId: tripId,
      existing: existing,
      rentalOnly: rentalOnly,
    ),
  );
}
```

Add `final bool rentalOnly;` and `this.rentalOnly = false` to `_AddTripCylindersSheet`, and in `build` wrap the `SegmentedButton<_AddMode>(...)` and the `SizedBox(height: 12)` after it in `if (!widget.rentalOnly) ...[ ... ],`. (`_mode` starts at rental, so a rental-only sheet never shows the owned branch.)

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/domain/services/trip_cylinder_drafts_test.dart test/features/trips/presentation/widgets/cylinders/`
Expected: PASS.

- [ ] **Step 4: Export the two wording helpers**

In `trip_service_alert_list.dart`, move `_alertSubtitle` out of the class as a top-level function (the file is on the wording guard's allowlist, so the sentence stays composed there):

```dart
/// The one line under a gear row or alert row that says when a clock falls
/// due: the shared overdue sentence, or "due before {date}" for a clock
/// still ahead. Composed here and nowhere else (the wording guard).
String tripServiceAlertSubtitle(
  BuildContext context,
  UnitFormatter units,
  ServiceClockStatus status,
) {
  // Key off severity, not now-vs-dueDate: a clock overdue on dives/hours can
  // still have a future (or null) date trigger, and must read as "overdue".
  final dueDate = status.dueDate;
  if (status.severity == ServiceClockSeverity.overdue || dueDate == null) {
    return context.l10n.equipment_service_overdue(status.kind.name);
  }
  return context.l10n.trips_serviceAlert_dueBefore(
    status.kind.name,
    units.formatDate(dueDate),
  );
}
```

and call it from the list's tile (`subtitle: Text(tripServiceAlertSubtitle(context, units, alert.status))`).

In `trip_scrubber_margin_details.dart`, rename `_minutes` to `tripScrubberMarginMinutes` (public) and update its two call sites.

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/trip_service_alert_list_test.dart test/features/trips/presentation/widgets/trip_scrubber_margin_details_test.dart test/architecture/service_status_wording_single_source_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing Gear tab tests**

Create `test/features/trips/presentation/widgets/gear/trip_gear_tab_test.dart`, reusing the fixtures of `test/features/trips/presentation/widgets/trip_gear_card_test.dart` (copy its `_FakePacks`, `_FakeEquipment`, `trip()`, `bcd`, `fins`, `reg`, `kit()` helpers and the `testApp` pump shape; that file is deleted in Task 8):

```dart
// imports: the gear card test's imports, minus trip_gear_card.dart, plus
// trip_gear_tab.dart, trip_cylinder.dart, trip_cylinder_state.dart,
// trip_cylinder_state_fold.dart, trip_cylinder_providers.dart,
// trip_fill_forecast_providers.dart, scrubber_margin.dart,
// scrubber_margin_providers.dart, service_clock_status.dart,
// service_kind.dart, service_schedule.dart, go_router.dart.

class _FakeSlots extends TripCylinderRepository {
  final created = <List<TripCylinder>>[];
  @override
  Future<List<TripCylinder>> createCylinders(List<TripCylinder> cylinders) async {
    created.add(cylinders);
    return cylinders;
  }
}

TripCylinderState slot(String id, {String? equipmentId, bool full = false}) {
  final at = DateTime.utc(2026, 1, 1);
  return foldCylinderState(
    cylinder: TripCylinder(
      id: id,
      tripId: 't1',
      equipmentId: equipmentId,
      label: id,
      workingPressure: 207,
      createdAt: at,
      updatedAt: at,
    ),
    events: full
        ? [
            TripCylinderEvent(
              id: 'e-$id',
              tripCylinderId: id,
              kind: TripCylinderEventKind.fill,
              occurredAt: at,
              bottleLabel: '#140',
              pressure: 207,
              o2Percent: 32,
              createdAt: at,
              updatedAt: at,
            ),
          ]
        : const [],
    uses: const [],
  );
}

Future<({_FakePacks packs, _FakeSlots slots, List<String> pushed})> pump(
  WidgetTester tester, {
  Trip? onTrip,
  List<EquipmentItem> gear = const [],
  List<TripCylinderState> states = const [],
  List<DueClock> alerts = const [],
  List<ScrubberMargin> margins = const [],
  List<EquipmentItem> active = const [],
  List<EquipmentSet> sets = const [],
}) async {
  final packs = _FakePacks();
  final slots = _FakeSlots();
  final pushed = <String>[];
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: TripGearTab(trip: onTrip ?? trip())),
      ),
      GoRoute(
        path: '/trips/:id/cylinders',
        builder: (_, s) {
          pushed.add(s.uri.path);
          return const Scaffold();
        },
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (_, s) {
          pushed.add(s.uri.path);
          return const Scaffold();
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        tripGearProvider('t1').overrideWith((ref) async => gear),
        tripCylinderStatesProvider('t1').overrideWith((ref) async => states),
        tripCylindersProvider(
          't1',
        ).overrideWith((ref) async => [for (final s in states) s.cylinder]),
        tripServiceAlertsProvider('t1').overrideWith((ref) async => alerts),
        tripScrubberMarginsProvider('t1').overrideWith((ref) async => margins),
        tripFillForecastProvider('t1').overrideWith((ref) async => null),
        tripEquipmentRepositoryProvider.overrideWithValue(packs),
        tripCylinderRepositoryProvider.overrideWithValue(slots),
        activeEquipmentProvider.overrideWith((ref) async => active),
        equipmentSetsProvider.overrideWith((ref) async => sets),
        equipmentSetWithItemsProvider.overrideWith(
          (ref, id) async => sets.where((s) => s.id == id).firstOrNull,
        ),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        equipmentRepositoryProvider.overrideWithValue(_FakeEquipment(const {})),
      ].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (packs: packs, slots: slots, pushed: pushed);
}

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  testWidgets('an upcoming trip with nothing explains Add', (tester) async {
    await pump(tester);
    expect(
      find.text(
        "Nothing packed yet. Add the gear you'll bring and the cylinders "
        "you'll dive from.",
      ),
      findsOneWidget,
    );
    expect(find.text('Add'), findsWidgets);
  });

  testWidgets('a past trip with nothing says so and offers no Add', (
    tester,
  ) async {
    await pump(tester, onTrip: trip(past: true));
    expect(find.text('Nothing was packed for this trip.'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
  });

  testWidgets('packed gear and cylinders sit in two sections', (tester) async {
    await pump(
      tester,
      gear: const [bcd, fins],
      states: [slot('Truck 1'), slot('Truck 2')],
    );
    expect(find.text('Packed'), findsOneWidget);
    expect(find.text('Cylinders'), findsOneWidget);
    expect(find.text('BCD'), findsOneWidget);
    expect(find.text('Truck 2'), findsOneWidget);
    expect(find.text('Rental'), findsNWidgets(2));
  });

  testWidgets('an owned cylinder is listed once', (tester) async {
    const tank = EquipmentItem(id: 'tk', name: 'Faber 12', type: EquipmentType.tank);
    await pump(
      tester,
      gear: const [tank, bcd],
      states: [slot('Faber 12', equipmentId: 'tk')],
    );
    expect(find.text('Faber 12'), findsOneWidget);
    expect(find.text('My equipment'), findsOneWidget);
  });

  testWidgets('a service clock reads on its item, tinted', (tester) async {
    await pump(tester, gear: const [reg], alerts: [dueClock(itemId: 'reg')]);
    expect(find.textContaining('due before'), findsOneWidget);
  });

  testWidgets('a scrubber margin reads on its rebreather', (tester) async {
    const ccr = EquipmentItem(id: 'ccr', name: 'JJ', type: EquipmentType.rebreather);
    await pump(
      tester,
      gear: const [ccr],
      margins: [margin(ccr, marginAfter: 120, caution: false)],
    );
    expect(find.text('120 min scrubber margin'), findsOneWidget);
  });

  testWidgets('before departure a slot shows its specs; from day one its '
      'state', (tester) async {
    await pump(tester, states: [slot('Truck 1', full: true)]);
    expect(find.textContaining('207 bar'), findsOneWidget);
    expect(find.text('Open board'), findsNothing);
    final now = DateTime.now();
    final started = trip().copyWith(
      startDate: DateTime(now.year, now.month, now.day - 1),
    );
    await pump(tester, onTrip: started, states: [slot('Truck 1', full: true)]);
    expect(find.textContaining('#140 · EAN32 · 207 bar'), findsOneWidget);
    expect(find.text('Open board'), findsOneWidget);
  });

  testWidgets('tapping a slot opens the board', (tester) async {
    final h = await pump(tester, states: [slot('Truck 1')]);
    await tester.tap(find.text('Truck 1'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['/trips/t1/cylinders']);
  });

  testWidgets('Unpack removes the item', (tester) async {
    final h = await pump(tester, gear: const [bcd]);
    await tester.tap(find.byKey(const Key('trip-gear-menu-bcd')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpack'));
    await tester.pumpAndSettle();
    expect(h.packs.unpacked, [('t1', 'bcd')]);
  });

  testWidgets('Add offers three ways in', (tester) async {
    await pump(tester, gear: const [bcd]);
    await tester.tap(find.byKey(const Key('trip-gear-add')));
    await tester.pumpAndSettle();
    expect(find.text('From my equipment'), findsOneWidget);
    expect(find.text('An equipment set'), findsOneWidget);
    expect(find.text('Rental cylinders'), findsOneWidget);
  });

  testWidgets('From my equipment packs a picked item', (tester) async {
    final h = await pump(tester, active: const [bcd]);
    await tester.tap(find.byKey(const Key('trip-gear-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From my equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BCD').last);
    await tester.pumpAndSettle();
    expect(h.packs.packed.single.$2, ['bcd']);
    expect(h.slots.created, isEmpty);
  });

  testWidgets('From my equipment makes a picked cylinder a slot', (
    tester,
  ) async {
    const tank = EquipmentItem(id: 'tk', name: 'Faber 12', type: EquipmentType.tank);
    final h = await pump(tester, active: const [tank]);
    await tester.tap(find.byKey(const Key('trip-gear-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From my equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faber 12').last);
    await tester.pumpAndSettle();
    expect(h.packs.packed, isEmpty);
    expect(h.slots.created.single.single.equipmentId, 'tk');
  });

  testWidgets('An equipment set packs the members and slots its cylinders', (
    tester,
  ) async {
    const tank = EquipmentItem(id: 'tk', name: 'Faber 12', type: EquipmentType.tank);
    final h = await pump(tester, sets: [kit(const [bcd, fins, tank])]);
    await tester.tap(find.byKey(const Key('trip-gear-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('An equipment set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reef kit'));
    await tester.pumpAndSettle();
    expect(h.packs.packed.single.$2, ['bcd', 'fins']);
    expect(h.slots.created.single.single.equipmentId, 'tk');
    expect(find.text('Packed 2 items from Reef kit'), findsOneWidget);
  });

  testWidgets('Rental cylinders opens the rental form alone', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('trip-gear-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rental cylinders'));
    await tester.pumpAndSettle();
    expect(find.text('How many'), findsOneWidget);
    expect(find.byType(SegmentedButton<dynamic>), findsNothing);
  });
}
```

`dueClock` and `margin` are the alerts panel test's fixtures (`test/features/trips/presentation/widgets/trip_gear_alerts_panel_test.dart:48-80`): copy them in with an `itemId` parameter and an `EquipmentItem item` parameter respectively. "How many" is `trips_cylinders_add_count`'s English value; read it from the ARB if it differs. `SegmentedButton<dynamic>` may need `find.byWidgetPredicate((w) => w is SegmentedButton)`.

- [ ] **Step 6: Run them to see them fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/gear/trip_gear_tab_test.dart`
Expected: compile error, the tab does not exist.

- [ ] **Step 7: Create the rows**

Create `lib/features/trips/presentation/widgets/gear/trip_packed_item_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_scrubber_margin_details.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One packed item on the Gear tab (#2845). The subtitle is the item's
/// state for this trip when it has one (a service clock falling due, a
/// rebreather's scrubber margin), else its type. Tap opens the item.
class TripPackedItemRow extends ConsumerWidget {
  final EquipmentItem item;
  final DueClock? alert;
  final ScrubberMargin? margin;
  final Future<void> Function() onUnpack;

  const TripPackedItemRow({
    super.key,
    required this.item,
    this.alert,
    this.margin,
    required this.onUnpack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));

    String subtitle = item.type.localizedName(l10n);
    Color? tint;
    final clock = alert?.status;
    final m = margin;
    if (clock != null) {
      subtitle = tripServiceAlertSubtitle(context, units, clock);
      tint = clock.severity == ServiceClockSeverity.overdue
          ? theme.colorScheme.error
          : theme.colorScheme.tertiary;
    } else if (m != null && m.marginAfter != null) {
      subtitle = l10n.trips_scrubber_bannerMargin(
        tripScrubberMarginMinutes(m.marginAfter!),
      );
      if (m.caution) tint = theme.colorScheme.error;
    }

    return ListTile(
      leading: Icon(equipmentTypeIcon(item.type)),
      title: Text(item.name),
      subtitle: Text(subtitle, style: TextStyle(color: tint)),
      trailing: PopupMenuButton<String>(
        key: Key('trip-gear-menu-${item.id}'),
        onSelected: (_) => onUnpack(),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'unpack', child: Text(l10n.trips_gear_remove)),
        ],
      ),
      onTap: () => context.push('/equipment/${item.id}'),
    );
  }
}
```

The warn tint: the alerts panel used `StatusColors.of(context).warn.onContainer` for gear coming due; use that instead of `tertiary` so the colour matches the Overview row (import `package:submersion/core/theme/status_colors.dart`).

Create `lib/features/trips/presentation/widgets/gear/trip_cylinder_slot_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One cylinder slot on the Gear tab (#2845). Before departure: the label,
/// its specs, and whether it is rental or the diver's own. From the first
/// day: the status dot, bottle, mix and pressure, as the board shows them.
class TripCylinderSlotRow extends StatelessWidget {
  final TripCylinderState state;
  final bool started;
  final UnitFormatter units;
  final VoidCallback onTap;

  const TripCylinderSlotRow({
    super.key,
    required this.state,
    required this.started,
    required this.units,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = state.cylinder;
    final specs = [
      if (c.volume != null) units.formatVolume(c.volume),
      if (c.workingPressure != null) units.formatPressure(c.workingPressure),
    ].join(' · ');
    final origin = c.equipmentId == null
        ? l10n.trips_gear_slot_rental
        : l10n.trips_gear_slot_own;

    final String title;
    final String subtitle;
    Widget leading;
    if (started) {
      title =
          '${state.bottleLabel} · '
          '${state.mix == null ? '--' : tripCylinderMixLabel(l10n, state.mix!)} · '
          '${state.pressure == null ? '--' : units.formatPressure(state.pressure)}';
      subtitle = [c.label, origin].join(' · ');
      leading = Icon(
        Icons.circle,
        size: 14,
        color: tripCylinderStatusColor(theme.colorScheme, state.status),
        semanticLabel: tripCylinderStatusLabel(l10n, state.status),
      );
    } else {
      title = c.label;
      subtitle = [if (specs.isNotEmpty) specs, origin].join(' · ');
      leading = Icon(MdiIcons.divingScubaTank, color: theme.colorScheme.primary);
    }

    return ListTile(
      key: Key('trip-gear-slot-${c.id}'),
      leading: leading,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
```

(The old chip composed `'${s.bottleLabel} · ' + mix + pressure` the same way; copy the exact expression from `trip_cylinders_card.dart:91-93` before that file is deleted.)

- [ ] **Step 8: Create the add sheet**

Create `lib/features/trips/presentation/widgets/gear/trip_gear_add_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_drafts.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripGearAddSheet');

enum _Way { equipment, set, rental }

/// The Gear tab's one Add (#2845): a chooser that opens the equipment
/// picker, the set picker, or the rental cylinder form. A cylinder picked
/// from the diver's equipment becomes a slot on the board; anything else is
/// packed.
Future<void> showTripGearAddSheet(
  BuildContext context, {
  required Trip trip,
  required List<EquipmentItem> packed,
  required List<TripCylinder> slots,
}) async {
  final l10n = context.l10n;
  final way = await showModalBottomSheet<_Way>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l10n.trips_gear_add_fromEquipment),
            onTap: () => Navigator.of(sheet).pop(_Way.equipment),
          ),
          ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: Text(l10n.trips_gear_add_fromSet),
            onTap: () => Navigator.of(sheet).pop(_Way.set),
          ),
          ListTile(
            leading: Icon(MdiIcons.divingScubaTank),
            title: Text(l10n.trips_gear_add_rental),
            onTap: () => Navigator.of(sheet).pop(_Way.rental),
          ),
        ],
      ),
    ),
  );
  if (way == null || !context.mounted) return;
  switch (way) {
    case _Way.equipment:
      await _fromEquipment(context, trip, packed, slots);
    case _Way.set:
      await _fromSet(context, trip, slots);
    case _Way.rental:
      await showAddTripCylindersSheet(
        context,
        tripId: trip.id,
        existing: slots,
        rentalOnly: true,
      );
  }
}

Future<void> _fromEquipment(
  BuildContext context,
  Trip trip,
  List<EquipmentItem> packed,
  List<TripCylinder> slots,
) async {
  final picked = await showModalBottomSheet<EquipmentItem>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => EquipmentPickerSheet(
        scrollController: scrollController,
        selectedEquipmentIds: {
          for (final i in packed) i.id,
          for (final s in slots)
            if (s.equipmentId != null) s.equipmentId!,
        },
        hideSpare: true,
        onEquipmentSelected: (item) => Navigator.of(sheetContext).pop(item),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await _apply(context, trip, slots, [picked], setName: null);
}

Future<void> _fromSet(
  BuildContext context,
  Trip trip,
  List<TripCylinder> slots,
) async {
  final picked =
      await showModalBottomSheet<(EquipmentSet, List<EquipmentItem>)>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => EquipmentSetPickerSheet(
            scrollController: scrollController,
            onSetSelected: (set, items) =>
                Navigator.of(sheetContext).pop((set, items)),
          ),
        ),
      );
  if (picked == null || !context.mounted) return;
  await _apply(context, trip, slots, picked.$2, setName: picked.$1.name);
}

/// Packs the non-cylinder items the diver may use and slots the cylinders
/// not already on the board, in one go; says how many a set added.
Future<void> _apply(
  BuildContext context,
  Trip trip,
  List<TripCylinder> slots,
  List<EquipmentItem> items, {
  required String? setName,
}) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  // Everything read before the first await: the tab can be gone by the
  // time the diver resolves.
  final packs = container.read(tripEquipmentRepositoryProvider);
  final cylinders = container.read(tripCylinderRepositoryProvider);
  final equipment = container.read(equipmentRepositoryProvider);
  final diverIdFuture = container.read(validatedCurrentDiverIdProvider.future);
  try {
    final diverId = await diverIdFuture;
    var ids = [for (final i in items) i.id];
    // A member no longer shared with the diver stays in the set but is not
    // applied (issue #2046).
    if (diverId != null) ids = await equipment.usableSetMemberIds(ids, diverId);
    final usable = [for (final i in items) if (ids.contains(i.id)) i];
    final slotted = {for (final s in slots) if (s.equipmentId != null) s.equipmentId!};
    final tanks = [
      for (final i in usable)
        if (i.type == EquipmentType.tank && !slotted.contains(i.id)) i,
    ];
    final others = [for (final i in usable) if (i.type != EquipmentType.tank) i];
    var packedCount = 0;
    if (others.isNotEmpty) {
      packedCount = await packs.pack(trip.id, [for (final i in others) i.id]);
    }
    if (tanks.isNotEmpty) {
      final now = DateTime.now().toUtc();
      final start = nextTripCylinderSortOrder(slots);
      await cylinders.createCylinders([
        for (final (i, t) in tanks.indexed)
          tripCylinderDraftFromEquipment(
            t,
            tripId: trip.id,
            sortOrder: start + i,
            now: now,
          ),
      ]);
    }
    if (setName != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.trips_gear_packedFromSet(packedCount, setName)),
        ),
      );
    }
  } catch (e, stackTrace) {
    _log.error('Failed to add trip gear', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(SnackBar(content: Text(l10n.trips_gear_failed)));
  }
}
```

`ProviderScope.containerOf(context)` keeps these top-level functions free of a `WidgetRef`; if the project convention prefers passing `ref`, give each function a `WidgetRef ref` parameter from the tab instead. Add `import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';`.

- [ ] **Step 9: Create the tab**

Create `lib/features/trips/presentation/widgets/gear/trip_gear_tab.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_cylinder_slot_row.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_add_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_packed_item_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripGearTab');

/// What I'll dive with (#2845): the gear packed for the trip and the
/// cylinder slots on its board, in one list with one Add.
class TripGearTab extends ConsumerWidget {
  final Trip trip;

  const TripGearTab({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final gear = ref.watch(tripGearProvider(trip.id)).value;
    final states = ref.watch(tripCylinderStatesProvider(trip.id)).value;
    if (gear == null || states == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final alerts = ref.watch(tripServiceAlertsProvider(trip.id)).value ?? const [];
    final margins =
        ref.watch(tripScrubberMarginsProvider(trip.id)).value ?? const [];
    final forecast = ref.watch(tripFillForecastProvider(trip.id)).value;
    final now = clock.now();
    final started = !trip.startsAfter(now);
    final upcoming = trip.isUpcoming;
    // Per item: its worst clock (the provider lists one per blocking clock).
    final alertByItem = {for (final a in alerts) a.item.id: a};
    final marginByItem = {for (final m in margins) m.item.id: m};
    // An owned cylinder on the board is listed under Cylinders only.
    final slotted = {
      for (final s in states)
        if (s.cylinder.equipmentId != null) s.cylinder.equipmentId!,
    };
    final packed = [for (final i in gear) if (!slotted.contains(i.id)) i];

    Future<void> add() => showTripGearAddSheet(
      context,
      trip: trip,
      packed: gear,
      slots: [for (final s in states) s.cylinder],
    );
    void openBoard() => context.push('/trips/${trip.id}/cylinders');

    if (packed.isEmpty && states.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                upcoming
                    ? l10n.trips_gear_empty_upcoming
                    : l10n.trips_gear_empty_past,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (upcoming) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  key: const Key('trip-gear-add'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.trips_gear_add_action),
                  onPressed: add,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (upcoming)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                key: const Key('trip-gear-add'),
                icon: const Icon(Icons.add),
                label: Text(l10n.trips_gear_add_action),
                onPressed: add,
              ),
            ),
          ),
        if (packed.isNotEmpty) ...[
          _SectionHeader(title: l10n.trips_gear_section_packed),
          for (final item in packed)
            TripPackedItemRow(
              item: item,
              alert: alertByItem[item.id],
              margin: marginByItem[item.id],
              onUnpack: () => _unpack(context, ref, item.id),
            ),
        ],
        if (states.isNotEmpty) ...[
          _SectionHeader(
            title: l10n.trips_gear_section_cylinders,
            action: started
                ? TextButton(
                    onPressed: openBoard,
                    child: Text(l10n.trips_gear_openBoard),
                  )
                : null,
          ),
          if (trip.isInProgress && forecast != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TripFillForecastText(forecast: forecast, units: units),
            ),
          for (final s in states)
            TripCylinderSlotRow(
              state: s,
              started: started,
              units: units,
              onTap: openBoard,
            ),
        ],
      ],
    );
  }

  Future<void> _unpack(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(tripEquipmentRepositoryProvider).unpack(trip.id, id);
    } catch (e, stackTrace) {
      _log.error('Failed to unpack', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(SnackBar(content: Text(l10n.trips_gear_failed)));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
```

(`?action` is the null-aware collection element the codebase already uses in `trip_gear_alerts_panel.dart:70`.)

- [ ] **Step 10: Run the Gear tab tests**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/gear/trip_gear_tab_test.dart`
Expected: PASS.

- [ ] **Step 11: Write the failing summary card tests, then the card**

Create `test/features/trips/presentation/widgets/trip_cylinders_summary_card_test.dart`, copying the harness of `test/features/trips/presentation/widgets/trip_cylinders_card_test.dart` (its `slots`, `shortForecast`, settings and provider overrides; that file is deleted in Task 8), pumping `TripCylindersSummaryCard(trip: ...)` inside a `GoRouter` whose `/trips/:id/cylinders` route records the push:

```dart
  testWidgets('a trip in progress with slots shows the counts and forecast', (
    tester,
  ) async {
    await pump(tester, trip: inProgress(), slots: [full('a'), empty('b')]);
    expect(find.text('Full 1 · Partial 0 · Empty 1'), findsOneWidget);
    expect(find.byKey(const Key('trip-cylinders-forecast')), findsOneWidget);
  });

  testWidgets('tapping it opens the board', (tester) async {
    final pushed = await pump(tester, trip: inProgress(), slots: [full('a')]);
    await tester.tap(find.byKey(const Key('trip-cylinders-summary')));
    await tester.pumpAndSettle();
    expect(pushed, ['/trips/t1/cylinders']);
  });

  testWidgets('an upcoming trip shows nothing', (tester) async {
    await pump(tester, trip: upcoming(), slots: [full('a')]);
    expect(find.byKey(const Key('trip-cylinders-summary')), findsNothing);
  });

  testWidgets('a trip in progress with no slots shows nothing', (tester) async {
    await pump(tester, trip: inProgress(), slots: const []);
    expect(find.byKey(const Key('trip-cylinders-summary')), findsNothing);
  });

  testWidgets('a past trip shows nothing', (tester) async {
    await pump(tester, trip: past(), slots: [full('a')]);
    expect(find.byKey(const Key('trip-cylinders-summary')), findsNothing);
  });
```

Create `lib/features/trips/presentation/widgets/trip_cylinders_summary_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The story's cylinders line while a trip is under way (#2845): the full,
/// partial and empty counts and the fill forecast, opening the board. Shows
/// nothing before departure, after the trip, or with no slots.
class TripCylindersSummaryCard extends ConsumerWidget {
  final Trip trip;

  const TripCylindersSummaryCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!trip.isInProgress) return const SizedBox.shrink();
    final states = ref.watch(tripCylinderStatesProvider(trip.id)).value;
    if (states == null || states.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final forecast = ref.watch(tripFillForecastProvider(trip.id)).value;
    final counts = tripCylinderCounts(states);
    final summary = l10n.trips_cylinders_summary(
      counts.full,
      counts.partial,
      counts.empty,
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('trip-cylinders-summary'),
        onTap: () => context.push('/trips/${trip.id}/cylinders'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(MdiIcons.divingScubaTank, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      counts.unknown == 0
                          ? summary
                          : '$summary · '
                                '${l10n.trips_cylinders_summaryUnfilled(counts.unknown)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (forecast != null) ...[
                      const SizedBox(height: 4),
                      TripFillForecastText(
                        key: const Key('trip-cylinders-forecast'),
                        forecast: forecast,
                        units: units,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
```

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/trip_cylinders_summary_card_test.dart`
Expected: PASS.

- [ ] **Step 12: Format, analyze, guards, commit**

Run `dart format .`, `flutter analyze`, `TMPDIR=$SCR/tmp flutter test test/architecture/ test/features/trips/presentation/widgets/cylinders/ test/features/trips/presentation/widgets/trip_gear_card_test.dart test/features/trips/presentation/widgets/trip_cylinders_card_test.dart test/l10n/arb_parity_test.dart` (the old card tests still pass; their widgets are untouched until Task 8).

```bash
git add lib/features/trips/domain/services/trip_cylinder_drafts.dart lib/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart lib/features/trips/presentation/widgets/trip_service_alert_list.dart lib/features/trips/presentation/widgets/trip_scrubber_margin_details.dart lib/features/trips/presentation/widgets/gear lib/features/trips/presentation/widgets/trip_cylinders_summary_card.dart lib/l10n/arb test/features/trips/domain/services/trip_cylinder_drafts_test.dart test/features/trips/presentation/widgets/gear test/features/trips/presentation/widgets/trip_cylinders_summary_card_test.dart
git commit -m "feat(trips): Gear tab with packed gear and cylinders in one list"
```

---
### Task 7: Six tabs on every trip, the story as one scroll

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_detail_tabs.dart` (add the widget)
- Create: `lib/features/trips/presentation/widgets/trip_dives_tab.dart`
- Create: `lib/features/trips/presentation/widgets/trip_photos_tab.dart`
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (one layout)
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart` (flatten)
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_hero.dart` (drop Generate)
- Test: `test/features/trips/presentation/pages/trip_detail_page_test.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`
- Test: `test/features/trips/presentation/pages/trip_detail_checklist_test.dart`

**Interfaces:**
- Consumes: everything Tasks 2 to 6 produced; `TripChecklistSection`, `showStartSessionSheet`, `TripPhotoSection`, `showTripDayMapPage`, `TripCylindersSummaryCard`.
- Produces: `TripDetailTabs({required TripWithStats tripWithStats})`; `TripDivesTab({required String tripId})`; `TripPhotosTab({required String tripId})`; `TripStoryView` with no band, passing `mapPoints` and `onExpandMap` to each day card.

- [ ] **Step 1: Write the failing page tests**

In `test/features/trips/presentation/pages/trip_detail_page_test.dart`, inside `group('TripDetailPage', ...)`, add (reusing the file's `testTrip`, `testTripWithStats`, mocks and `_setMobileTestSurfaceSize`; add the Task 5 `prepareOverrides()`-style stubs for `tripChecklistProvider`, `tripGearProvider`, `tripCylinderStatesProvider`, `tripServiceAlertsProvider`, `tripScrubberMarginsProvider`, `tripFillForecastProvider`, `itineraryDaysProvider`, `divesForTripProvider`, each returning an empty value for `testTrip.id`, as a file-level `List<Override> tabOverrides(String tripId)` helper):

```dart
    for (final type in TripType.values) {
      testWidgets('a $type trip shows the six tabs in order', (tester) async {
        _setMobileTestSurfaceSize(tester);
        final trip = testTrip.copyWith(tripType: type);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tripWithStatsProvider(trip.id).overrideWith(
                (ref) async => TripWithStats(trip: trip, diveCount: 0),
              ),
              diveIdsForTripProvider(trip.id).overrideWith((ref) async => []),
              tripListNotifierProvider.overrideWith(
                (ref) => _MockTripListNotifier([]),
              ),
              settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
              ...tabOverrides(trip.id),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TripDetailPage(tripId: trip.id),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tabs = tester
            .widgetList<Tab>(find.byType(Tab))
            .map((t) => t.text)
            .toList();
        expect(tabs, [
          'Overview',
          'Itinerary',
          'Gear',
          'Checklist',
          'Dives',
          'Photos',
        ]);
        expect(find.byType(TripHeaderCards), findsNothing);
      });
    }

    testWidgets('the Gear tab holds the gear list', (tester) async {
      // same pump as above with testTrip
      await tester.tap(find.widgetWithText(Tab, 'Gear'));
      await tester.pumpAndSettle();
      expect(find.byType(TripGearTab), findsOneWidget);
    });

    testWidgets('the Checklist tab offers the pre-dive checklist', (
      tester,
    ) async {
      // same pump as above with testTrip
      await tester.tap(find.widgetWithText(Tab, 'Checklist'));
      await tester.pumpAndSettle();
      expect(find.text('Pre-dive checklist'), findsOneWidget);
      expect(find.byType(TripChecklistSection), findsOneWidget);
    });
```

Add imports for `TripHeaderCards` (deleted in Task 8; drop that assertion then), `TripGearTab`, `TripChecklistSection`, `TripType`. The existing tests that build a liveaboard to reach the Dives tab (`'liveaboard dives tab shows runtime'`, the `'dives section edge cases'` group, `'renders embedded header for liveaboard trip'`) keep their liveaboard fixtures and keep passing; add `...tabOverrides(id)` to each pump that now renders the Gear and Overview tabs' providers. The `'overview renders the trip story day chapters'` test dates the trip in 2024, so the Overview is the story; keep it.

In `test/features/trips/presentation/pages/trip_detail_checklist_test.dart`, the `'liveaboard trip shows a Checklist tab'` test still passes; duplicate it as `'a shore trip shows a Checklist tab'` with `tripType: TripType.shore`.

- [ ] **Step 2: Write the failing story view tests**

In `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`:

Delete these tests outright (they test the band, the docked day or the trailing checklist, none of which survives): `'one band serves every width'`, `'the band parks at the docked extent'`, `'scrolling resolves the active day and animates the map'`, `'the band names the day whose heading last crossed the line'`, `'the band switches a third of the way below itself'`, `'the last day docks once the story is scrolled to the end'`, `'a last chapter taller than the screen still docks its own day'`, `'the band catches up when a scroll comes to rest'`, `'tapping the docked day scrolls its chapter back into view'`, `'the docked day sits at the start edge in both directions'`, `'large text does not overflow the docked panel'`, `'text past the floor grows the band rather than clipping it'`, `'a subtitled day at 3x text does not clip the docked panel'`, `'tapping the docked day clears the chapter of the band'`, `'a trip with no mappable points still renders the band'`, `'the docked day carries its stored weather into the band'`, `'checklist and notes closers share the section title style'`, and the whole checklist `group` at the end (`'upcoming trip with an empty checklist can still bootstrap ...'` through `'liveaboard trips keep the closer out of the story'`). Delete the `_headingTop` and `_dockedDayNumber` helpers and the band, docked-day and map-header imports.

Keep: `'past trip renders day chapters, hero, and stat strip'`, `'in-progress trip shows a Today divider'`, `'liveaboard trip includes the vessel section'`, `'the story fills a wide window rather than sitting in gutters'`, `'stat strip scrolls away in the narrow layout'` (now true at every width: rename it `'the stat strip scrolls away'` and drop any width branch), `'surface days get the same sticky header as dive days'` (rename `'surface days get the same header as dive days'`), `'the surface day renders stored weather'`, `'a day with nothing stored renders no weather badge'`.

Add:

```dart
  testWidgets('the story is one scroll with no pinned band', (tester) async {
    final trip = _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 9));
    final story = _story(
      trip,
      dives: [_diveAt('d1', DateTime(2026, 3, 8, 9), 12.1, -68.2)],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(390, 844));
    expect(find.byType(SliverPersistentHeader), findsNothing);
    expect(find.byType(TripStoryHero), findsOneWidget);
    // One map, inside the day with a located dive.
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TripChecklistSection), findsNothing);
  });

  testWidgets('each day card gets only its own points', (tester) async {
    final trip = _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 9));
    final story = _story(
      trip,
      dives: [
        _diveAt('d1', DateTime(2026, 3, 7, 9), 12.1, -68.2),
        _diveAt('d2', DateTime(2026, 3, 8, 9), 12.2, -68.3),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story);
    final cards = tester.widgetList<TripStoryDayCard>(
      find.byType(TripStoryDayCard),
    );
    final byDay = {for (final c in cards) c.day.dayNumber: c.mapPoints};
    expect(byDay[1]!.map((p) => p.diveId), ['d1']);
    expect(byDay[2]!.map((p) => p.diveId), ['d2']);
    expect(byDay[3], isEmpty);
  });

  testWidgets('expanding a day map opens the fullscreen page', (tester) async {
    final trip = _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 7));
    final story = _story(
      trip,
      dives: [_diveAt('d1', DateTime(2026, 3, 7, 9), 12.1, -68.2)],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story);
    await tester.tap(find.byKey(const Key('day-map-expand')));
    await tester.pumpAndSettle();
    expect(find.byType(TripDayMapPage), findsOneWidget);
    expect(find.text('Day 1 · Mar 7'), findsOneWidget);
  });

  testWidgets('a trip in progress with slots shows the cylinders summary', (
    tester,
  ) async {
    final now = DateTime.now();
    final trip = _trip(
      start: DateTime(now.year, now.month, now.day - 1),
      end: DateTime(now.year, now.month, now.day + 3),
    );
    await pumpView(
      tester,
      _story(trip, today: now),
      extra: [
        tripCylinderStatesProvider('trip-1').overrideWith(
          (ref) async => [
            foldCylinderState(
              cylinder: TripCylinder(
                id: 'c1',
                tripId: 'trip-1',
                label: 'Truck 1',
                createdAt: now,
                updatedAt: now,
              ),
              events: const [],
              uses: const [],
            ),
          ],
        ),
        tripFillForecastProvider('trip-1').overrideWith((ref) async => null),
      ],
    );
    expect(find.byKey(const Key('trip-cylinders-summary')), findsOneWidget);
  });
```

Add the imports those need (`flutter_map`, `TripChecklistSection`, `TripDayMapPage`, `TripStoryDayCard`, `TripCylinder`, `foldCylinderState`, the two cylinder providers). `pumpView` must also stub `tripCylinderStatesProvider('trip-1')` with an empty list by default so the summary card's provider never touches the database in the other tests.

In `test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`, delete `'planned liveaboard shows countdown, checklist, generate CTA'`'s Generate assertions (keep the countdown and checklist ones), and delete `'planned shore trip hides the generate itinerary CTA'`, `'tapping Generate itinerary saves generated days'`, `'a failed Generate itinerary says so without the exception'` and `'a partial itinerary still offers Generate, which adds only ...'`, plus their `_RecordingRepo`-style helpers and the repository imports if nothing else uses them. Add:

```dart
  testWidgets('the hero never offers itinerary generation', (tester) async {
    final trip = _trip(
      start: _daysFrom(DateTime.now(), 12),
      end: _daysFrom(DateTime.now(), 19),
      tripType: TripType.liveaboard,
    );
    await pumpHero(tester, _story(trip));
    expect(find.text('Generate itinerary'), findsNothing);
  });
```

- [ ] **Step 3: Run them to see them fail**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/pages/trip_detail_page_test.dart test/features/trips/presentation/widgets/story/trip_story_view_test.dart test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`
Expected: compile errors (`TripDetailTabs`, `TripGearTab` imports) and failures (Generate still offered, band present).

- [ ] **Step 4: Extract the Dives and Photos tabs**

Create `lib/features/trips/presentation/widgets/trip_photos_tab.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/trips/presentation/widgets/trip_photo_section.dart';

/// The Photos tab: the trip's photo section on its own scroll.
class TripPhotosTab extends StatelessWidget {
  final String tripId;

  const TripPhotosTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TripPhotoSection(tripId: tripId),
    );
  }
}
```

Create `lib/features/trips/presentation/widgets/trip_dives_tab.dart` holding `class TripDivesTab extends ConsumerWidget` whose `build` is the body of `_TripDetailContent._buildDivesTab` moved verbatim (`trip.id` becomes `tripId`; the imports it needs are `dive_providers.dart`, `settings_providers.dart`, `unit_formatter.dart`, `go_router`, `l10n_extension.dart`). Delete `_buildDivesTab` and `_buildPhotosTab` from the page.

- [ ] **Step 5: The tab widget**

Append to `lib/features/trips/presentation/widgets/trip_detail_tabs.dart`:

```dart
/// The trip page's body (#2845): one scrolling tab row and six views, the
/// same for every trip type and width.
class TripDetailTabs extends StatelessWidget {
  final TripWithStats tripWithStats;

  const TripDetailTabs({super.key, required this.tripWithStats});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trip = tripWithStats.trip;
    return DefaultTabController(
      length: TripDetailTab.values.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l10n.trips_detail_tab_overview),
                Tab(text: l10n.trips_detail_tab_itinerary),
                Tab(text: l10n.trips_detail_tab_gear),
                Tab(text: l10n.trips_detail_tab_checklist),
                Tab(text: l10n.trips_detail_tab_dives),
                Tab(text: l10n.trips_detail_tab_photos),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                TripOverviewTab(tripWithStats: tripWithStats),
                TripItineraryTab(tripId: trip.id),
                TripGearTab(trip: trip),
                _ChecklistTab(trip: trip),
                TripDivesTab(tripId: trip.id),
                TripPhotosTab(tripId: trip.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The pre-dive checklist button over the trip's to-do list, as the
/// liveaboard tab had it.
class _ChecklistTab extends StatelessWidget {
  final Trip trip;

  const _ChecklistTab({required this.trip});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.fact_check),
              label: Text(context.l10n.trips_detail_preDive_action),
              onPressed: () => showStartSessionSheet(context, tripId: trip.id),
            ),
          ),
          const SizedBox(height: 12),
          TripChecklistSection(trip: trip),
        ],
      ),
    );
  }
}
```

with the imports: `flutter/material.dart`, `trip_checklist_section.dart`, `start_session_sheet.dart`, `trip.dart` (for `Trip` and `TripWithStats`; check where `TripWithStats` lives, `trip_providers.dart` in the old page's imports), `trip_dives_tab.dart`, `trip_photos_tab.dart`, `trip_gear_tab.dart`, `trip_itinerary_tab.dart`, `trip_overview_tab.dart`, `l10n_extension.dart`. `TripOverviewTab`'s `onOpenTab` is left null so the summary card drives `DefaultTabController.of(context)`.

- [ ] **Step 6: One layout in the page**

In `trip_detail_page.dart`, replace `_TripDetailContent.build`, `_buildStandardLayout` and `_buildLiveaboardLayout` with:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = tripWithStats.trip;
    final body = Column(
      children: [
        SharedByBanner(
          kind: SharedItemKind.trip,
          itemId: trip.id,
          ownerId: trip.diverId,
          isShared: trip.isShared,
        ),
        Expanded(child: TripDetailTabs(tripWithStats: tripWithStats)),
      ],
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, trip),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: _buildAppBarActions(context, ref, trip),
      ),
      body: body,
    );
  }
```

Delete `_headerCards` and the imports of `trip_gear_alerts_panel.dart`, `trip_cylinders_card.dart`, `trip_gear_card.dart`, `trip_header_cards.dart`, `trip_itinerary_tab.dart`, `trip_overview_tab.dart`, `trip_photo_section.dart`, `trip_checklist_section.dart`, `start_session_sheet.dart`; add `trip_detail_tabs.dart`. Remove any now-unused imports `flutter analyze` reports.

- [ ] **Step 7: Flatten the story view**

In `trip_story_view.dart`:

- Remove the imports of `flutter/scheduler.dart`, `flutter_map`, `latlong2`, `trip_checklist_section.dart`, `trip_story_band.dart`, `trip_story_band_extents.dart`, `trip_story_map_header.dart`; add `trip_cylinders_summary_card.dart`, `trip_day_map_page.dart`.
- Delete `_scrollThrottle`, the `TickerProviderStateMixin`, `_mapController`, `_cameraAnimator`, `_dayKeys`, `_activeDayIndex`, `_lastResolve`, `initState`, `didUpdateWidget`, `_buildKeys`, `dispose`, `_selectDay`, `_onPinSelected`, `_scrollToDay`, `_onScroll`, `_resolveDockedDay`, `_headingTop`, `_bandExtents`.
- `build` becomes:

```dart
  @override
  Widget build(BuildContext context) {
    final tripId = widget.story.trip.id;
    // One read for the whole story, shared by every chapter heading.
    final storedWeather =
        ref.watch(tripDayWeatherProvider(tripId)).asData?.value ??
        const <int, TripDayWeather>{};
    // Fire and forget: the backfill's writes come back through the provider
    // above via the table tick, so a row landing re-renders its day header.
    ref.watch(tripDayWeatherBackfillProvider(tripId));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TripStatStrip(stats: widget.stats, siteCount: _siteCount),
        ),
        ..._contentSlivers(storedWeather),
      ],
    );
  }
```

  The hero stays first inside `_contentSlivers`; move the stat strip sliver to sit after the hero's sliver so the order is hero, stat strip, cylinders summary, flight countdown, vessel, chapters, notes.
- In `_contentSlivers`, delete `showChecklistAtEnd`, `openChecklist` and the whole `if (showChecklistAtEnd) SliverPadding(...)` closer, and add after the hero's sliver:

```dart
      SliverToBoxAdapter(
        child: TripStatStrip(stats: widget.stats, siteCount: _siteCount),
      ),
      SliverToBoxAdapter(child: TripCylindersSummaryCard(trip: trip)),
```

- In `_daySliver`, the heading loses its `KeyedSubtree` (no `_dayKeys` any more) and the body passes the day's points and the expand handler:

```dart
    final heading = SliverToBoxAdapter(
      child: TripStoryDayHeader(
        day: day,
        storedWeather: stored?.toStoryWeather(),
      ),
    );
    final body = SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TripStoryDayCard(
              day: day,
              tripId: story.trip.id,
              mapPoints: story.mapGeometry.pointsForDay(index),
              onExpandMap: (day, points) =>
                  showTripDayMapPage(context, day: day, points: points),
            ),
          ],
        ),
      ),
    );
```

  Rewrite the comments above them: the heading is ordinary content and carries no key; the card gets the day's own points (#2845).
- Update the class doc: "The assembled trip story: hero, stat strip, the cylinders line while under way, and one chapter per day, each with its own map."

In `trip_story_hero.dart`, delete `_GenerateItineraryButton`, its state, the `coversTrip` computation and the `if (trip.isLiveaboard && trip.isUpcoming && !coversTrip) ...[` block, and the imports of `logger_service.dart`, `itinerary_day.dart`, `trip_dive_days.dart`, `liveaboard_providers.dart`, `trip_story_providers.dart` and the `_log` constant if nothing else in the file uses them.

- [ ] **Step 8: Run the tests, format, analyze, guards**

Run: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/pages/ test/features/trips/presentation/widgets/story/ test/features/trips/presentation/widgets/trip_overview_tab_test.dart test/features/trips/presentation/widgets/overview/ test/features/trips/presentation/widgets/gear/ test/features/checklists/`
Expected: PASS. Then `dart format .`, `flutter analyze`, `TMPDIR=$SCR/tmp flutter test test/architecture/`.

- [ ] **Step 9: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_detail_tabs.dart lib/features/trips/presentation/widgets/trip_dives_tab.dart lib/features/trips/presentation/widgets/trip_photos_tab.dart lib/features/trips/presentation/pages/trip_detail_page.dart lib/features/trips/presentation/widgets/story/trip_story_view.dart lib/features/trips/presentation/widgets/story/trip_story_hero.dart test/features/trips/presentation/pages/trip_detail_page_test.dart test/features/trips/presentation/pages/trip_detail_checklist_test.dart test/features/trips/presentation/widgets/story/trip_story_view_test.dart test/features/trips/presentation/widgets/story/trip_story_hero_test.dart
git commit -m "feat(trips): six tabs on every trip, the story as one scroll"
```

---

### Task 8: Remove what nothing uses

**Files:**
- Delete: `lib/features/trips/presentation/widgets/trip_header_cards.dart`, `trip_gear_alerts_panel.dart`, `trip_cylinders_card.dart`, `trip_gear_card.dart`, `story/trip_story_band.dart`, `story/trip_story_band_extents.dart`, `story/trip_story_docked_day.dart`, `story/trip_story_map_header.dart`
- Delete: `test/features/trips/presentation/widgets/trip_header_cards_test.dart`, `trip_gear_alerts_panel_test.dart`, `trip_cylinders_card_test.dart`, `trip_gear_card_test.dart`, `story/trip_story_band_test.dart`, `story/trip_story_band_extents_test.dart`, `story/trip_story_docked_day_test.dart`, `story/trip_story_map_header_test.dart`
- Create: `test/features/trips/presentation/widgets/story/trip_stat_strip_test.dart` (the stat strip tests move here)
- Modify: all 11 ARB files (orphaned keys removed)

- [ ] **Step 1: Move the stat strip tests**

`trip_story_map_header_test.dart` holds five `'stat strip ...'` tests (lines 287-345) and the `pumpStrip` helper. Create `test/features/trips/presentation/widgets/story/trip_stat_strip_test.dart` with those tests and helper verbatim (imports: `flutter/material.dart`, `flutter_test`, `core/providers/provider.dart`, `trip.dart`, `trip_stat_strip.dart`, `app_localizations.dart`, `mock_providers.dart`). Run it: `TMPDIR=$SCR/tmp flutter test test/features/trips/presentation/widgets/story/trip_stat_strip_test.dart`. Expected: PASS.

- [ ] **Step 2: Delete the files**

```bash
git rm lib/features/trips/presentation/widgets/trip_header_cards.dart lib/features/trips/presentation/widgets/trip_gear_alerts_panel.dart lib/features/trips/presentation/widgets/trip_cylinders_card.dart lib/features/trips/presentation/widgets/trip_gear_card.dart lib/features/trips/presentation/widgets/story/trip_story_band.dart lib/features/trips/presentation/widgets/story/trip_story_band_extents.dart lib/features/trips/presentation/widgets/story/trip_story_docked_day.dart lib/features/trips/presentation/widgets/story/trip_story_map_header.dart test/features/trips/presentation/widgets/trip_header_cards_test.dart test/features/trips/presentation/widgets/trip_gear_alerts_panel_test.dart test/features/trips/presentation/widgets/trip_cylinders_card_test.dart test/features/trips/presentation/widgets/trip_gear_card_test.dart test/features/trips/presentation/widgets/story/trip_story_band_test.dart test/features/trips/presentation/widgets/story/trip_story_band_extents_test.dart test/features/trips/presentation/widgets/story/trip_story_docked_day_test.dart test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart
```

Then `flutter analyze`: it must report zero issues. If anything still imports a deleted file (`grep -rn "trip_story_band\|trip_story_docked_day\|trip_story_map_header\|trip_header_cards\|trip_gear_alerts_panel\|trip_cylinders_card.dart\|trip_gear_card.dart" lib test`), fix the importer, never restore the file. Drop the `TripHeaderCards` assertion and import added in Task 7's page test.

- [ ] **Step 3: Remove the orphaned ARB keys**

Write `$SCR/orphan_keys.py` and run it with `python3.14` from the worktree: for each candidate key below, count files under `lib/` (excluding `lib/l10n/`) containing `l10n.<key>` or `.<key>(`; print the count; for every key with zero uses, remove the `"<key>": ...` line and any `"@<key>": ...` line (which may span several lines; parse each ARB as JSON, delete the two entries, and write it back with `json.dump(..., ensure_ascii=False, indent=2)` ONLY if the project's ARB files are already 2-space JSON that round-trips byte-identical on an untouched key, else edit the lines textually). Candidates: `trips_story_dockedDay_goToDay`, `trips_story_map_semantics`, `trips_gearAlerts_count`, `trips_scrubber_bannerCount`, `trips_scrubber_title`, `trips_gear_title`, `trips_gear_none`, `trips_gear_add`, `trips_gear_useSet`, `trips_cylinders_setUp`, `trips_cylinders_setUpHint`, `trips_itinerary_noDives`. `trips_serviceAlert_count` stays (the upcoming trip banner uses it). Check `git diff --stat lib/l10n/arb` touches exactly 11 ARB files and nothing is reordered (`git diff lib/l10n/arb/app_en.arb` shows only removed lines). Run `flutter gen-l10n`.

- [ ] **Step 4: Run the guards and the affected suites**

Run: `dart format .`, `flutter analyze`, then `TMPDIR=$SCR/tmp flutter test test/architecture/ test/l10n/ test/features/trips/ test/features/checklists/ test/features/equipment/presentation/ test/features/cylinder_passports/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -u lib/features/trips/presentation/widgets lib/l10n/arb test/features/trips/presentation/widgets test/features/trips/presentation/pages/trip_detail_page_test.dart
git add test/features/trips/presentation/widgets/story/trip_stat_strip_test.dart
git commit -m "refactor(trips): remove the header cards, the story band and their strings"
```

(`git add -u <paths>` stages the deletions and edits under those paths only; `git show --stat HEAD` must list the 16 deletions, the new test and 11 ARB files plus the generated localizations.)

---

### Task 9: Docs, screenshots, final checks

**Files:**
- Modify: `docs/features/trips.md:210-228` ("Planning Future Trips")
- Scratchpad: `$SCR/shots/*.png`

- [ ] **Step 1: Rewrite the user doc section**

Replace the "Planning Future Trips" section (from `## Planning Future Trips` to just before `## Trip Best Practices`) with:

```markdown
## Planning Future Trips

Every trip, whatever its type, has the same six tabs: Overview, Itinerary,
Gear, Checklist, Dives and Photos.

### Before departure

Until the first day the Overview is a preparation page: the countdown, then
one card with a row for each thing to get ready (to-dos, gear, itinerary,
plan), each opening its tab, and your notes.

### Itinerary

Generate fills the trip's dates with a travel day at each end and dive days
between (embark and disembark on a liveaboard). Tap a day to set its type
(Travel, Dive day, Rest; plus Embark, Disembark, Sea day and Port day on a
boat), its location, notes and the number of dives you plan that day, which
the cylinder forecast uses. A day planned at no dives is a rest day.

### Gear

One list of what you'll dive with: the gear you pack from your equipment
(service clocks falling due before the trip show on the item) and the
cylinders you'll hold, rental or your own. Add offers all three ways in. Once
the trip starts, the cylinders show their fill state and open the board.

### Checklist

Your to-dos for the trip, with templates, and the pre-dive checklist runs.

### During and after the trip

From the first day the Overview tells the story: a card per day with its own
map of that day's dives (tap a pin to find the dive, or open the map
fullscreen), the day's dives, photos and sightings. While the trip is under
way a cylinders line sits under the heading.
```

- [ ] **Step 2: After screenshots**

Adapt the throwaway harness at `test/tmp_shots/planned_trip_before_test.dart` (untracked; it already loads real fonts, the icon fonts and the app theme) so it pumps the new page: add `debugShowCheckedModeBanner: false`, stub `itineraryDaysProvider`, `tripScrubberMarginsProvider` and `divesForTripProvider` as it already stubs the others, and capture, at phone (390x844) and desktop (1100x800, `embedded: true`), light and dark:

- `02-overview-prepare-after[-dark][-desktop].png`: the Overview 12 days out.
- `03-gear-tab-after[-dark].png`: after `tester.tap(find.widgetWithText(Tab, 'Gear'))` and `pumpAndSettle`.
- `04-itinerary-tab-after.png`: the Itinerary tab with generated days (override `itineraryDaysProvider` with `ItineraryDay.generateForTrip(..., tripType: TripType.resort)`).
- `05-story-day-map-after.png`: a trip dated in the past with two dives at located sites on one day (override `tripStoryProvider` with a story built from such dives), scrolled to the first chapter; the FlutterMap tiles render only if the harness lets the tile fetch through, so set `HttpOverrides.global = null` in `setUpAll` and loop `runAsync` + `pump` as the widget-screenshot memory describes; a blank map background is acceptable if tiles stay offline, the pins are the point.

Run the harness with `--update-goldens` and `--dart-define=SHOT_DIR=$SCR/shots`. Copy nothing into the repo. Delete `test/tmp_shots/` afterwards so it cannot be staged.

- [ ] **Step 3: Send the screenshots**

One `SendUserFile` call with every PNG under `$SCR/shots` (`display: attach`), captioned that they go in the PR's Screenshots section, before and after.

- [ ] **Step 4: Final checks**

`dart format .`, `flutter analyze`, `TMPDIR=$SCR/tmp flutter test test/architecture/`, then one run of the affected suites: `TMPDIR=$SCR/tmp flutter test test/features/trips/ test/features/checklists/ test/features/equipment/presentation/ test/features/cylinder_passports/ test/features/dive_log/presentation/widgets/dive_list_item_test.dart test/l10n/`. Expected: PASS. `git status` must show only the doc change (and no `test/tmp_shots/`).

- [ ] **Step 5: Commit**

```bash
git add docs/features/trips.md
git commit -m "docs(trips): describe the planned trip page"
```

Then the build-feature workflow continues at step 5 (push, open the PR with `Closes #2845` and `Closes #2658`, the spec and plan links, and the screenshot list).

---

## Self-review notes

- Spec coverage: page structure and phases (Tasks 5, 7); Prepare mode (5); Story mode, day map, pin-to-row, fullscreen, shared animator (3, 4, 7, 8); Gear tab, Add, rows, empty states (6); Itinerary day types, Generate, sheet, list, #2658 (1, 2); Checklist, Dives, Photos tabs, desktop (7); removals (8); localization (each task); testing (each task); docs and screenshots (9). Shared trips: no task changes any permission path, as the spec requires.
- Deviations recorded as rulings: R1 to R6 above. R6 (keep `nearestPointForDay`) and the summary rows' subtitle placement (R3) correct two spec lines.
- Types: `TripDetailTab` is created in Task 5 and consumed in Tasks 5 and 7; `tripCylinderDraftFromEquipment` and `nextTripCylinderSortOrder` are created in Task 6 and consumed there; `showTripDayMapPage` is created in Task 4 and consumed in Task 7; `TripStoryDayCard.mapPoints`/`onExpandMap` are created in Task 3 and consumed in Task 7; `showAddTripCylindersSheet(rentalOnly:)` is created and consumed in Task 6; `tripServiceAlertSubtitle` and `tripScrubberMarginMinutes` are created and consumed in Task 6.
- Review Focus: 1 in Task 5 (`'a trip starting today shows the story'`), 2 in Task 3 (`'same-site dives get distinct pins'`), 3 in Task 2 (`'a sea day on a resort trip keeps its type'`), 4 in Task 6 (`'an owned cylinder is listed once'`), 5 in Task 1 (`'a one-day resort trip is a single dive day'`).
