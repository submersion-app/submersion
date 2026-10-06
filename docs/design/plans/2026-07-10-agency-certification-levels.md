# Agency-Dependent Certification Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the certification level dropdown depend on the selected agency (issue #546), with agency always presented before level, on both the certification and buddy edit forms.

**Architecture:** Extend the `CertificationLevel` enum with agency-specific values (CMAS star grades, BSAC grades, GUE ratings, generic/tech additions) and add a `CertificationLevelCatalog` that maps each `CertificationAgency` to its progression ladder plus a shared specialty set. The two edit pages build their level dropdown items from the catalog. Levels remain persisted as enum-name text - no schema change, no migration.

**Tech Stack:** Flutter 3.x, Riverpod, Drift (untouched), flutter_test widget tests with the repo's real-in-memory-DB harness.

**Spec:** `docs/superpowers/specs/2026-07-10-agency-certification-levels-design.md`

## Global Constraints

- Work happens in worktree branch `worktree-issue-546-agency-cert-levels`; all paths below are relative to the worktree root `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-546-agency-cert-levels/`.
- Existing `CertificationLevel` values must NOT be renamed or reordered relative to each other; their `.name` is a persistence format (DB text, UDDF, sync). New values are inserted between `techDiver` and `other` so `other` stays last.
- No database schema change, no new l10n strings (agency level names are brand names and stay English in `displayName`).
- `dart format .` must produce no diff before every commit (pre-push hook enforces it). NOTE: the pre-push hook runs against the MAIN tree, not this worktree - do not push in this plan; pushing happens at PR time with `--no-verify` if needed.
- No emojis in code or docs. The star character `★` (U+2605) used in CMAS display names is a typographic symbol, not an emoji, and is intentional.
- Run tests per specific file (`flutter test <file>`), never the whole suite (timeout risk).
- Inside `testWidgets`, wrap any Drift/repository `await` that happens AFTER the first `pumpWidget` in `tester.runAsync(() => ...)` (fake-async deadlock trap). Repository calls made before `pumpWidget` follow the existing direct-await pattern.
- Dropdown menu overlays duplicate the selected item's label; tap menu entries with `find.text(label).last`, and `ensureVisible` a dropdown before tapping it.

---

### Task 1: Enum extension + CertificationLevelCatalog

**Files:**
- Modify: `lib/core/constants/enums.dart:141-164` (the `CertificationLevel` enum)
- Create: `lib/core/constants/certification_levels.dart`
- Test: `test/core/constants/certification_levels_test.dart`

**Interfaces:**
- Consumes: `CertificationAgency`, `CertificationLevel` from `package:submersion/core/constants/enums.dart`.
- Produces (used by Tasks 2 and 3):
  - `CertificationLevelCatalog.levelsFor(CertificationAgency? agency, {CertificationLevel? ensure})` -> `List<CertificationLevel>` - full dropdown list: agency ladder, then non-duplicate specialties, then (if `ensure` is set, not `other`, and missing) `ensure`, then always `CertificationLevel.other` last. `null` agency behaves like `CertificationAgency.other`.
  - `CertificationLevelCatalog.ladderFor(CertificationAgency? agency)` -> `List<CertificationLevel>`
  - `CertificationLevelCatalog.specialties` -> `List<CertificationLevel>` (const)
  - New enum values listed in Step 3 (e.g. `CertificationLevel.cmas2StarDiver.displayName == '2★ Diver'`).

- [ ] **Step 1: Write the failing test**

