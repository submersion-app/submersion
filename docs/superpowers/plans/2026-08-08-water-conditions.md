# Water Conditions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reframe the coral-specific "Reef health" presentation as general
"Water conditions" for all ocean sites, skip the NOAA fetch for freshwater
sites (closing the coastal-pixel leak), and retitle the site section
"Ecosystem" — per `docs/superpowers/specs/2026-08-08-water-conditions-design.md`.

**Architecture:** Presentation-layer only. Services, domain entities, cache
schema, and cached rows are untouched. Changes: one new method and one new
parameter on `ReefRepository`, a rekeyed provider family plus one new provider,
a renamed card widget with gating logic, section/call-site updates on two
pages, a `convertDelta` on `TemperatureUnit`, and l10n strings in all 11
locales.

**Tech Stack:** Flutter 3 / Material 3, Riverpod (legacy providers via
`core/providers/provider.dart`), Drift local-cache DB, `http` MockClient tests,
`flutter_test` widget tests with `localizedMaterialApp` helper.

## Global Constraints

- Work in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/water-conditions` on branch `worktree-water-conditions`. Bash working directory can reset to the main checkout between calls — run `pwd` first and `cd` back to the worktree if needed. Never touch the main checkout.
- All Dart code must pass `dart format` with no changes (format the whole project, not just changed files).
- `flutter analyze` must be clean — infos are fatal in CI.
- No emojis anywhere. No console prints. Immutability throughout.
- Every user-visible string goes through l10n; every new/changed key lands in ALL 11 ARBs: `app_en`, `app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`.
- Anything displaying units respects the active diver's unit settings.
- TDD: write the failing test first in every task. Commit after each task (commits are preauthorized). No Co-Authored-By lines in commit messages.
- `flutter test` invocations: give long-running suite steps a generous timeout (10 minutes).
- The `dives`/reef cache schemas are NOT modified in this plan. If a step seems to require a schema change, stop — it's a plan misreading.

---

### Task 1: `TemperatureUnit.convertDelta`

**Files:**
- Modify: `lib/core/constants/units.dart` (TemperatureUnit enum, ends line 32)
- Test: `test/core/constants/units_test.dart` (create if absent; append a group if present)

**Interfaces:**
- Produces: `double TemperatureUnit.convertDelta(double value, TemperatureUnit to)` — converts a temperature *difference* (scale only, no +32 offset). Used by Task 5.

- [ ] **Step 1: Write the failing test**

If `test/core/constants/units_test.dart` does not exist, create it with this content; if it exists, add only the group inside `main()`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';

void main() {
  group('TemperatureUnit.convertDelta', () {
    test('scales celsius deltas to fahrenheit without the offset', () {
      expect(
        TemperatureUnit.celsius.convertDelta(0.5, TemperatureUnit.fahrenheit),
        closeTo(0.9, 1e-9),
      );
      expect(
        TemperatureUnit.celsius.convertDelta(-1.0, TemperatureUnit.fahrenheit),
        closeTo(-1.8, 1e-9),
      );
    });

    test('is identity for same-unit conversion', () {
      expect(
        TemperatureUnit.celsius.convertDelta(0.7, TemperatureUnit.celsius),
        closeTo(0.7, 1e-9),
      );
    });

    test('scales fahrenheit deltas back to celsius', () {
      expect(
        TemperatureUnit.fahrenheit.convertDelta(1.8, TemperatureUnit.celsius),
        closeTo(1.0, 1e-9),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/units_test.dart`
Expected: FAIL — `convertDelta` is not defined.

- [ ] **Step 3: Implement**

In `lib/core/constants/units.dart`, inside `enum TemperatureUnit` after the existing `convert` method:

```dart
  /// Converts a temperature difference between units.
  ///
  /// Deltas scale but never take the Fahrenheit offset: a +0.5 C anomaly is
  /// +0.9 F, not +32.9 F.
  double convertDelta(double value, TemperatureUnit to) {
    if (this == to) return value;
    if (this == celsius && to == fahrenheit) return value * 9 / 5;
    return value * 5 / 9;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/constants/units_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/units.dart test/core/constants/units_test.dart
git commit -m "Add TemperatureUnit.convertDelta for temperature differences"
```

---

### Task 2: Repository — `includeHealth` skip and `habitatFor`

**Files:**
- Modify: `lib/features/reef/data/repositories/reef_repository.dart` (`snapshotFor` at ~line 44; add `habitatFor` after `healthFor` ~line 103)
- Test: `test/features/reef/data/repositories/reef_repository_test.dart`

