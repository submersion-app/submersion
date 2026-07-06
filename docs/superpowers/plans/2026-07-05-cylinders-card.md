# Unified Cylinders Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dive-detail page's separate "Tanks" card and "SAC by Cylinder" block with one always-expanded "Cylinders" card that shows identity, pressures, MOD/MND, and per-tank SAC for every tank.

**Architecture:** A new `CylindersCard` `ConsumerWidget` joins `dive.tanks` with `cylinderSacProvider` results by `tankId` and takes over the existing `DiveDetailSectionId.tanks` slot. The old inline builders in `dive_detail_page.dart` and the cylinder-SAC sub-block of the SAC-segments section are deleted, along with the never-used `cylinder_sac_card.dart`.

**Tech Stack:** Flutter 3.x / Material 3, Riverpod (StateNotifier + FutureProvider.family), flutter gen-l10n (ARB, 11 locales), flutter_test widget tests.

**Spec:** `docs/superpowers/specs/2026-07-05-cylinders-card-design.md`

## Global Constraints

- `DiveDetailSectionId.tanks` enum value is NEVER renamed (persisted section config round-trips through `id.name`).
- All strings displayed to users come from l10n; new/changed keys must be updated in ALL 11 ARB files (`lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`), then regenerate with `flutter gen-l10n`.
- All displayed values go through `UnitFormatter` (respect active unit settings).
- `dart format .` must produce no changes before each commit; `flutter analyze` (whole project) must report no issues.
- Run specific test files, not broad directories (Bash timeouts).
- No emojis in code, comments, or docs. Commits contain no Co-Authored-By lines.
- Behavior preservation: hardcoded English " used" suffixes in pressure/volume strings are pre-existing behavior — keep them verbatim, do not localize in this plan.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `lib/features/dive_log/presentation/widgets/cylinders_card.dart` | Create | The unified card widget (rows, chip, trailing SAC block, pressure resolution) |
| `test/features/dive_log/presentation/widgets/cylinders_card_test.dart` | Create | Widget tests for the card |
| `lib/l10n/arb/app_*.arb` (11 files) | Modify | Add `diveLog_detail_section_cylinders`; update section name/description strings; later remove obsolete keys |
| `lib/core/constants/dive_detail_sections.dart` | Modify | English fallback `displayName`/`description` for `tanks` and `sacSegments` |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Modify | Swap `tanks` section builder to `CylindersCard`; delete old builders and the cylinder-SAC sub-block |
| `lib/features/dive_log/presentation/providers/gas_analysis_providers.dart` | Modify | Remove `cylinderSacExpandedProvider` |
| `lib/features/dive_log/presentation/widgets/cylinder_sac_card.dart` | Delete | Dead code (no references anywhere) |
| `test/core/constants/dive_detail_sections_test.dart`, `test/features/settings/presentation/pages/dive_detail_sections_page_test.dart` | Modify | 'Tanks' -> 'Cylinders' expectations |

---

### Task 1: l10n strings and section metadata

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Modify: `lib/core/constants/dive_detail_sections.dart`
- Modify: `test/core/constants/dive_detail_sections_test.dart:402,535`
- Modify: `test/features/settings/presentation/pages/dive_detail_sections_page_test.dart:326`

**Interfaces:**
- Produces: l10n getter `context.l10n.diveLog_detail_section_cylinders` (type `String`), used by Task 2's widget. Old keys (`diveLog_detail_section_tanks`, `diveLog_detail_section_sacByCylinder`, `diveLog_detail_tankCount`) stay in place until Task 4 so the page keeps compiling.

- [ ] **Step 1: Add the new key and update changed strings in `app_en.arb`**

Next to the existing `"diveLog_detail_section_tanks": "Tanks",` line (line ~1900), add:

```json
  "diveLog_detail_section_cylinders": "Cylinders",
```

Change these existing values (do NOT remove any keys in this task):