Create `test/core/constants/certification_levels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  group('CertificationLevelCatalog.levelsFor', () {
    test(
      'every agency and null yields a non-empty, duplicate-free list '
      'ending in other',
      () {
        final agencies = <CertificationAgency?>[
          ...CertificationAgency.values,
          null,
        ];
        for (final agency in agencies) {
          final levels = CertificationLevelCatalog.levelsFor(agency);
          expect(levels, isNotEmpty, reason: 'agency=$agency');
          expect(
            levels.last,
            CertificationLevel.other,
            reason: 'agency=$agency',
          );
          expect(
            levels.toSet().length,
            levels.length,
            reason: 'agency=$agency has duplicates',
          );
        }
      },
    );

    test('display names within each agency list are unique', () {
      final agencies = <CertificationAgency?>[
        ...CertificationAgency.values,
        null,
      ];
      for (final agency in agencies) {
        final names = CertificationLevelCatalog.levelsFor(
          agency,
        ).map((l) => l.displayName).toList();
        expect(
          names.toSet().length,
          names.length,
          reason: 'agency=$agency has duplicate display names',
        );
      }
    });

    test('CMAS ladder is exactly the nine grades from issue #546, in order', () {
      final levels = CertificationLevelCatalog.levelsFor(
        CertificationAgency.cmas,
      );
      expect(levels.sublist(0, 9), const [
        CertificationLevel.cmas1StarDiver,
        CertificationLevel.cmas2StarDiver,
        CertificationLevel.cmas3StarDiver,
        CertificationLevel.cmas4StarDiver,
        CertificationLevel.cmas3StarDiverAssistantInstructor,
        CertificationLevel.cmas4StarDiverAssistantInstructor,
        CertificationLevel.cmas1StarInstructor,
        CertificationLevel.cmas2StarInstructor,
        CertificationLevel.cmas3StarInstructor,
      ]);
      // Generic recreational ladder is excluded for CMAS...
      expect(levels, isNot(contains(CertificationLevel.advancedOpenWater)));
      // ...but shared specialties remain available.
      expect(levels, contains(CertificationLevel.nitrox));
    });

    test('tech agency ladder/specialty overlap is deduplicated', () {
      final levels = CertificationLevelCatalog.levelsFor(
        CertificationAgency.tdi,
      );
      expect(
        levels.where((l) => l == CertificationLevel.nitrox).length,
        1,
      );
      // Ladder order wins: nitrox appears first, not in specialty position.
      expect(levels.first, CertificationLevel.nitrox);
    });

    test('ensure appends an out-of-catalog level before other', () {
      final levels = CertificationLevelCatalog.levelsFor(
        CertificationAgency.cmas,
        ensure: CertificationLevel.advancedOpenWater,
      );
      expect(levels, contains(CertificationLevel.advancedOpenWater));
      expect(levels.last, CertificationLevel.other);
    });

    test('ensure of an in-catalog level does not duplicate it', () {
      final levels = CertificationLevelCatalog.levelsFor(
        CertificationAgency.cmas,
        ensure: CertificationLevel.cmas2StarDiver,
      );
      expect(
        levels.where((l) => l == CertificationLevel.cmas2StarDiver).length,
        1,
      );
    });

    test('null agency offers the full generic list', () {
      final levels = CertificationLevelCatalog.levelsFor(null);
      expect(levels, contains(CertificationLevel.openWater));
      expect(levels, contains(CertificationLevel.advancedOpenWater));
      expect(levels, contains(CertificationLevel.courseDirector));
      expect(levels, contains(CertificationLevel.nitrox));
      expect(levels, isNot(contains(CertificationLevel.cmas1StarDiver)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/certification_levels_test.dart`
Expected: FAIL to compile - `certification_levels.dart` does not exist and enum values like `cmas1StarDiver` are undefined.

- [ ] **Step 3: Extend the enum**

In `lib/core/constants/enums.dart`, the `CertificationLevel` enum currently ends:

```dart
  techDiver('Tech Diver'),
  other('Other');
```

Replace those two lines with:

```dart
  techDiver('Tech Diver'),
  // Generic ladder additions (issue #546)
  masterDiver('Master Diver'),
  assistantInstructor('Assistant Instructor'),
  // Technical ladder additions
  extendedRange('Extended Range'),
  advancedTrimix('Advanced Trimix'),
  // CMAS star grades
  cmas1StarDiver('1★ Diver'),
  cmas2StarDiver('2★ Diver'),
  cmas3StarDiver('3★ Diver'),
  cmas4StarDiver('4★ Diver'),
  cmas3StarDiverAssistantInstructor('3★ Diver - Assistant Instructor'),
  cmas4StarDiverAssistantInstructor('4★ Diver - Assistant Instructor'),
  cmas1StarInstructor('1★ Instructor'),
  cmas2StarInstructor('2★ Instructor'),
  cmas3StarInstructor('3★ Instructor'),
  // BSAC grades
  bsacOceanDiver('Ocean Diver'),
  bsacSportsDiver('Sports Diver'),
  bsacDiveLeader('Dive Leader'),
  bsacAdvancedDiver('Advanced Diver'),
  bsacFirstClassDiver('First Class Diver'),
  bsacOpenWaterInstructor('Open Water Instructor'),
  bsacAdvancedInstructor('Advanced Instructor'),
  bsacNationalInstructor('National Instructor'),
  // GUE ratings
  gueFundamentals('Fundamentals'),
  gueRec1('Rec 1'),
  gueRec2('Rec 2'),
  gueRec3('Rec 3'),
  gueTech1('Tech 1'),
  gueTech2('Tech 2'),
  gueCave1('Cave 1'),
  gueCave2('Cave 2'),
  gueDpv('DPV'),
  other('Other');
```

Display names deliberately omit the agency prefix - the dropdown is already scoped by the agency field above it, and buddy/detail surfaces show agency alongside level.

- [ ] **Step 4: Create the catalog**