**Interfaces:**
- Consumes: existing `_resolve`, `ReefCoordinateKey`, `ReefPart`.
- Produces:
  - `Future<ReefSnapshot> snapshotFor(GeoPoint point, {DateTime? date, bool includeHealth = true})` — when `includeHealth` is false the health slot is `ReefPart<ReefHealth>.empty()` with no network request and no cache I/O.
  - `Future<ReefPart<ReefHabitat>> habitatFor(GeoPoint point)` — cache-aside habitat lookup, same dedupe as `healthFor`.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/reef/data/repositories/reef_repository_test.dart`. The file's `buildRepository` helper hardcodes clients; add an optional `healthClient` parameter to it, defaulting to the existing 503 mock:

```dart
  ReefRepository buildRepository({
    http.Client? habitatClient,
    http.Client? healthClient,
  }) {
    final ok = MockClient(
      (_) async => http.Response(jsonEncode({'features': []}), 200),
    );
    return ReefRepository(
      cache: ReefCacheDao(db, now: () => clock),
      habitat: ReefHabitatService(client: habitatClient ?? ok),
      health: ReefHealthService(
        client:
            healthClient ??
            MockClient((_) async => http.Response('down', 503)),
      ),
      protection: ReefProtectionService(client: ok),
      species: NearbySpeciesService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'facets': []}), 200),
        ),
        matcher: _matcher(),
      ),
    );
  }