```json
  "diveDetailSection_tanks_name": "Cylinders",
  "diveDetailSection_tanks_description": "Cylinder list, gas mixes, pressures, MOD/MND, per-tank SAC",
  "diveDetailSection_sacSegments_description": "Phase/time SAC segmentation",
```

- [ ] **Step 2: Update the 10 non-English ARB files**

Every locale already translates "Tanks" with its cylinder/bottle word, so for each locale: (a) add `diveLog_detail_section_cylinders` with the SAME value as that locale's existing `diveLog_detail_section_tanks`; (b) replace `diveDetailSection_sacSegments_description` with the trimmed value below; (c) leave `diveDetailSection_tanks_name` and `diveDetailSection_tanks_description` unchanged (already cylinder-worded).

| File | `diveLog_detail_section_cylinders` (copy of existing tanks value) | New `diveDetailSection_sacSegments_description` |
| --- | --- | --- |
| app_ar.arb | `الأسطوانات` | `تقسيم SAC حسب المراحل/الوقت` |
| app_de.arb | `Flaschen` | `SAC-Segmentierung nach Phase/Zeit` |
| app_es.arb | `Tanques` | `Segmentacion SAC por fase/tiempo` |
| app_fr.arb | `Blocs` | `Segmentation SAC par phase/temps` |
| app_he.arb | `בלונים` | `פילוח SAC לפי שלב/זמן` |
| app_hu.arb | `Palackok` | `SAC szegmentálás fázis/idő szerint` |
| app_it.arb | `Bombole` | `Segmentazione SAC per fase/tempo` |
| app_nl.arb | `Flessen` | `SAC-segmentatie per fase/tijd` |
| app_pt.arb | `Cilindros` | `Segmentacao SAC por fase/tempo` |
| app_zh.arb | `气瓶` | `按阶段/时间的SAC分段` |

(es keeps `Tanques` — that is its existing value; consistency with the rest of the es locale wins over the English rename.)

- [ ] **Step 3: Update the English fallbacks in `lib/core/constants/dive_detail_sections.dart`**

In the `displayName` switch: `tanks => 'Tanks',` becomes `tanks => 'Cylinders',`.
In the `description` switch:
`sacSegments => 'Phase/time segmentation, cylinder breakdown',` becomes `sacSegments => 'Phase/time SAC segmentation',` and
`tanks => 'Tank list, gas mixes, pressures, per-tank SAC',` becomes `tanks => 'Cylinder list, gas mixes, pressures, MOD/MND, per-tank SAC',`.

- [ ] **Step 4: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits 0; `lib/l10n/arb/app_localizations.dart` gains `String get diveLog_detail_section_cylinders;`.

- [ ] **Step 5: Update test expectations**

- `test/core/constants/dive_detail_sections_test.dart:402`: `expect(DiveDetailSectionId.tanks.displayName, 'Tanks');` -> `'Cylinders'`.
- `test/core/constants/dive_detail_sections_test.dart:535`: `expect(DiveDetailSectionId.tanks.localizedDisplayName(l10n), 'Tanks');` -> `'Cylinders'`.
- `test/features/settings/presentation/pages/dive_detail_sections_page_test.dart:326`: `expect(displayNames.first, 'Tanks');` -> `'Cylinders'`.
- Then grep the two files for any other assertions on the old description strings (`grep -n "Tank list\|cylinder breakdown" test/core/constants/dive_detail_sections_test.dart test/features/settings/presentation/pages/dive_detail_sections_page_test.dart`) and update them to the new values from Step 3.

- [ ] **Step 6: Run the affected tests**

Run: `flutter test test/core/constants/dive_detail_sections_test.dart test/features/settings/presentation/pages/dive_detail_sections_page_test.dart`
Expected: all pass.

- [ ] **Step 7: Analyze, format, commit**

```bash
flutter analyze          # expect: No issues found!
dart format .            # expect: no changed files
git add -A
git commit -m "feat(l10n): add Cylinders section strings, trim SAC-segments description"
```