Create `lib/core/constants/certification_levels.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';

/// Agency-specific certification level catalogs (issue #546).
///
/// Each agency exposes its core progression ladder plus the cross-agency
/// [specialties] set. Levels are still persisted as enum-name text, so this
/// catalog only shapes what the dropdowns offer - it never restricts what
/// can be stored or parsed.
class CertificationLevelCatalog {
  CertificationLevelCatalog._();

  /// Specialty levels offered by essentially every agency.
  static const List<CertificationLevel> specialties = [
    CertificationLevel.nitrox,
    CertificationLevel.advancedNitrox,
    CertificationLevel.decompression,
    CertificationLevel.trimix,
    CertificationLevel.cavern,
    CertificationLevel.cave,
    CertificationLevel.wreck,
    CertificationLevel.sidemount,
    CertificationLevel.rebreather,
    CertificationLevel.techDiver,
  ];

  static const List<CertificationLevel> _genericLadder = [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
    CertificationLevel.masterDiver,
    CertificationLevel.diveMaster,
    CertificationLevel.assistantInstructor,
    CertificationLevel.instructor,
    CertificationLevel.masterInstructor,
    CertificationLevel.courseDirector,
  ];

  static const List<CertificationLevel> _ssiLadder = [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
    CertificationLevel.masterDiver,
    CertificationLevel.diveMaster,
    CertificationLevel.assistantInstructor,
    CertificationLevel.instructor,
  ];

  static const List<CertificationLevel> _nauiSdiLadder = [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
    CertificationLevel.masterDiver,
    CertificationLevel.diveMaster,
    CertificationLevel.assistantInstructor,
    CertificationLevel.instructor,
    CertificationLevel.courseDirector,
  ];

  static const List<CertificationLevel> _raidLadder = [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
    CertificationLevel.masterDiver,
    CertificationLevel.diveMaster,
    CertificationLevel.instructor,
  ];

  static const List<CertificationLevel> _techLadder = [
    CertificationLevel.nitrox,
    CertificationLevel.advancedNitrox,
    CertificationLevel.decompression,
    CertificationLevel.extendedRange,
    CertificationLevel.trimix,
    CertificationLevel.advancedTrimix,
    CertificationLevel.cavern,
    CertificationLevel.cave,
    CertificationLevel.rebreather,
    CertificationLevel.instructor,
  ];

  static const List<CertificationLevel> _gueLadder = [
    CertificationLevel.gueFundamentals,
    CertificationLevel.gueRec1,
    CertificationLevel.gueRec2,
    CertificationLevel.gueRec3,
    CertificationLevel.gueTech1,
    CertificationLevel.gueTech2,
    CertificationLevel.gueCave1,
    CertificationLevel.gueCave2,
    CertificationLevel.gueDpv,
    CertificationLevel.instructor,
  ];

  static const List<CertificationLevel> _bsacLadder = [
    CertificationLevel.bsacOceanDiver,
    CertificationLevel.bsacSportsDiver,
    CertificationLevel.bsacDiveLeader,
    CertificationLevel.bsacAdvancedDiver,
    CertificationLevel.bsacFirstClassDiver,
    CertificationLevel.bsacOpenWaterInstructor,
    CertificationLevel.bsacAdvancedInstructor,
    CertificationLevel.bsacNationalInstructor,
  ];

  static const List<CertificationLevel> _cmasLadder = [
    CertificationLevel.cmas1StarDiver,
    CertificationLevel.cmas2StarDiver,
    CertificationLevel.cmas3StarDiver,
    CertificationLevel.cmas4StarDiver,
    CertificationLevel.cmas3StarDiverAssistantInstructor,
    CertificationLevel.cmas4StarDiverAssistantInstructor,
    CertificationLevel.cmas1StarInstructor,
    CertificationLevel.cmas2StarInstructor,
    CertificationLevel.cmas3StarInstructor,
  ];

  /// Core progression ladder for an agency, in rank order. A null agency
  /// (possible on buddies) behaves like [CertificationAgency.other].
  static List<CertificationLevel> ladderFor(CertificationAgency? agency) =>
      switch (agency) {
        CertificationAgency.padi => _genericLadder,
        CertificationAgency.ssi => _ssiLadder,
        CertificationAgency.naui ||
        CertificationAgency.sdi => _nauiSdiLadder,
        CertificationAgency.raid => _raidLadder,
        CertificationAgency.tdi ||
        CertificationAgency.iantd ||
        CertificationAgency.psai => _techLadder,
        CertificationAgency.gue => _gueLadder,
        CertificationAgency.bsac => _bsacLadder,
        CertificationAgency.cmas => _cmasLadder,
        CertificationAgency.other || null => _genericLadder,
      };

  /// Full dropdown list for an agency: ladder, then specialties not already
  /// on the ladder, then [CertificationLevel.other] last. When [ensure] is
  /// provided and missing from the list (a stored value from another
  /// agency's catalog), it is inserted before `other` so existing data
  /// always renders.
  static List<CertificationLevel> levelsFor(
    CertificationAgency? agency, {
    CertificationLevel? ensure,
  }) {
    final ladder = ladderFor(agency);
    final result = [
      ...ladder,
      ...specialties.where((s) => !ladder.contains(s)),
    ];
    if (ensure != null &&
        ensure != CertificationLevel.other &&
        !result.contains(ensure)) {
      result.add(ensure);
    }
    result.add(CertificationLevel.other);
    return result;
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/constants/certification_levels_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/core/constants/enums.dart lib/core/constants/certification_levels.dart test/core/constants/certification_levels_test.dart
git commit -m "feat(certifications): add agency-specific certification levels and catalog (#546)"
```

---

### Task 2: Certification edit page - agency-dependent level dropdown

**Files:**
- Modify: `lib/features/certifications/presentation/pages/certification_edit_page.dart:332-383` (agency + level dropdowns)
- Test: `test/features/certifications/presentation/pages/certification_edit_agency_level_test.dart` (new)

**Interfaces:**
- Consumes: `CertificationLevelCatalog.levelsFor(agency, ensure: level)` from Task 1.
- Produces: no new API - behavior change only. Agency dropdown already sits above level on this page; only filtering/reset is added.

- [ ] **Step 1: Write the failing tests**