```

New tests inside `main()`:

```dart
  test('includeHealth false issues no health request and caches nothing', () async {
    var healthCalls = 0;
    final counting = MockClient((_) async {
      healthCalls++;
      return http.Response('down', 503);
    });

    final repo = buildRepository(healthClient: counting);
    final snapshot = await repo.snapshotFor(
      const GeoPoint(41.0, -81.5),
      includeHealth: false,
    );

    expect(healthCalls, 0);
    expect(snapshot.health.status, ReefDataStatus.empty);
    // The other three parts fetched normally.
    expect(snapshot.habitat.status, ReefDataStatus.empty);
    expect(snapshot.protection.status, ReefDataStatus.empty);

    // Nothing was cached for health: a later includeHealth fetch really goes
    // to the network.
    await repo.snapshotFor(const GeoPoint(41.0, -81.5));
    expect(healthCalls, 1);
  });

  test('habitatFor serves the second call from cache', () async {
    final counting = MockClient((_) async {
      habitatCalls++;
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {'threat_txt': 'High'},
            },
          ],
        }),
        200,
      );
    });

    final repo = buildRepository(habitatClient: counting);
    final first = await repo.habitatFor(const GeoPoint(12.16, -68.28));
    final second = await repo.habitatFor(const GeoPoint(12.16, -68.28));

    expect(habitatCalls, 1);
    expect(first.value!.onReef, isTrue);
    expect(second.value!.threatLevel, 'High');
  });

  test('habitatFor shares the cache entry with snapshotFor', () async {
    final counting = MockClient((_) async {
      habitatCalls++;
      return http.Response(jsonEncode({'features': []}), 200);
    });

    final repo = buildRepository(habitatClient: counting);
    await repo.snapshotFor(const GeoPoint(12.16, -68.28));
    await repo.habitatFor(const GeoPoint(12.16, -68.28));

    expect(habitatCalls, 1);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/reef/data/repositories/reef_repository_test.dart`
Expected: FAIL — `includeHealth` and `habitatFor` are not defined. Pre-existing tests still pass.

- [ ] **Step 3: Implement**

In `reef_repository.dart`, change `snapshotFor`'s signature and health element:

```dart
  /// Fetches all four parts for [point], using cache where fresh.
  ///
  /// [includeHealth] is false for freshwater sites: NOAA's grid covers only
  /// oceans, and skipping the fetch also skips the nearest-water-pixel
  /// fallback that would otherwise hand a coastal quarry the adjacent ocean's
  /// temperature. The health slot comes back [ReefDataStatus.empty] with no
  /// network request and no cache write.
  Future<ReefSnapshot> snapshotFor(
    GeoPoint point, {
    DateTime? date,
    bool includeHealth = true,
  }) async {
```

and replace the health `_resolve` entry in the `Future.wait` list with:

```dart
      includeHealth
          ? _resolve<ReefHealth>(
              provider: ReefProviderId.health,
              coordKey: key,
              variant: date == null ? '' : _dateVariant(date),
              fetch: () => _health.fetch(quantized, date: date),
              encode: (v) => jsonEncode(v.toJson()),
              decode: (j) => ReefHealth.fromJson(j as Map<String, dynamic>),
            )
          : Future.value(const ReefPart<ReefHealth>.empty()),
```

After `healthFor`, add:

```dart
  /// Fetches reef habitat alone, for surfaces that already have health data
  /// from another lookup (the dive detail page). Shares cache entries and
  /// in-flight dedupe with [snapshotFor].
  Future<ReefPart<ReefHabitat>> habitatFor(GeoPoint point) {
    final quantized = ReefCoordinateKey.quantize(point);
    return _resolve<ReefHabitat>(
      provider: ReefProviderId.habitat,
      coordKey: ReefCoordinateKey.format(point),
      fetch: () => _habitat.fetch(quantized),
      encode: (v) => jsonEncode(v.toJson()),
      decode: (j) => ReefHabitat.fromJson(j as Map<String, dynamic>),
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/reef/data/repositories/reef_repository_test.dart`
Expected: PASS (all, including pre-existing).

- [ ] **Step 5: Commit**

```bash
git add lib/features/reef/data/repositories/reef_repository.dart test/features/reef/data/repositories/reef_repository_test.dart
git commit -m "Add health-skip and habitatFor to ReefRepository"
```

---

### Task 3: Providers — `ReefSnapshotRequest` rekey and `reefHabitatProvider`

**Files:**
- Modify: `lib/features/reef/presentation/providers/reef_providers.dart`
- Test: `test/features/reef/presentation/providers/reef_providers_test.dart` (update any `reefSnapshotProvider(GeoPoint)` usages)

**Interfaces:**
- Consumes: Task 2's `snapshotFor(includeHealth:)` and `habitatFor`.
- Produces:
  - `class ReefSnapshotRequest extends Equatable { final GeoPoint location; final bool fetchHealth; const ReefSnapshotRequest({required this.location, this.fetchHealth = true}); }`
  - `reefSnapshotProvider` — `FutureProvider.family<ReefSnapshot, ReefSnapshotRequest>`
  - `reefHabitatProvider` — `FutureProvider.family<ReefPart<ReefHabitat>, GeoPoint>`

- [ ] **Step 1: Update the provider file**

In `reef_providers.dart`, add import `package:submersion/features/reef/domain/entities/reef_habitat.dart`, then replace the `reefSnapshotProvider` declaration with:

```dart
/// Identifies one snapshot lookup. [fetchHealth] is false for freshwater
/// sites, whose water NOAA's ocean grid cannot see; equality covers it so a
/// water-type edit refetches.
class ReefSnapshotRequest extends Equatable {
  final GeoPoint location;
  final bool fetchHealth;

  const ReefSnapshotRequest({required this.location, this.fetchHealth = true});

  @override
  List<Object?> get props => [location, fetchHealth];
}

/// All reef-data parts for a location. Fetched when a site is viewed.
final reefSnapshotProvider =
    FutureProvider.family<ReefSnapshot, ReefSnapshotRequest>((ref, request) {
      return ref
          .watch(reefRepositoryProvider)
          .snapshotFor(request.location, includeHealth: request.fetchHealth);
    });

/// Habitat alone, for the dive detail page's water-conditions card.
final reefHabitatProvider =
    FutureProvider.family<ReefPart<ReefHabitat>, GeoPoint>((ref, location) {
      return ref.watch(reefRepositoryProvider).habitatFor(location);
    });
```

- [ ] **Step 2: Fix compile errors in tests and run them**

Run: `grep -rn "reefSnapshotProvider(" lib test` — every call site must pass a `ReefSnapshotRequest`. In `reef_providers_test.dart`, wrap existing `GeoPoint` arguments: `reefSnapshotProvider(ReefSnapshotRequest(location: <the GeoPoint>))`. (`reef_section_test.dart` is fully reworked in Task 6 — if it fails to compile at this point, that is expected; do not fix it here beyond leaving a note.) `lib/` has exactly one call site (`reef_section.dart`), updated in Task 6; to keep the tree compiling in this task, update it minimally now:

In `reef_section.dart` replace

```dart
    final snapshotAsync = ref.watch(reefSnapshotProvider(location));
```

with

```dart
    final snapshotAsync = ref.watch(
      reefSnapshotProvider(ReefSnapshotRequest(location: location)),
    );
```

Run: `flutter test test/features/reef/presentation/providers/reef_providers_test.dart`
Expected: PASS.

- [ ] **Step 3: Add a provider test for the habitat family**

In `reef_providers_test.dart`, following the file's existing override/container conventions, add a test that overrides `reefRepositoryProvider` (or the http client provider, matching how the file already stubs) and asserts `reefHabitatProvider(const GeoPoint(12.16, -68.28))` resolves to a `ReefPart<ReefHabitat>`. If the file's existing pattern stubs at the HTTP layer, reuse it verbatim with the habitat ArcGIS response shape from the repository test (`{'features': []}` → `empty`).

Run: `flutter test test/features/reef/presentation/providers/reef_providers_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/reef/presentation/providers/reef_providers.dart lib/features/reef/presentation/widgets/reef_section.dart test/features/reef/presentation/providers/reef_providers_test.dart
git commit -m "Rekey reef snapshot provider and add habitat provider"
```

---

### Task 4: l10n strings, all 11 locales

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (reef keys at ~14624; `diveDetailSection_reefHealth_*` at ~7601) and the 10 other `app_*.arb`
- Modify (generated): run l10n codegen after editing

**Interfaces:**
- Produces l10n getters used by Tasks 5-7: `water_conditions_title`, `water_conditions_unavailable`, `water_conditions_noData`, `water_conditions_freshwater`, `water_conditions_anomaly(String value)`. Changed values: `reef_section_title`, `reef_section_loadError`, `diveDetailSection_reefHealth_name`, `diveDetailSection_reefHealth_description`. Removed: `reef_health_title`, `reef_health_unavailable`, `reef_health_noData` (and their `@` metadata if present). Kept verbatim (names and values): `reef_health_degreeHeatingWeeks`, `reef_health_seaSurface`, `reef_health_asOf`, `reef_health_level*`.

- [ ] **Step 1: Edit `app_en.arb`**

Replace values:

```json
  "reef_section_title": "Ecosystem",
  "reef_section_loadError": "Could not load ecosystem data right now",
  "diveDetailSection_reefHealth_name": "Water Conditions",
  "diveDetailSection_reefHealth_description": "Satellite water conditions on the dive date",
```

Delete `reef_health_title`, `reef_health_unavailable`, `reef_health_noData` (plus any `@`-metadata entries for them). Add, next to the remaining `reef_health_*` keys:

```json
  "water_conditions_title": "Water conditions",
  "water_conditions_unavailable": "Could not check water conditions right now",
  "water_conditions_noData": "No satellite water data for this location",
  "water_conditions_freshwater": "Satellite water temperature covers oceans only",
  "water_conditions_anomaly": "Anomaly {value}",
  "@water_conditions_anomaly": {
    "placeholders": {
      "value": {"type": "String"}
    }
  },
```

(Match the metadata formatting style the file already uses for `reef_health_seaSurface`.)

- [ ] **Step 2: Translate into the other 10 locales**

Apply the same structural edit (replace 4 values, delete 3 keys, add 5 keys + metadata) in each ARB with these values:

| Key | de | es | fr | it | nl | pt | hu | ar | he | zh |
|---|---|---|---|---|---|---|---|---|---|---|
| reef_section_title | Ökosystem | Ecosistema | Écosystème | Ecosistema | Ecosysteem | Ecossistema | Ökoszisztéma | النظام البيئي | מערכת אקולוגית | 生态系统 |
| reef_section_loadError | Ökosystemdaten konnten gerade nicht geladen werden | No se pudieron cargar los datos del ecosistema en este momento | Impossible de charger les données de l'écosystème pour le moment | Impossibile caricare i dati dell'ecosistema al momento | Ecosysteemgegevens konden nu niet worden geladen | Não foi possível carregar os dados do ecossistema agora | Az ökoszisztéma-adatok jelenleg nem tölthetők be | تعذّر تحميل بيانات النظام البيئي الآن | לא ניתן לטעון נתוני מערכת אקולוגית כרגע | 目前无法加载生态系统数据 |
| diveDetailSection_reefHealth_name | Wasserbedingungen | Condiciones del agua | Conditions de l'eau | Condizioni dell'acqua | Wateromstandigheden | Condições da água | Vízviszonyok | أحوال المياه | תנאי המים | 水况 |
| diveDetailSection_reefHealth_description | Satellitengestützte Wasserbedingungen am Tauchdatum | Condiciones del agua por satélite en la fecha de la inmersión | Conditions de l'eau par satellite à la date de la plongée | Condizioni dell'acqua da satellite alla data dell'immersione | Satellietwateromstandigheden op de duikdatum | Condições da água por satélite na data do mergulho | Műholdas vízviszonyok a merülés napján | أحوال المياه عبر الأقمار الصناعية في تاريخ الغطسة | תנאי מים לווייניים בתאריך הצלילה | 潜水日期的卫星水况 |
| water_conditions_title | Wasserbedingungen | Condiciones del agua | Conditions de l'eau | Condizioni dell'acqua | Wateromstandigheden | Condições da água | Vízviszonyok | أحوال المياه | תנאי המים | 水况 |
| water_conditions_unavailable | Wasserbedingungen konnten gerade nicht geprüft werden | No se pudieron comprobar las condiciones del agua en este momento | Impossible de vérifier les conditions de l'eau pour le moment | Impossibile verificare le condizioni dell'acqua al momento | Wateromstandigheden konden nu niet worden gecontroleerd | Não foi possível verificar as condições da água agora | A vízviszonyok jelenleg nem ellenőrizhetők | تعذّر التحقق من أحوال المياه الآن | לא ניתן לבדוק את תנאי המים כרגע | 目前无法检查水况 |
| water_conditions_noData | Keine Satelliten-Wasserdaten für diesen Ort | No hay datos satelitales del agua para esta ubicación | Aucune donnée satellite sur l'eau pour cet emplacement | Nessun dato satellitare sull'acqua per questa posizione | Geen satellietwatergegevens voor deze locatie | Sem dados de satélite da água para este local | Nincsenek műholdas vízadatok ehhez a helyhez | لا توجد بيانات مياه من الأقمار الصناعية لهذا الموقع | אין נתוני לוויין על המים למיקום זה | 此位置没有卫星水文数据 |
| water_conditions_freshwater | Satellitengestützte Wassertemperatur deckt nur Ozeane ab | La temperatura del agua por satélite solo cubre los océanos | La température de l'eau par satellite ne couvre que les océans | La temperatura dell'acqua da satellite copre solo gli oceani | Satellietwatertemperatuur dekt alleen oceanen | A temperatura da água por satélite cobre apenas os oceanos | A műholdas vízhőmérséklet csak az óceánokat fedi le | درجة حرارة المياه عبر الأقمار الصناعية تغطي المحيطات فقط | טמפרטורת מים לוויינית מכסה אוקיינוסים בלבד | 卫星水温仅覆盖海洋 |
| water_conditions_anomaly | Anomalie {value} | Anomalía {value} | Anomalie {value} | Anomalia {value} | Anomalie {value} | Anomalia {value} | Anomália {value} | شذوذ {value} | סטייה {value} | 距平 {value} |

Merge-conflict note: ARB files in this repo have a history of line-2 merge conflicts; keep each ARB's existing key ordering and only touch the listed keys.

- [ ] **Step 3: Regenerate localizations and verify compile**

Run: `flutter gen-l10n` then `flutter analyze lib/l10n`
Expected: `app_localizations.dart` regenerates with the new getters; analyze may report errors elsewhere (widgets still referencing `reef_health_title` until Task 5) — that is expected; only confirm the l10n library itself generated.

- [ ] **Step 4: Commit**

Do NOT commit yet if `flutter analyze` fails project-wide because `reef_health_card.dart` references deleted keys — instead proceed to Task 5 and commit both together. If analyze is clean, commit now:

```bash
git add lib/l10n
git commit -m "Add water-conditions l10n strings in all locales"
```

---

### Task 5: `WaterConditionsCard`

**Files:**
- Create: `lib/features/reef/presentation/widgets/water_conditions_card.dart`
- Delete: `lib/features/reef/presentation/widgets/reef_health_card.dart` (git mv then rewrite)
- Test: `test/features/reef/presentation/widgets/water_conditions_card_test.dart` (new)

**Interfaces:**
- Consumes: `TemperatureUnit.convertDelta` (Task 1), l10n keys (Task 4).
- Produces: `WaterConditionsCard({required ReefPart<ReefHealth> health, ReefPart<ReefHabitat>? habitat, WaterType? waterType})` — used by Tasks 6 and 7.

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/reef/presentation/widgets/water_conditions_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/widgets/water_conditions_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

ReefHealth _health({double? anomaly}) => ReefHealth(
  sst: 30.1,
  sstAnomaly: anomaly,
  degreeHeatingWeeks: 15.64,
  hotspot: 0.91,
  alertLevel: BleachingAlertLevel.watch,
  observedAt: DateTime.utc(2023, 9, 1, 12),
);

Widget _harness({
  required ReefPart<ReefHealth> health,
  ReefPart<ReefHabitat>? habitat,
  WaterType? waterType,
  TemperatureUnit unit = TemperatureUnit.celsius,
}) {
  return ProviderScope(
    overrides: [temperatureUnitProvider.overrideWithValue(unit)],
    child: localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: WaterConditionsCard(
          health: health,
          habitat: habitat,
          waterType: waterType,
        ),
      ),
    ),
  );
}

void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  group('bleaching gate', () {
    testWidgets('shows stress lines when habitat confirms a reef', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health()),
          habitat: const ReefPart.ok(ReefHabitat(onReef: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bleaching watch'), findsOneWidget);
      expect(find.textContaining('15.6'), findsOneWidget);
    });

    testWidgets('hides stress lines when habitat rules a reef out', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health()),
          habitat: const ReefPart.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bleaching'), findsNothing);
      expect(find.textContaining('Degree Heating'), findsNothing);
      expect(find.textContaining('30.1'), findsOneWidget);
    });

    testWidgets('shows stress lines when habitat is unavailable', (
      tester,
    ) async {
      // An offline habitat provider must never hide an active alert.
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health()),
          habitat: const ReefPart.unavailable(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bleaching watch'), findsOneWidget);
    });

    testWidgets('shows stress lines when habitat is unknown (null)', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(health: ReefPart.ok(_health())));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bleaching watch'), findsOneWidget);
    });
  });

  group('anomaly line', () {
    testWidgets('renders signed anomaly in celsius', (tester) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health(anomaly: 0.42)),
          habitat: const ReefPart.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('+0.4C'), findsOneWidget);
    });

    testWidgets('converts anomaly as a delta, not an absolute', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health(anomaly: 0.5)),
          habitat: const ReefPart.empty(),
          unit: TemperatureUnit.fahrenheit,
        ),
      );
      await tester.pumpAndSettle();

      // 0.5 C delta is +0.9 F. An absolute conversion would say +32.9 F.
      expect(find.textContaining('+0.9F'), findsOneWidget);
      expect(find.textContaining('32.9'), findsNothing);
    });

    testWidgets('renders negative anomaly with its own sign', (tester) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health(anomaly: -1.0)),
          habitat: const ReefPart.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('-1.0C'), findsOneWidget);
    });
  });

  group('non-ok states', () {
    testWidgets('freshwater message wins over fetched data', (tester) async {
      await tester.pumpWidget(
        _harness(
          health: const ReefPart.unavailable(),
          waterType: WaterType.fresh,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Satellite water temperature covers oceans only'),
        findsOneWidget,
      );
      expect(find.textContaining('Could not check'), findsNothing);
    });

    testWidgets('distinguishes unavailable from empty', (tester) async {
      await tester.pumpWidget(
        _harness(health: const ReefPart.unavailable()),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not check'), findsOneWidget);

      await tester.pumpWidget(_harness(health: const ReefPart.empty()));
      await tester.pumpAndSettle();
      expect(find.textContaining('No satellite water data'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/reef/presentation/widgets/water_conditions_card_test.dart`
Expected: FAIL — `water_conditions_card.dart` does not exist.

- [ ] **Step 3: Implement the card**

`git mv lib/features/reef/presentation/widgets/reef_health_card.dart lib/features/reef/presentation/widgets/water_conditions_card.dart`, then rewrite the file:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Satellite water conditions: temperature, anomaly, and — on reefs — the
/// coral thermal-stress classification.
///
/// Sea surface temperature and its anomaly are valid anywhere in the ocean;
/// the bleaching alert level and Degree Heating Weeks are coral framing and
/// only shown while [habitat] has not ruled a reef out. When shown, Degree
/// Heating Weeks is rendered next to the alert level, never behind a tap: the
/// level is an instantaneous classification while the damage it implies is
/// cumulative, so a reef mid-mortality can read "Bleaching Watch".
class WaterConditionsCard extends ConsumerWidget {
  final ReefPart<ReefHealth> health;

  /// Null while the habitat lookup is still resolving (dive detail page).
  final ReefPart<ReefHabitat>? habitat;

  final WaterType? waterType;

  const WaterConditionsCard({
    super.key,
    required this.health,
    this.habitat,
    this.waterType,
  });

  /// True unless habitat definitively answered "no reef here". An offline
  /// habitat provider must never hide an active bleaching alert.
  bool get _reefPossible =>
      habitat == null || habitat!.status != ReefDataStatus.empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget tile(String subtitle, {bool isThreeLine = false}) => ListTile(
      leading: Icon(Icons.thermostat, color: scheme.primary),
      title: Text(
        context.l10n.water_conditions_title,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(subtitle),
      isThreeLine: isThreeLine,
      dense: true,
    );

    if (waterType == WaterType.fresh) {
      return tile(context.l10n.water_conditions_freshwater);
    }
    if (health.status == ReefDataStatus.unavailable) {
      return tile(context.l10n.water_conditions_unavailable);
    }
    if (health.status == ReefDataStatus.empty) {
      return tile(context.l10n.water_conditions_noData);
    }

    final data = health.value!;
    final tempUnit = ref.watch(temperatureUnitProvider);

    final lines = <String>[];
    if (_reefPossible) {
      final level = data.alertLevel;
      if (level != null) lines.add(_levelLabel(context, level));
      if (data.degreeHeatingWeeks != null) {
        lines.add(
          context.l10n.reef_health_degreeHeatingWeeks(
            data.degreeHeatingWeeks!.toStringAsFixed(1),
          ),
        );
      }
    }
    if (data.sst != null) {
      final value = TemperatureUnit.celsius.convert(data.sst!, tempUnit);
      lines.add(
        context.l10n.reef_health_seaSurface(
          '${value.toStringAsFixed(1)}${tempUnit.symbol}',
        ),
      );
    }
    if (data.sstAnomaly != null) {
      // The anomaly is a temperature difference, not a temperature: it
      // scales between units but never takes the Fahrenheit offset.
      final value = TemperatureUnit.celsius.convertDelta(
        data.sstAnomaly!,
        tempUnit,
      );
      final signed = value >= 0
          ? '+${value.toStringAsFixed(1)}'
          : value.toStringAsFixed(1);
      lines.add(
        context.l10n.water_conditions_anomaly('$signed${tempUnit.symbol}'),
      );
    }
    // NOAA publishes one composite per UTC day, stamped at 12:00Z. Converting
    // to local time would shift that stamp into the next or previous calendar
    // day at the extremes of the timezone range, reporting an observation
    // date the dataset never had.
    lines.add(
      context.l10n.reef_health_asOf(
        DateFormat.yMMMd().format(data.observedAt.toUtc()),
      ),
    );

    return tile(lines.join('\n'), isThreeLine: lines.length > 2);
  }

  String _levelLabel(BuildContext context, BleachingAlertLevel level) =>
      switch (level) {
        BleachingAlertLevel.noStress => context.l10n.reef_health_levelNoStress,
        BleachingAlertLevel.watch => context.l10n.reef_health_levelWatch,
        BleachingAlertLevel.warning => context.l10n.reef_health_levelWarning,
        BleachingAlertLevel.alertLevel1 => context.l10n.reef_health_levelAlert1,
        BleachingAlertLevel.alertLevel2 => context.l10n.reef_health_levelAlert2,
        BleachingAlertLevel.alertLevel3 => context.l10n.reef_health_levelAlert3,
        BleachingAlertLevel.alertLevel4 => context.l10n.reef_health_levelAlert4,
        BleachingAlertLevel.alertLevel5 => context.l10n.reef_health_levelAlert5,
      };
}
```

Note: `reef_section.dart` and `dive_detail_page.dart` still import and use
`ReefHealthCard` at this point and will not compile. Update them minimally in
this task to keep the tree green — in both files change the import to
`water_conditions_card.dart` and the constructor to
`WaterConditionsCard(health: <the part>)` (full rework lands in Tasks 6-7).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/reef/presentation/widgets/water_conditions_card_test.dart test/features/reef`
Expected: new tests PASS; `reef_section_test.dart` may still reference removed "Reef health" strings — if it fails on those, adjust only failing expectations to the new card title (Task 6 rewrites the file properly).

- [ ] **Step 5: Commit (include Task 4's l10n if deferred)**

```bash
git add -A lib/l10n lib/features/reef test/features/reef lib/features/dive_log
git commit -m "Replace ReefHealthCard with gated WaterConditionsCard"
```

---

### Task 6: Ecosystem section on the site page

**Files:**
- Modify: `lib/features/reef/presentation/widgets/reef_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (ReefSection call, ~line 203)
- Test: `test/features/reef/presentation/widgets/reef_section_test.dart`

**Interfaces:**
- Consumes: `ReefSnapshotRequest` (Task 3), `WaterConditionsCard` (Task 5).
- Produces: `ReefSection({required GeoPoint location, WaterType? waterType})`.

- [ ] **Step 1: Update the failing tests first**

Rework `reef_section_test.dart`: change the harness to build the request and accept a water type, and add the new behavioral tests. Replace the `_harness` function and add tests:

```dart
Widget _harness(ReefSnapshot snapshot, {WaterType? waterType}) {
  final request = ReefSnapshotRequest(
    location: _location,
    fetchHealth: waterType != WaterType.fresh,
  );
  return ProviderScope(
    overrides: [
      reefSnapshotProvider(request).overrideWith((ref) async => snapshot),
      // WaterConditionsCard reads the diver's unit setting, which chains
      // through settingsProvider to SharedPreferences. Overriding at the
      // narrowest point severs that chain without mocking preferences.
      temperatureUnitProvider.overrideWithValue(TemperatureUnit.celsius),
    ],
    child: localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReefSection(location: _location, waterType: waterType),
        ),
      ),
    ),
  );
}
```

Add `import 'package:submersion/core/constants/enums.dart';` to the test file. New tests inside `main()`:

```dart
  testWidgets('titles the section Ecosystem', (tester) async {
    await tester.pumpWidget(_harness(_snapshot()));
    await tester.pumpAndSettle();

    expect(find.text('Ecosystem'), findsOneWidget);
    expect(find.text('Reef'), findsNothing);
  });

  testWidgets('hides the habitat row when the site is not on a reef', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_snapshot()));
    await tester.pumpAndSettle();

    expect(find.textContaining('No mapped coral reef'), findsNothing);
    expect(find.textContaining('Reef habitat'), findsNothing);
  });

  testWidgets('keeps the habitat row when the check failed', (tester) async {
    await tester.pumpWidget(
      _harness(_snapshot(habitat: const ReefPart.unavailable())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not check reef habitat'), findsOneWidget);
  });

  testWidgets('shows the freshwater message for freshwater sites', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_snapshot(), waterType: WaterType.fresh),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Satellite water temperature covers oceans only'),
      findsOneWidget,
    );
  });

  testWidgets('suppresses stress lines at a confirmed non-reef site', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          health: ReefPart.ok(
            ReefHealth(
              sst: 14.2,
              sstAnomaly: 0.3,
              degreeHeatingWeeks: 0.0,
              hotspot: -0.5,
              alertLevel: BleachingAlertLevel.noStress,
              observedAt: DateTime.utc(2026, 8, 1, 12),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('14.2'), findsOneWidget);
    expect(find.textContaining('stress'), findsNothing);
    expect(find.textContaining('Degree Heating'), findsNothing);
  });