---

### Task 2: CylindersCard widget (TDD)

**Files:**
- Create: `test/features/dive_log/presentation/widgets/cylinders_card_test.dart`
- Create: `lib/features/dive_log/presentation/widgets/cylinders_card.dart`

**Interfaces:**
- Consumes: `context.l10n.diveLog_detail_section_cylinders` (Task 1); existing providers `cylinderSacProvider` / `tankPressuresProvider` (`FutureProvider.family<..., String>` in `gas_analysis_providers.dart` / `dive_providers.dart`), `diveDataSourcesProvider`; entities `Dive`, `DiveTank`, `TankPressurePoint`, `CylinderSac`; helpers `UnitFormatter`, `TankPresets.byName`, `resolveSourceName`/`SourceNameLabels`, `FieldAttributionBadge`.
- Produces: `CylindersCard({required Dive dive, required UnitFormatter units, required AppSettings settings, required SacUnit sacUnit})` — a `ConsumerWidget`. Task 3 constructs it exactly with those four named parameters. Settings-derived values are constructor-injected so tests never need a `SettingsNotifier` mock (see memory: settings-notifier-mocks).

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/cylinders_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

const _settings = AppSettings();
const _units = UnitFormatter(_settings);

DiveTank _makeTank({
  String id = 'tank-1',
  String? name,
  double? volume = 11.1,
  double? startPressure = 200,
  double? endPressure = 50,
  GasMix gasMix = const GasMix(o2: 32),
  String? computerId,
}) {
  return DiveTank(
    id: id,
    name: name,
    volume: volume,
    startPressure: startPressure,
    endPressure: endPressure,
    gasMix: gasMix,
    computerId: computerId,
  );
}

Dive _makeDive(List<DiveTank> tanks) {
  return Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 1, 10, 0),
    maxDepth: 30.0,
    avgDepth: 18.0,
    bottomTime: const Duration(minutes: 45),
    tanks: tanks,
  );
}

CylinderSac _makeSac({
  String tankId = 'tank-1',
  double? sacRate = 2.0,
  double? tankVolume = 11.1,
  double? startPressure = 200,
  double? endPressure = 50,
}) {
  return CylinderSac(
    tankId: tankId,
    gasMix: const GasMix(o2: 32),
    role: TankRole.backGas,
    tankVolume: tankVolume,
    sacRate: sacRate,
    startPressure: startPressure,
    endPressure: endPressure,
  );
}

DiveDataSource _makeSource({
  required String id,
  String? computerId,
  bool isPrimary = false,
  String? computerModel,
}) {
  final now = DateTime(2026, 6, 1, 10, 0);
  return DiveDataSource(
    id: id,
    diveId: 'dive-1',
    computerId: computerId,
    isPrimary: isPrimary,
    computerModel: computerModel,
    entryTime: now,
    exitTime: now.add(const Duration(minutes: 45)),
    importedAt: now,
    createdAt: now,
  );
}

Widget _buildCard({
  required Dive dive,
  List<CylinderSac> cylinderSacs = const [],
  List<DiveDataSource> dataSources = const [],
  UnitFormatter units = _units,
  AppSettings settings = _settings,
  SacUnit sacUnit = SacUnit.pressurePerMin,
}) {
  return testApp(
    overrides: [
      cylinderSacProvider.overrideWith((ref, id) async => cylinderSacs),
      tankPressuresProvider.overrideWith(
        (ref, id) async => <String, List<TankPressurePoint>>{},
      ),
      diveDataSourcesProvider.overrideWith((ref, id) async => dataSources),
    ],
    child: SingleChildScrollView(
      child: CylindersCard(
        dive: dive,
        units: units,
        settings: settings,
        sacUnit: sacUnit,
      ),
    ),
  );
}