Create `test/features/certifications/presentation/pages/certification_edit_agency_level_test.dart`. The harness mirrors `certification_edit_instructor_test.dart` (same directory): real in-memory DB via `setUpTestDatabase()`, base provider overrides via `getBaseOverrides()`, embedded page inside a localized `MaterialApp`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late CertificationRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = CertificationRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Widget> buildHarness({String? certificationId}) async {
    final overrides = await getBaseOverrides();
    return ProviderScope(
      overrides: [
        ...overrides,
        certificationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CertificationEditPage(
            certificationId: certificationId,
            embedded: true,
          ),
        ),
      ),
    );
  }

  Finder agencyDropdown() =>
      find.byType(DropdownButtonFormField<CertificationAgency>);
  Finder levelDropdown() =>
      find.byType(DropdownButtonFormField<CertificationLevel>);

  Future<void> selectFromDropdown(
    WidgetTester tester,
    Finder dropdown,
    String optionLabel,
  ) async {
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    // The overlay duplicates the selected item's label; .last hits the menu.
    await tester.tap(find.text(optionLabel).last);
    await tester.pumpAndSettle();
  }

  testWidgets('agency dropdown appears above level dropdown', (tester) async {
    await tester.pumpWidget(await buildHarness());
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(agencyDropdown()).dy,
      lessThan(tester.getTopLeft(levelDropdown()).dy),
    );
  });

  testWidgets('selecting CMAS restricts levels to CMAS grades + specialties', (
    tester,
  ) async {
    await tester.pumpWidget(await buildHarness());
    await tester.pumpAndSettle();

    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('2★ Diver'), findsOneWidget);
    expect(find.text('Nitrox'), findsOneWidget);
    expect(find.text('Advanced Open Water'), findsNothing);
  });

  testWidgets('switching agency resets an incompatible level', (tester) async {
    await tester.pumpWidget(await buildHarness());
    await tester.pumpAndSettle();

    // Default agency is PADI; pick a PADI-ladder level.
    await selectFromDropdown(
      tester,
      levelDropdown(),
      'Advanced Open Water',
    );
    expect(find.text('Advanced Open Water'), findsOneWidget);

    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    expect(find.text('Advanced Open Water'), findsNothing);
    expect(find.text('Not specified'), findsOneWidget);
  });

  testWidgets('switching agency keeps a compatible (specialty) level', (
    tester,
  ) async {
    await tester.pumpWidget(await buildHarness());
    await tester.pumpAndSettle();

    await selectFromDropdown(tester, levelDropdown(), 'Nitrox');
    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    expect(find.text('Nitrox'), findsOneWidget);
  });

  testWidgets(
    'existing record with out-of-catalog level renders and survives save',
    (tester) async {
      final now = DateTime(2024);
      final cert = await repository.createCertification(
        Certification(
          id: '',
          name: 'Legacy CMAS card',
          agency: CertificationAgency.cmas,
          level: CertificationLevel.advancedOpenWater,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(await buildHarness(certificationId: cert.id));
      await tester.pumpAndSettle();

      // Stored level renders even though it is not in the CMAS catalog.
      expect(find.text('Advanced Open Water'), findsOneWidget);

      // Save without touching agency or level; the value must survive.
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(seconds: 1));

      final saved = await tester.runAsync(
        () => repository.getCertificationById(cert.id),
      );
      expect(saved!.level, CertificationLevel.advancedOpenWater);
      expect(saved.agency, CertificationAgency.cmas);
    },
  );
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/certifications/presentation/pages/certification_edit_agency_level_test.dart`
Expected: 'agency appears above level' PASSES (already true on this page); the CMAS filtering, reset, and keep-specialty tests FAIL (full flat list is shown, nothing resets). The out-of-catalog test may pass trivially pre-change; it exists to guard the new code.

- [ ] **Step 3: Implement the dependent dropdown**

In `lib/features/certifications/presentation/pages/certification_edit_page.dart`:

Add the import (with the other `core/constants` import):

```dart
import 'package:submersion/core/constants/certification_levels.dart';
```

Replace the agency dropdown's `onChanged` (currently lines 345-352):

```dart
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _agency = value;
                          // A level from another agency's catalog is reset -
                          // a visible consequence of the user's own switch.
                          if (_level != null &&
                              !CertificationLevelCatalog.levelsFor(
                                value,
                              ).contains(_level)) {
                            _level = null;
                          }
                          _hasChanges = true;
                        });
                      }
                    },