```

Also update the two pre-existing health tests ("always shows degree heating weeks beside the alert level" and "reports the observation date in UTC"): the default `_snapshot()` habitat is `ReefPart.empty()`, which now suppresses stress lines — pass `habitat: const ReefPart.ok(ReefHabitat(onReef: true))` in both so the stress-line expectations still hold.

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `flutter test test/features/reef/presentation/widgets/reef_section_test.dart`
Expected: FAIL — `ReefSection` has no `waterType`, title is still "Reef", habitat row still renders when empty.

- [ ] **Step 3: Implement**

In `reef_section.dart`: add imports for `enums.dart`, `reef_data_status.dart`, and `water_conditions_card.dart` (drop the `reef_health_card.dart` import if still present). Add the field and constructor parameter, build the request, and change the data column:

```dart
class ReefSection extends ConsumerWidget {
  final GeoPoint location;

  /// Freshwater sites skip the NOAA fetch: its grid covers only oceans.
  final WaterType? waterType;

  const ReefSection({super.key, required this.location, this.waterType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(
      reefSnapshotProvider(
        ReefSnapshotRequest(
          location: location,
          fetchHealth: waterType != WaterType.fresh,
        ),
      ),
    );
```

and in the `data:` branch:

```dart
              data: (snapshot) => Column(
                children: [
                  if (snapshot.habitat.status != ReefDataStatus.empty)
                    ReefHabitatCard(part: snapshot.habitat),
                  WaterConditionsCard(
                    health: snapshot.health,
                    habitat: snapshot.habitat,
                    waterType: waterType,
                  ),
                  ReefProtectionCard(part: snapshot.protection),
                ],
              ),
```

Update the class doc comment: the section is now ecosystem information
(habitat when on a reef, water conditions, protected status), still hidden
entirely for sites without coordinates.

In `site_detail_page.dart` change the call:

```dart
            ReefSection(location: site.location!, waterType: site.waterType),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/reef/presentation/widgets/reef_section_test.dart test/features/dive_sites`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reef/presentation/widgets/reef_section.dart lib/features/dive_sites/presentation/pages/site_detail_page.dart test/features/reef/presentation/widgets/reef_section_test.dart
git commit -m "Retitle site reef section to Ecosystem with water-type awareness"
```

---

### Task 7: Dive detail page section

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildReefHealthSection`, ~line 3409)
- Modify: `lib/core/constants/dive_detail_sections.dart` (fallback strings, lines 42 and 70)
- Test: run `grep -rn "Reef Health\|ReefHealthCard\|reefHealth" test/ --include="*.dart" -l` and update every hit for the new name/API

**Interfaces:**
- Consumes: `reefHabitatProvider` (Task 3), `WaterConditionsCard` (Task 5).
- Produces: no new interfaces. `DiveDetailSectionId.reefHealth` enum id is deliberately unchanged (persisted in user section configs).

- [ ] **Step 1: Update the section builder**

Replace `_buildReefHealthSection` in `dive_detail_page.dart`:

```dart
  /// Satellite water conditions on the date of this dive.
  ///
  /// Historical NOAA readings are immutable, so this is fetched once and
  /// cached permanently. Hidden when the dive has no site coordinates, and
  /// for freshwater sites, whose water NOAA's ocean grid cannot see — a
  /// permanent coverage explanation on every quarry dive would be noise.
  Widget _buildReefHealthSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
  ) {
    final site = dive.site;
    if (site?.hasCoordinates != true) return const SizedBox.shrink();
    if (site!.waterType == WaterType.fresh) return const SizedBox.shrink();

    final location = site.location!;
    final healthAsync = ref.watch(
      reefHealthForDiveProvider(
        ReefHealthRequest(location: location, date: dive.effectiveEntryTime),
      ),
    );
    final habitatAsync = ref.watch(reefHabitatProvider(location));

    return healthAsync.when(
      data: (part) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Card(
            child: WaterConditionsCard(
              health: part,
              // Null while still resolving: the card then keeps the stress
              // lines, the conservative default.
              habitat: habitatAsync.valueOrNull,
              waterType: site.waterType,
            ),
          ),
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
```

Confirm imports: `WaterType` (from `core/constants/enums.dart`) and the reef providers import are likely present; add whichever the analyzer reports missing. Remove the now-unused `reef_health_card.dart` import if Task 5's shim left one.

- [ ] **Step 2: Update the section registry fallback strings**

In `dive_detail_sections.dart` line 42: `reefHealth => 'Reef Health',` → `reefHealth => 'Water Conditions',` and line 70: `reefHealth => 'Coral bleaching heat stress on the dive date',` → `reefHealth => 'Satellite water conditions on the dive date',`. (The l10n keys were already re-valued in Task 4; the enum id stays.)

- [ ] **Step 3: Sweep tests referencing the old name**

Run: `grep -rln "Reef Health\|ReefHealthCard\|reef_health_card" test/ --include="*.dart"` and fix each hit: imports to `water_conditions_card.dart`, constructor to named parameters (`health:` etc.), display-name expectations to "Water Conditions".

- [ ] **Step 4: Run the affected suites**

Run: `flutter test test/features/dive_log test/features/reef test/core`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/core/constants/dive_detail_sections.dart test/
git commit -m "Gate dive-detail water conditions and rename section display"
```

---

### Task 8: Full verification sweep

**Files:** none new — verification only.

- [ ] **Step 1: Format**

Run: `dart format .`
Expected: only files from this branch change, if any; commit any reformatting.

- [ ] **Step 2: Analyze — full project, no output piping**

Run: `flutter analyze`
Expected: `No issues found!` — do not pipe through `tail`/`grep` (masks failures); infos are fatal.

- [ ] **Step 3: Full test suite**

Run: `flutter test` (timeout 600000 ms)
Expected: all pass. Known flaky suites (backup, media store, recovery-code) may fail under full-suite load — retry a failing flaky suite alone before treating it as a regression; reef/dive-log/core failures are real.

- [ ] **Step 4: Commit any remaining changes**

```bash
git add -A
git commit -m "Format and test sweep for water conditions"
```

(Skip the commit if the tree is clean.)

---

### Task 9: Open the PR

- [ ] **Step 1: Push**

```bash
git push -u origin worktree-water-conditions --no-verify
```

`--no-verify` is required: the pre-push hook resolves an absolute
`core.hooksPath` and analyzes the MAIN checkout, not this worktree (known repo
issue; fix pending in PR #915).

- [ ] **Step 2: Create the PR**

`gh pr create` with base `main`, title
`Reframe reef health as water conditions for non-reef sites`, and a body that
summarizes: the ocean-wide validity of the NOAA data vs its coral framing; the
Ecosystem retitle; the bleaching gate (shown unless habitat rules a reef out);
the freshwater skip closing the coastal-pixel leak; the newly displayed
anomaly with delta conversion; the dive-detail section display rename with
unchanged persisted id; and the spec/plan paths. Do NOT include any Claude
attribution or session links (project rule).