void main() {
  group('CylindersCard', () {
    testWidgets('renders title, tank identity, pressures, and MOD/MND', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank()]), cylinderSacs: [_makeSac()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cylinders'), findsOneWidget);
      expect(find.textContaining('Tank 1 (EAN32)'), findsOneWidget);
      expect(
        find.textContaining('200 bar → 50 bar (150 bar used)'),
        findsOneWidget,
      );
      expect(find.textContaining('MOD:'), findsOneWidget);
      expect(find.textContaining('MND:'), findsOneWidget);
    });

    testWidgets('shows SAC and gas used on a single-tank dive', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank()]), cylinderSacs: [_makeSac()]),
      );
      await tester.pumpAndSettle();

      // sacRate 2.0 bar/min, pressurePerMin mode, metric.
      expect(find.text('2.0 bar/min'), findsOneWidget);
      // gasUsedLiters = (200 - 50) * 11.1 = 1665 L.
      expect(find.text('1665 L used'), findsOneWidget);
    });

    testWidgets('omits the SAC block when SAC is not computable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(startPressure: null, endPressure: null)]),
          cylinderSacs: [
            _makeSac(sacRate: null, startPressure: null, endPressure: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tank 1'), findsOneWidget);
      expect(find.textContaining('/min'), findsNothing);
      expect(find.textContaining('used'), findsNothing);
    });

    testWidgets('shows one row with distinct SAC per tank on multi-tank dive', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([
            _makeTank(),
            _makeTank(
              id: 'tank-2',
              name: 'Deco O2',
              volume: 5.7,
              startPressure: 200,
              endPressure: 140,
              gasMix: const GasMix(o2: 100),
            ),
          ]),
          cylinderSacs: [
            _makeSac(),
            _makeSac(
              tankId: 'tank-2',
              sacRate: 1.2,
              tankVolume: 5.7,
              startPressure: 200,
              endPressure: 140,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2.0 bar/min'), findsOneWidget);
      expect(find.text('1.2 bar/min'), findsOneWidget);
      expect(find.textContaining('Deco O2'), findsOneWidget);
    });

    testWidgets('formats SAC as L/min when unit is litersPerMin', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank()]),
          cylinderSacs: [_makeSac()],
          sacUnit: SacUnit.litersPerMin,
        ),
      );
      await tester.pumpAndSettle();

      // sacVolume = 2.0 * 11.1 / 1.01325 = 21.909... -> '21.9 L/min'.
      expect(find.text('21.9 L/min'), findsOneWidget);
    });

    testWidgets('formats pressures and SAC in imperial units', (
      tester,
    ) async {
      const imperialSettings = AppSettings(
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
        depthUnit: DepthUnit.feet,
      );
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank()]),
          cylinderSacs: [_makeSac()],
          units: const UnitFormatter(imperialSettings),
          settings: imperialSettings,
        ),
      );
      await tester.pumpAndSettle();

      // 2.0 bar/min * 14.5038 = 29.0076 -> '29.0 psi/min'.
      expect(find.text('29.0 psi/min'), findsOneWidget);
      // Pressure line rendered in psi.
      expect(find.textContaining('psi →'), findsOneWidget);
    });

    testWidgets('shows source badge only with two or more data sources', (
      tester,
    ) async {
      final dive = _makeDive([_makeTank(computerId: 'comp-1')]);

      await tester.pumpWidget(
        _buildCard(
          dive: dive,
          cylinderSacs: [_makeSac()],
          dataSources: [
            _makeSource(
              id: 'src-1',
              computerId: 'comp-1',
              isPrimary: true,
              computerModel: 'Perdix 2',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FieldAttributionBadge), findsNothing);

      await tester.pumpWidget(
        _buildCard(
          dive: dive,
          cylinderSacs: [_makeSac()],
          dataSources: [
            _makeSource(
              id: 'src-1',
              computerId: 'comp-1',
              isPrimary: true,
              computerModel: 'Perdix 2',
            ),
            _makeSource(
              id: 'src-2',
              computerId: 'comp-2',
              computerModel: 'Teric',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Perdix 2'), findsOneWidget);
    });
  });
}
```

Note: if `Dive`, `DiveTank`, or `DiveDataSource` constructors require parameters not listed here, mirror the fixtures in `test/features/dive_log/presentation/pages/dive_detail_page_test.dart:588` (`makeDiveWithTanksAndProfile`) and `test/features/dive_log/presentation/widgets/data_sources_section_test.dart` (`_makeSource`) — do not change the assertions.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart`
Expected: FAIL — compile error, `cylinders_card.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/features/dive_log/presentation/widgets/cylinders_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Unified card showing every cylinder on a dive: identity (name, gas mix,
/// volume), start/end pressures, MOD/MND, and per-tank SAC.
///
/// Replaces the former Tanks card and SAC by Cylinder block. Occupies the
/// [DiveDetailSectionId.tanks] slot on the dive detail page. Per-tank SAC
/// is shown whenever it is computable, regardless of tank count; the
/// trailing block is omitted entirely when it is not.
class CylindersCard extends ConsumerWidget {
  const CylindersCard({
    super.key,
    required this.dive,
    required this.units,
    required this.settings,
    required this.sacUnit,
  });

  final Dive dive;
  final UnitFormatter units;
  final AppSettings settings;
  final SacUnit sacUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tankPressures = ref
        .watch(tankPressuresProvider(dive.id))
        .valueOrNull;
    final cylinderSacs =
        ref.watch(cylinderSacProvider(dive.id)).valueOrNull ??
        const <CylinderSac>[];
    final sacByTankId = {for (final c in cylinderSacs) c.tankId: c};
    final dataSources =
        ref.watch(diveDataSourcesProvider(dive.id)).valueOrNull ??
        const <DiveDataSource>[];
    // Only badge tanks once there's more than one source to disambiguate —
    // a single-source dive never needs attribution.
    final showSourceBadges = dataSources.length >= 2;
    final computerNames = _computerDisplayNames(context, dataSources);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_detail_section_cylinders,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            ...dive.tanks.asMap().entries.map(
              (entry) => _tankRow(
                context,
                index: entry.key,
                tank: entry.value,
                cylinderSac: sacByTankId[entry.value.id],
                tankPressures: tankPressures,
                sourceName:
                    showSourceBadges && entry.value.computerId != null
                    ? computerNames[entry.value.computerId]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tankRow(
    BuildContext context, {
    required int index,
    required DiveTank tank,
    required CylinderSac? cylinderSac,
    required Map<String, List<TankPressurePoint>>? tankPressures,
    required String? sourceName,
  }) {
    final theme = Theme.of(context);

    final pressures = _resolveTankPressures(
      tank: tank,
      tankPressures: tankPressures,
    );
    final startP = units.formatPressureValue(pressures.$1);
    final endP = units.formatPressureValue(pressures.$2);
    final pressureUsed = pressures.$1 != null && pressures.$2 != null
        ? pressures.$1! - pressures.$2!
        : null;
    final used = pressureUsed != null && pressureUsed > 0
        ? ' (${units.formatPressure(pressureUsed)} used)'
        : '';

    // Preset display name, falling back to formatted volume.
    final preset = tank.presetName != null
        ? TankPresets.byName(tank.presetName!)
        : null;
    final tankLabel =
        preset?.displayName ??
        (tank.volume != null
            ? units.formatTankVolume(
                tank.volume,
                tank.workingPressure,
                decimals: 1,
              )
            : null);
    final tankTitle = tank.name != null && tank.name!.isNotEmpty
        ? tank.name!
        : context.l10n.diveLog_tank_title(index + 1);

    final modDepth = units.formatDepth(tank.gasMix.mod(), decimals: 0);
    final mndValue = tank.gasMix.mnd(
      endLimit: settings.endLimit,
      o2Narcotic: settings.o2Narcotic,
    );
    final mndDepth = mndValue.isFinite
        ? units.formatDepth(mndValue, decimals: 0)
        : '--';
    final modMndText = context.l10n.diveLog_tank_modMndInfo(
      modDepth,
      mndDepth,
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(MdiIcons.divingScubaTank),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text('$tankTitle (${tank.gasMix.name})')),
          if (tankLabel != null) _volumeChip(theme, tankLabel),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$startP ${units.pressureSymbol} → '
            '$endP ${units.pressureSymbol}$used',
          ),
          Text(
            modMndText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
      ),
      trailing: _trailingBlock(theme, cylinderSac, sourceName),
    );
  }

  /// Small outlined chip carrying the preset/volume label (e.g. "AL80").
  Widget _volumeChip(ThemeData theme, String label) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Trailing column: attribution badge, SAC rate, gas used in liters.
  /// Returns null when there is nothing to show so the tile keeps its
  /// natural width.
  Widget? _trailingBlock(
    ThemeData theme,
    CylinderSac? cylinderSac,
    String? sourceName,
  ) {
    final hasSac = cylinderSac != null && cylinderSac.hasValidSac;
    if (!hasSac && sourceName == null) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (sourceName != null) FieldAttributionBadge(sourceName: sourceName),
        if (hasSac) ...[
          Text(
            _formatSac(cylinderSac),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          if (cylinderSac.gasUsedLiters != null)
            Text(
              '${units.convertVolume(cylinderSac.gasUsedLiters!).round()} '
              '${units.volumeSymbol} used',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }

  /// Formats the SAC value per the diver's SAC unit preference. L/min needs
  /// a tank volume; otherwise falls back to pressure-drop per minute.
  /// Only called when [CylinderSac.hasValidSac] is true.
  String _formatSac(CylinderSac cylinder) {
    if (sacUnit == SacUnit.litersPerMin && cylinder.sacVolume != null) {
      final value = units.convertVolume(cylinder.sacVolume!);
      return '${value.toStringAsFixed(1)} ${units.volumeSymbol}/min';
    }
    final value = units.convertPressure(cylinder.sacRate!);
    return '${value.toStringAsFixed(1)} ${units.pressureSymbol}/min';
  }

  /// Resolves start/end pressure: stored tank metadata wins, per-tank
  /// time-series fills any nulls.
  (double?, double?) _resolveTankPressures({
    required DiveTank tank,
    required Map<String, List<TankPressurePoint>>? tankPressures,
  }) {
    if (tankPressures != null && tankPressures.containsKey(tank.id)) {
      final points = tankPressures[tank.id]!;
      if (points.isNotEmpty) {
        return (
          tank.startPressure ?? points.first.pressure,
          tank.endPressure ?? points.last.pressure,
        );
      }
    }
    return (tank.startPressure, tank.endPressure);
  }

  /// computerId -> display name via the shared source-name resolver.
  Map<String, String> _computerDisplayNames(
    BuildContext context,
    List<DiveDataSource> dataSources,
  ) {
    final labels = SourceNameLabels(
      unknownComputer: context.l10n.diveLog_sources_unknownComputer,
      manualEntry: context.l10n.diveLog_sources_manualEntry,
      importedFile: context.l10n.diveLog_sources_importedFile,
      editedSuffix: context.l10n.diveLog_sources_editedSuffix,
    );
    return {
      for (final source in dataSources)
        if (source.computerId != null)
          source.computerId!: resolveSourceName(source, labels),
    };
  }
}
```

If `GasMix(o2: 32).name` renders something other than `EAN32`, or `UnitFormatter` is not a const constructor, adjust the TEST fixtures/expectations to the actual values — the widget code stays.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart`
Expected: all 7 tests PASS.

- [ ] **Step 5: Analyze, format, commit**

```bash
flutter analyze          # expect: No issues found!
dart format .            # expect: no changed files
git add lib/features/dive_log/presentation/widgets/cylinders_card.dart test/features/dive_log/presentation/widgets/cylinders_card_test.dart
git commit -m "feat(dive-detail): add unified CylindersCard widget"
```

---

### Task 3: Wire CylindersCard into the dive detail page, remove old builders

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (line refs are pre-change positions: section builder ~336; SAC-segments watches ~1683-1707; SAC-segments sub-block ~1917-1928; `_buildCylinderSacSection` ~2044-2149; `_formatCylinderSac` ~2152-2165; `_buildTanksSection` ~3825-3951; `_resolveTankPressures` ~3953-3981)

**Interfaces:**
- Consumes: `CylindersCard({required dive, required units, required settings, required sacUnit})` from Task 2; `sacUnitProvider` from `settings_providers.dart`.
- Produces: no new interfaces. The `sacSegments` section, with no segments available, now renders nothing (`SizedBox.shrink`) — the Cylinders card always carries per-tank SAC.

- [ ] **Step 1: Swap the `tanks` section builder**

In `_sectionBuilders`, replace:

```dart
      DiveDetailSectionId.tanks: () {
        if (dive.tanks.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          _buildTanksSection(context, ref, dive, units),
        ];
      },
```

with:

```dart
      DiveDetailSectionId.tanks: () {
        if (dive.tanks.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          CylindersCard(
            dive: dive,
            units: units,
            settings: settings,
            sacUnit: ref.watch(sacUnitProvider),
          ),
        ];
      },
```

Add the import `package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart` (grouped with the other widget imports).

- [ ] **Step 2: Strip the cylinder-SAC pieces out of `_buildSacSegmentsSection`**

(a) Delete the `isMultiTank` watch and the `cylinderSacAsync` watch:

```dart
    final isMultiTank =
        ref.watch(isMultiTankDiveProvider(dive.id)).valueOrNull ?? false;

    // Get cylinder SAC data for multi-tank dives
    final cylinderSacAsync = ref.watch(cylinderSacProvider(dive.id));
```

(keep the `hasGasSwitches` watch directly above — the segmentation selector still uses it).

(b) Simplify the no-segments early return from:

```dart
    if (analysis == null ||
        (analysis.sacSegments == null || analysis.sacSegments!.isEmpty)) {
      // Still show cylinder SAC if available
      if (isMultiTank && cylinderSacAsync.hasValue) {
        return _buildCylinderSacSection(
          context,
          ref,
          dive,
          cylinderSacAsync.value!,
          units,
          sacUnit,
        );
      }
      return const SizedBox.shrink();
    }
```

to:

```dart
    if (analysis == null ||
        (analysis.sacSegments == null || analysis.sacSegments!.isEmpty)) {
      return const SizedBox.shrink();
    }
```

(c) Delete the trailing sub-block near the end of the method (the `const SizedBox(height: 24),` after it stays):

```dart
        // Cylinder SAC subsection for multi-tank dives
        if (isMultiTank && cylinderSacAsync.hasValue) ...[
          const SizedBox(height: 16),
          _buildCylinderSacSection(
            context,
            ref,
            dive,
            cylinderSacAsync.value!,
            units,
            sacUnit,
          ),
        ],
```

- [ ] **Step 3: Delete the four dead methods**

Remove in full from `dive_detail_page.dart`:
- `Widget _buildCylinderSacSection(...)` (the whole method)
- `String _formatCylinderSac(...)`
- `Widget _buildTanksSection(...)`
- `(double?, double?) _resolveTankPressures(...)` (including its doc comment)

- [ ] **Step 4: Analyze and remove newly-unused imports**

Run: `flutter analyze`
Expected: `unused_import` warnings for anything only the deleted methods used (likely the `CylinderSac` entity import; possibly `TankPresets`). Remove exactly the flagged imports, re-run, expect: No issues found! Do NOT remove `gas_analysis_providers.dart` (the page still uses `cylinderSacProvider`? No — after this task the page no longer watches `cylinderSacProvider`, but it still uses `isMultiTankDiveProvider`? No — also removed. The page still imports that file for `selectedSegmentationProvider`/`hasGasSwitchesProvider`/etc.; let analyze be the judge — remove only what it flags).

- [ ] **Step 5: Run the page test suites**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart test/features/dive_log/presentation/pages/dive_detail_multi_source_test.dart`
Expected: all pass. (The section-config "renders tanks section" test only asserts the page renders; `CylindersCard` tolerates erroring providers via `valueOrNull`.) If a test fails on missing text like `Tanks`, update the expectation to `Cylinders`.

- [ ] **Step 6: Format, commit**

```bash
dart format .            # expect: no changed files
git add -A
git commit -m "feat(dive-detail): replace Tanks and SAC by Cylinder cards with CylindersCard"
```

---

### Task 4: Cleanup — dead widget, dead provider, obsolete l10n keys

**Files:**
- Delete: `lib/features/dive_log/presentation/widgets/cylinder_sac_card.dart`
- Modify: `lib/features/dive_log/presentation/providers/gas_analysis_providers.dart` (remove `cylinderSacExpandedProvider`)
- Modify: all 11 `lib/l10n/arb/app_*.arb` files (remove 3 obsolete keys)

**Interfaces:**
- Consumes: Task 3 must be complete (nothing may reference the removed symbols/keys).
- Produces: nothing — pure deletion.

- [ ] **Step 1: Verify the symbols are unreferenced**

```bash
grep -rn "CylinderSacCard\|CylinderSacList" lib/ test/ | grep -v "widgets/cylinder_sac_card.dart"
grep -rn "cylinderSacExpandedProvider" lib/ test/ | grep -v "gas_analysis_providers.dart"
grep -rn "diveLog_detail_section_sacByCylinder\|diveLog_detail_section_tanks\b\|diveLog_detail_tankCount" lib/ test/ | grep -v "lib/l10n"
```

Expected: all three commands print nothing. If any prints a hit, STOP — Task 3 missed a reference; fix that first.

- [ ] **Step 2: Delete the dead code**

```bash
git rm lib/features/dive_log/presentation/widgets/cylinder_sac_card.dart
```

In `gas_analysis_providers.dart`, delete the `cylinderSacExpandedProvider` declaration (a one-line `StateProvider<bool>((ref) => true);` plus its doc comment if any).

- [ ] **Step 3: Remove obsolete l10n keys from all 11 ARB files**

From every `lib/l10n/arb/app_*.arb`, remove these entries (and the `"@diveLog_detail_tankCount"` metadata block in `app_en.arb`):
- `diveLog_detail_section_sacByCylinder`
- `diveLog_detail_section_tanks`
- `diveLog_detail_tankCount`

- [ ] **Step 4: Regenerate localizations and verify nothing broke**

```bash
flutter gen-l10n         # expect: exit 0
flutter analyze          # expect: No issues found!  (any missing-getter error means a straggler reference)
```

- [ ] **Step 5: Run the affected test files**

Run: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart test/core/constants/dive_detail_sections_test.dart`
Expected: all pass.

- [ ] **Step 6: Format, commit**

```bash
dart format .            # expect: no changed files
git add -A
git commit -m "chore(dive-detail): remove dead cylinder SAC card code and obsolete l10n keys"
```

---

## Final Verification (after all tasks)

- [ ] `flutter analyze` — No issues found!
- [ ] `dart format .` — no changed files
- [ ] Targeted suites green: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart test/features/settings/presentation/pages/dive_detail_sections_page_test.dart test/core/constants/dive_detail_sections_test.dart`
- [ ] Manual smoke (optional, macOS): open a multi-tank dive — one Cylinders card with per-tank SAC in trailing position, no separate SAC by Cylinder block; open a single-tank dive — SAC visible on the row; SAC Rate by Segment section unchanged above.