```

Replace the level dropdown (currently lines 356-383) with:

```dart
                  // Level dropdown (options depend on the selected agency)
                  DropdownButtonFormField<CertificationLevel>(
                    // DropdownButtonFormField keeps its selection in its own
                    // FormFieldState; the key forces a remount when the
                    // agency changes or the level is reset externally, so
                    // initialValue is re-read.
                    key: ValueKey('level-${_agency.name}-${_level?.name}'),
                    initialValue: _level,
                    decoration: InputDecoration(
                      labelText: context.l10n.certifications_edit_label_level,
                      prefixIcon: const Icon(Icons.stairs),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          context.l10n.certifications_edit_level_notSpecified,
                        ),
                      ),
                      ...CertificationLevelCatalog.levelsFor(
                        _agency,
                        ensure: _level,
                      ).map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level.displayName),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _level = value;
                        _hasChanges = true;
                      });
                    },
                  ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/certifications/presentation/pages/certification_edit_agency_level_test.dart`
Expected: PASS (5 tests).

Also run the neighboring page tests to catch regressions:

Run: `flutter test test/features/certifications/presentation/pages/`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/certifications/presentation/pages/certification_edit_page.dart test/features/certifications/presentation/pages/certification_edit_agency_level_test.dart
git commit -m "feat(certifications): filter level dropdown by selected agency (#546)"
```

---

### Task 3: Buddy edit page - agency before level + dependent dropdown

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart:462-585` (the two certification dropdown blocks)
- Test: `test/features/buddies/presentation/pages/buddy_edit_cert_fields_test.dart` (new)

**Interfaces:**
- Consumes: `CertificationLevelCatalog.levelsFor(agency, ensure: level)` from Task 1. Note `_certAgency` is `CertificationAgency?` - `levelsFor` accepts null (generic list).
- Produces: no new API. Merge-cycle buttons (`_mergeCtrl`) keep their existing behavior; a merge-cycled level not in the current agency's catalog stays visible via `ensure`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/buddies/presentation/pages/buddy_edit_cert_fields_test.dart`, modeled on `buddy_edit_roles_test.dart` (same directory - real DB, diver row, `SharedPreferences` mock, `MockSettingsNotifier`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddyRepo;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    buddyRepo = BuddyRepository();

    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Widget harness({String? buddyId}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BuddyEditPage(buddyId: buddyId, embedded: true),
        ),
      ),
    );
  }

  Finder agencyDropdown() =>
      find.byType(DropdownButtonFormField<CertificationAgency>);
  Finder levelDropdown() =>
      find.byType(DropdownButtonFormField<CertificationLevel>);

  Future<void> selectFromDropdown(
    WidgetTester tester,
    Finder dropdown,
    String optionLabel,
  ) async {
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(optionLabel).last);
    await tester.pumpAndSettle();
  }

  testWidgets('agency dropdown appears above level dropdown', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(agencyDropdown()).dy,
      lessThan(tester.getTopLeft(levelDropdown()).dy),
    );
  });

  testWidgets('selecting CMAS agency restricts the level list', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('2★ Diver'), findsOneWidget);
    expect(find.text('Advanced Open Water'), findsNothing);
  });

  testWidgets('no agency selected offers the generic level list', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('Advanced Open Water'), findsOneWidget);
    expect(find.text('2★ Diver'), findsNothing);
  });

  testWidgets('switching agency resets an incompatible level', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await selectFromDropdown(
      tester,
      levelDropdown(),
      'Advanced Open Water',
    );
    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    expect(find.text('Advanced Open Water'), findsNothing);
  });

  testWidgets('existing buddy with out-of-catalog level still renders it', (
    tester,
  ) async {
    final now = DateTime(2024);
    final buddy = await buddyRepo.createBuddy(
      Buddy(
        id: '',
        name: 'Alice',
        certificationAgency: CertificationAgency.cmas,
        certificationLevel: CertificationLevel.advancedOpenWater,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(harness(buddyId: buddy.id));
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('Advanced Open Water'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/buddies/presentation/pages/buddy_edit_cert_fields_test.dart`
Expected: 'agency above level' FAILS (level currently renders first); 'restricts the level list' and 'resets an incompatible level' FAIL. The generic-list and out-of-catalog tests may pass pre-change; they guard the new code.

- [ ] **Step 3: Implement**

In `lib/features/buddies/presentation/pages/buddy_edit_page.dart`:

Add the import:

```dart
import 'package:submersion/core/constants/certification_levels.dart';
```

The certification section (after the `buddies_section_certification` header, lines 462-585) currently renders: level `Row` + level merge-source label + `SizedBox(height: 16)` + agency `Row` + agency merge-source label + `SizedBox(height: 24)`.

Reorder to: agency `Row` + agency merge-source label + `SizedBox(height: 16)` + level `Row` + level merge-source label + `SizedBox(height: 24)`. Move the blocks whole (each `Row` keeps its merge-cycle button and its `if (widget.isMerging ...)` label block); only the two `SizedBox` spacers stay in place.

Then update the two dropdowns inside the moved blocks.

Agency dropdown `onChanged` (was lines 548-553) becomes:

```dart
                    onChanged: (value) {
                      setState(() {
                        _certAgency = value;
                        if (_certLevel != null &&
                            !CertificationLevelCatalog.levelsFor(
                              value,
                            ).contains(_certLevel)) {
                          _certLevel = null;
                        }
                        _hasChanges = true;
                      });
                    },
```

Level dropdown: change its `key` so it also remounts when the agency changes (the page already uses value-based keys for merge cycling), and build its items from the catalog. Replace:

```dart
                  child: DropdownButtonFormField<CertificationLevel>(
                    key: ValueKey(_certLevel),
```

with:

```dart
                  child: DropdownButtonFormField<CertificationLevel>(
                    key: ValueKey(
                      'certLevel-${_certAgency?.name}-${_certLevel?.name}',
                    ),
```

and replace its items list:

```dart
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(context.l10n.buddies_label_notSpecified),
                      ),
                      ...CertificationLevelCatalog.levelsFor(
                        _certAgency,
                        ensure: _certLevel,
                      ).map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level.displayName),
                        );
                      }),
                    ],
```

The `ensure: _certLevel` argument keeps merge-cycled or previously stored levels selectable even when they are not in the current agency's catalog (a `DropdownButtonFormField` whose value is missing from its items throws an assertion).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/buddies/presentation/pages/buddy_edit_cert_fields_test.dart`
Expected: PASS (5 tests).

Also run the neighboring buddy page tests (merge cycling must be unaffected):

Run: `flutter test test/features/buddies/presentation/pages/`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/buddies/presentation/pages/buddy_edit_page.dart test/features/buddies/presentation/pages/buddy_edit_cert_fields_test.dart
git commit -m "feat(buddies): agency-first certification fields with dependent level list (#546)"
```

---

### Task 4: Whole-project verification

**Files:**
- Modify: none expected (fixups only if analyze/format flag something)

**Interfaces:**
- Consumes: everything above.
- Produces: a branch ready for PR.

- [ ] **Step 1: Format the whole repo**

Run: `dart format .`
Expected: "0 changed" (or reformat + amend the relevant commit).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found!". Do NOT pipe through `head`/`tail` - masked exit codes have hidden real failures before.

- [ ] **Step 3: Run the affected test files**

```bash
flutter test \
  test/core/constants/certification_levels_test.dart \
  test/core/constants/enums_test.dart \
  test/features/certifications/presentation/pages/ \
  test/features/buddies/presentation/pages/ \
  test/features/certifications/data/ \
  test/features/buddies/data/
```

Expected: all PASS.

- [ ] **Step 4: Commit any fixups**

Only if Steps 1-3 required changes:

```bash
git add -A
git commit -m "chore: format/analyze fixups for #546"
```
