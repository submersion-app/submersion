# Dive Detail Section Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users toggle visibility and reorder sections on the Dive Details page via a drag-and-drop settings UI, persisted per-diver in the database.

**Architecture:** A JSON column on the existing `diver_settings` table stores an ordered list of `{id, visible}` objects. A new enum + model pair defines section IDs and config. The dive detail page reads the config from `settingsProvider` and renders sections in the user-defined order via a registry map. A new settings sub-page provides drag-and-drop reordering with toggle switches.

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod (StateNotifier), go_router, ReorderableListView

**Spec:** `docs/superpowers/specs/2026-03-27-dive-detail-section-config-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/core/constants/dive_detail_sections.dart` | `DiveDetailSectionId` enum, `DiveDetailSectionConfig` model, defaults, JSON serialization |
| Modify | `lib/core/database/database.dart:575-724` | Add `diveDetailSections` nullable TEXT column to `DiverSettings` table |
| Modify | `lib/core/database/database.dart:1241` | Bump schema version 55 → 56 |
| Modify | `lib/core/database/database.dart:2467-2472` | Add v56 migration |
| Modify | `lib/features/settings/presentation/providers/settings_providers.dart:61-327` | Add `diveDetailSections` field to `AppSettings`, update `copyWith` |
| Modify | `lib/features/settings/presentation/providers/settings_providers.dart:551-1080` | Add `setDiveDetailSections()` and `resetDiveDetailSections()` to `SettingsNotifier` |
| Modify | `lib/features/settings/data/repositories/diver_settings_repository.dart` | Wire new column in create/update/map methods |
| Create | `lib/features/settings/presentation/pages/dive_detail_sections_page.dart` | `ReorderableListView` settings sub-page |
| Modify | `lib/features/settings/presentation/pages/appearance_page.dart:359` | Add "Dive Details" section with navigation tile |
| Modify | `lib/core/router/app_router.dart:725-811` | Add route for `dive-detail-sections` |
| Modify | `lib/features/dive_log/presentation/pages/dive_detail_page.dart:226-383` | Section registry + config-driven render loop |
| Create | `test/core/constants/dive_detail_sections_test.dart` | Unit tests for model, serialization, defaults |
| Modify | `test/features/settings/presentation/providers/settings_providers_test.dart` | Tests for AppSettings new field |
| Create | `test/features/settings/presentation/pages/dive_detail_sections_page_test.dart` | Widget tests for settings sub-page |

---

## Task 1: DiveDetailSectionId Enum and DiveDetailSectionConfig Model

**Files:**
- Create: `lib/core/constants/dive_detail_sections.dart`
- Test: `test/core/constants/dive_detail_sections_test.dart`

- [ ] **Step 1: Write failing tests for the model**

Create `test/core/constants/dive_detail_sections_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';

void main() {
  group('DiveDetailSectionId', () {
    test('has 17 values', () {
      expect(DiveDetailSectionId.values.length, 17);
    });

    test('values match expected IDs', () {
      expect(DiveDetailSectionId.values.first, DiveDetailSectionId.decoO2);
      expect(DiveDetailSectionId.values.last, DiveDetailSectionId.dataSources);
    });
  });

  group('DiveDetailSectionConfig', () {
    test('constructs with required fields', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.decoO2,
        visible: true,
      );
      expect(config.id, DiveDetailSectionId.decoO2);
      expect(config.visible, true);
    });

    test('copyWith updates visible', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.tanks,
        visible: true,
      );
      final updated = config.copyWith(visible: false);
      expect(updated.id, DiveDetailSectionId.tanks);
      expect(updated.visible, false);
    });

    test('toJson serializes correctly', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.environment,
        visible: false,
      );
      final json = config.toJson();
      expect(json['id'], 'environment');
      expect(json['visible'], false);
    });

    test('fromJson deserializes correctly', () {
      final config = DiveDetailSectionConfig.fromJson({
        'id': 'environment',
        'visible': false,
      });
      expect(config.id, DiveDetailSectionId.environment);
      expect(config.visible, false);
    });

    test('fromJson ignores unknown section IDs', () {
      final config = DiveDetailSectionConfig.tryFromJson({
        'id': 'nonexistent',
        'visible': true,
      });
      expect(config, isNull);
    });
  });

  group('DiveDetailSectionConfig list serialization', () {
    test('sectionsToJson produces valid JSON string', () {
      const sections = [
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoO2,
          visible: true,
        ),
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.details,
          visible: false,
        ),
      ];
      final jsonStr = DiveDetailSectionConfig.sectionsToJson(sections);
      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded.length, 2);
      expect(decoded[0]['id'], 'decoO2');
      expect(decoded[1]['visible'], false);
    });

    test('sectionsFromJson parses valid JSON string', () {
      const jsonStr =
          '[{"id":"decoO2","visible":true},{"id":"details","visible":false}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      expect(sections.length, 2);
      expect(sections[0].id, DiveDetailSectionId.decoO2);
      expect(sections[1].visible, false);
    });

    test('sectionsFromJson skips unknown section IDs', () {
      const jsonStr =
          '[{"id":"decoO2","visible":true},{"id":"unknown","visible":true},{"id":"details","visible":false}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      expect(sections.length, 2);
    });

    test('sectionsFromJson returns defaults for null input', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson(null);
      expect(sections.length, 17);
      expect(sections.every((s) => s.visible), true);
    });

    test('sectionsFromJson returns defaults for empty string', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson('');
      expect(sections.length, 17);
    });

    test('sectionsFromJson returns defaults for invalid JSON', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson('not json');
      expect(sections.length, 17);
    });
  });

  group('defaultSections', () {
    test('contains all 17 section IDs', () {
      expect(DiveDetailSectionConfig.defaultSections.length, 17);
      final ids =
          DiveDetailSectionConfig.defaultSections.map((s) => s.id).toSet();
      expect(ids, DiveDetailSectionId.values.toSet());
    });

    test('all sections are visible by default', () {
      expect(
        DiveDetailSectionConfig.defaultSections.every((s) => s.visible),
        true,
      );
    });

    test('order matches enum declaration order', () {
      for (var i = 0; i < DiveDetailSectionId.values.length; i++) {
        expect(
          DiveDetailSectionConfig.defaultSections[i].id,
          DiveDetailSectionId.values[i],
        );
      }
    });
  });

  group('ensureAllSections', () {
    test('appends missing sections from a saved config', () {
      const saved = [
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoO2,
          visible: true,
        ),
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.details,
          visible: false,
        ),
      ];
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      expect(result.length, 17);
      // First two preserve saved order and visibility
      expect(result[0].id, DiveDetailSectionId.decoO2);
      expect(result[0].visible, true);
      expect(result[1].id, DiveDetailSectionId.details);
      expect(result[1].visible, false);
      // Remaining 15 are appended visible
      expect(result.sublist(2).every((s) => s.visible), true);
    });

    test('returns saved config unchanged when all sections present', () {
      final saved = DiveDetailSectionConfig.defaultSections;
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      expect(result.length, 17);
      for (var i = 0; i < 17; i++) {
        expect(result[i].id, saved[i].id);
        expect(result[i].visible, saved[i].visible);
      }
    });
  });

  group('DiveDetailSectionId metadata', () {
    test('displayName returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.displayName.isNotEmpty, true);
      }
    });

    test('description returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.description.isNotEmpty, true);
      }
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/constants/dive_detail_sections_test.dart`
Expected: Compilation error — `dive_detail_sections.dart` does not exist yet.

- [ ] **Step 3: Implement the model**

Create `lib/core/constants/dive_detail_sections.dart`:

```dart
import 'dart:convert';

/// Identifies each configurable section on the Dive Details page.
///
/// Declaration order defines the default display order. The two fixed sections
/// (Header and Dive Profile Chart) are not included — they always render first.
enum DiveDetailSectionId {
  decoO2,
  sacSegments,
  details,
  environment,
  altitude,
  tide,
  weights,
  tanks,
  buddies,
  signatures,
  equipment,
  sightings,
  media,
  tags,
  notes,
  customFields,
  dataSources;

  /// Human-readable name shown in the settings UI.
  String get displayName {
    return switch (this) {
      decoO2 => 'Deco Status / Tissue Loading',
      sacSegments => 'SAC Rate by Segment',
      details => 'Details',
      environment => 'Environment',
      altitude => 'Altitude',
      tide => 'Tide',
      weights => 'Weights',
      tanks => 'Tanks',
      buddies => 'Buddies',
      signatures => 'Signatures',
      equipment => 'Equipment',
      sightings => 'Marine Life Sightings',
      media => 'Media',
      tags => 'Tags',
      notes => 'Notes',
      customFields => 'Custom Fields',
      dataSources => 'Data Sources',
    };
  }

  /// Short description shown below the name in the settings UI.
  String get description {
    return switch (this) {
      decoO2 => 'NDL, ceiling, tissue heat map, O2 toxicity',
      sacSegments => 'Phase/time segmentation, cylinder breakdown',
      details => 'Type, location, trip, dive center, interval',
      environment => 'Air/water temp, visibility, current',
      altitude => 'Altitude value, category, deco requirement',
      tide => 'Tide cycle graph and timing',
      weights => 'Weight breakdown, total weight',
      tanks => 'Tank list, gas mixes, pressures, per-tank SAC',
      buddies => 'Buddy list with roles',
      signatures => 'Buddy/instructor signature display and capture',
      equipment => 'Equipment used in dive',
      sightings => 'Species spotted, sighting details',
      media => 'Photos/videos gallery',
      tags => 'Dive tags',
      notes => 'Dive notes/description',
      customFields => 'User-defined custom fields',
      dataSources => 'Connected dive computers, source management',
    };
  }
}

/// Visibility and ordering configuration for a single dive detail section.
class DiveDetailSectionConfig {
  final DiveDetailSectionId id;
  final bool visible;

  const DiveDetailSectionConfig({
    required this.id,
    required this.visible,
  });

  DiveDetailSectionConfig copyWith({bool? visible}) {
    return DiveDetailSectionConfig(
      id: id,
      visible: visible ?? this.visible,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id.name,
        'visible': visible,
      };

  /// Returns a [DiveDetailSectionConfig] from a JSON map, or throws if the
  /// section ID is not recognized.
  factory DiveDetailSectionConfig.fromJson(Map<String, dynamic> json) {
    final idStr = json['id'] as String;
    final id = DiveDetailSectionId.values.firstWhere((e) => e.name == idStr);
    return DiveDetailSectionConfig(
      id: id,
      visible: json['visible'] as bool? ?? true,
    );
  }

  /// Returns a [DiveDetailSectionConfig] from a JSON map, or `null` if the
  /// section ID is not recognized (e.g. was removed in a newer app version).
  static DiveDetailSectionConfig? tryFromJson(Map<String, dynamic> json) {
    try {
      return DiveDetailSectionConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // List serialization (JSON string ↔ List<DiveDetailSectionConfig>)
  // ---------------------------------------------------------------------------

  /// All 17 sections visible in enum declaration order.
  static const List<DiveDetailSectionConfig> defaultSections = [
    DiveDetailSectionConfig(id: DiveDetailSectionId.decoO2, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.sacSegments, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.details, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.environment, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.altitude, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.tide, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.weights, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.tanks, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.buddies, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.signatures, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.equipment, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.sightings, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.media, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.tags, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.notes, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.customFields, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.dataSources, visible: true),
  ];

  /// Serialize a section list to a JSON string for database storage.
  static String sectionsToJson(List<DiveDetailSectionConfig> sections) {
    return jsonEncode(sections.map((s) => s.toJson()).toList());
  }

  /// Deserialize a JSON string from the database into a section list.
  ///
  /// Returns [defaultSections] for null, empty, or invalid input.
  /// Skips unrecognized section IDs (future-removed sections).
  /// After parsing, calls [ensureAllSections] to append any newly added
  /// sections that are missing from the saved data.
  static List<DiveDetailSectionConfig> sectionsFromJson(String? json) {
    if (json == null || json.isEmpty) return List.of(defaultSections);
    try {
      final decoded = jsonDecode(json) as List;
      final sections = decoded
          .map((e) => tryFromJson(e as Map<String, dynamic>))
          .whereType<DiveDetailSectionConfig>()
          .toList();
      if (sections.isEmpty) return List.of(defaultSections);
      return ensureAllSections(sections);
    } catch (_) {
      return List.of(defaultSections);
    }
  }

  /// Ensures every [DiveDetailSectionId] is represented in the list.
  ///
  /// Any IDs present in the enum but missing from [sections] (e.g. added in a
  /// newer app version) are appended at the end with `visible: true`.
  static List<DiveDetailSectionConfig> ensureAllSections(
    List<DiveDetailSectionConfig> sections,
  ) {
    final presentIds = sections.map((s) => s.id).toSet();
    final missing = DiveDetailSectionId.values
        .where((id) => !presentIds.contains(id))
        .map((id) => DiveDetailSectionConfig(id: id, visible: true));
    if (missing.isEmpty) return sections;
    return [...sections, ...missing];
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/constants/dive_detail_sections_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/constants/dive_detail_sections.dart test/core/constants/dive_detail_sections_test.dart
git add lib/core/constants/dive_detail_sections.dart test/core/constants/dive_detail_sections_test.dart
git commit -m "feat: add DiveDetailSectionId enum and DiveDetailSectionConfig model

Define the 17 configurable section IDs, their display metadata, and
JSON serialization for database storage. Includes ensureAllSections
for forward-compatible new-section detection."
```

---

## Task 2: Database Column and Migration

**Files:**
- Modify: `lib/core/database/database.dart:575-724` (DiverSettings table)
- Modify: `lib/core/database/database.dart:1241` (schema version)
- Modify: `lib/core/database/database.dart:2467-2472` (migration)

- [ ] **Step 1: Add the nullable TEXT column to DiverSettings table**

In `lib/core/database/database.dart`, after the `showDataSourceBadges` column (line 719) and before the `createdAt` column (line 720), add:

```dart
  // Dive detail section order and visibility (v56) — JSON array
  TextColumn get diveDetailSections => text().nullable()();
```

- [ ] **Step 2: Bump schema version from 55 to 56**

In `lib/core/database/database.dart` at line 1241, change:

```dart
static const int currentSchemaVersion = 56;
```

- [ ] **Step 3: Add v56 migration**

In `lib/core/database/database.dart`, after the v55 migration block (after line 2472), add:

```dart
        if (from < 56) {
          // Add dive detail section configuration column to diver_settings
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN dive_detail_sections TEXT',
          );
        }
```

- [ ] **Step 4: Run code generation to update Drift generated classes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Build completes successfully with updated `database.g.dart`.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/database/database.dart
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add diveDetailSections column to diver_settings (v56)

Nullable TEXT column stores JSON section config. Null means use defaults.
No data backfill needed for existing divers."
```

---

## Task 3: AppSettings Integration

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Test: `test/features/settings/presentation/providers/settings_providers_test.dart`

- [ ] **Step 1: Write failing tests for the new AppSettings field**

Add to `test/features/settings/presentation/providers/settings_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // ... existing tests ...

  group('AppSettings diveDetailSections', () {
    test('defaults to all 17 sections visible', () {
      const settings = AppSettings();
      expect(settings.diveDetailSections.length, 17);
      expect(settings.diveDetailSections.every((s) => s.visible), true);
    });

    test('copyWith updates diveDetailSections', () {
      const settings = AppSettings();
      final custom = [
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.tanks,
          visible: true,
        ),
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoO2,
          visible: false,
        ),
      ];
      final updated = settings.copyWith(diveDetailSections: custom);
      expect(updated.diveDetailSections.length, 2);
      expect(updated.diveDetailSections[0].id, DiveDetailSectionId.tanks);
    });

    test('copyWith can clear diveDetailSections to defaults', () {
      final settings = AppSettings(
        diveDetailSections: [
          const DiveDetailSectionConfig(
            id: DiveDetailSectionId.tanks,
            visible: false,
          ),
        ],
      );
      final updated = settings.copyWith(
        clearDiveDetailSections: true,
      );
      expect(updated.diveDetailSections.length, 17);
      expect(updated.diveDetailSections.every((s) => s.visible), true);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/providers/settings_providers_test.dart`
Expected: Compilation error — `diveDetailSections` not yet a field on `AppSettings`.

- [ ] **Step 3: Add diveDetailSections field to AppSettings**

In `lib/features/settings/presentation/providers/settings_providers.dart`, add the import at the top:

```dart
import 'package:submersion/core/constants/dive_detail_sections.dart';
```

Add the field declaration after `showDataSourceBadges` (around line 247):

```dart
  /// Ordered list of dive detail section visibility preferences
  final List<DiveDetailSectionConfig> diveDetailSections;
```

Add the constructor parameter after `this.showDataSourceBadges = true,` (around line 326):

```dart
    this.diveDetailSections = DiveDetailSectionConfig.defaultSections,
```

Add the `copyWith` parameter after `bool? showDataSourceBadges,` (around line 437):

```dart
    List<DiveDetailSectionConfig>? diveDetailSections,
    bool clearDiveDetailSections = false,
```

Add the `copyWith` body entry after the `showDataSourceBadges` line (around line 528):

```dart
      diveDetailSections: clearDiveDetailSections
          ? DiveDetailSectionConfig.defaultSections
          : (diveDetailSections ?? this.diveDetailSections),
```

- [ ] **Step 4: Add SettingsNotifier methods**

In the `SettingsNotifier` class, add after the last setter method (before the closing `}`):

```dart
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async {
    state = state.copyWith(diveDetailSections: sections);
    await _saveSettings();
  }

  Future<void> resetDiveDetailSections() async {
    state = state.copyWith(clearDiveDetailSections: true);
    await _saveSettings();
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/providers/settings_providers_test.dart`
Expected: All tests PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/features/settings/presentation/providers/settings_providers.dart test/features/settings/presentation/providers/settings_providers_test.dart
git add lib/features/settings/presentation/providers/settings_providers.dart test/features/settings/presentation/providers/settings_providers_test.dart
git commit -m "feat: add diveDetailSections to AppSettings and SettingsNotifier

New field with copyWith support and clear-to-defaults flag.
SettingsNotifier gets set and reset methods for the section config."
```

---

## Task 4: Repository Wiring

**Files:**
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`

- [ ] **Step 1: Add import**

Add at the top of the file:

```dart
import 'package:submersion/core/constants/dive_detail_sections.dart';
```

- [ ] **Step 2: Update _mapRowToAppSettings**

In `_mapRowToAppSettings` (around line 321), add after the `showDataSourceBadges` line (line 394):

```dart
      diveDetailSections: DiveDetailSectionConfig.sectionsFromJson(
        row.diveDetailSections,
      ),
```

- [ ] **Step 3: Update createSettingsForDiver**

In `createSettingsForDiver` (around line 50), add after the `showDataSourceBadges` line (line 133):

```dart
              diveDetailSections: Value(
                s.diveDetailSections == DiveDetailSectionConfig.defaultSections
                    ? null
                    : DiveDetailSectionConfig.sectionsToJson(
                        s.diveDetailSections,
                      ),
              ),
```

- [ ] **Step 4: Update updateSettingsForDiver**

In `updateSettingsForDiver` (around line 159), add after the `showDataSourceBadges` line (line 252):

```dart
          diveDetailSections: Value(
            settings.diveDetailSections ==
                    DiveDetailSectionConfig.defaultSections
                ? null
                : DiveDetailSectionConfig.sectionsToJson(
                    settings.diveDetailSections,
                  ),
          ),
```

- [ ] **Step 5: Verify the app compiles**

Run: `flutter analyze`
Expected: No new errors.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/features/settings/data/repositories/diver_settings_repository.dart
git add lib/features/settings/data/repositories/diver_settings_repository.dart
git commit -m "feat: wire diveDetailSections through DiverSettingsRepository

JSON serialization via DiveDetailSectionConfig.sectionsFromJson/toJson.
Stores null when config matches defaults to avoid unnecessary writes."
```

---

## Task 5: Settings UI — DiveDetailSectionsPage

**Files:**
- Create: `lib/features/settings/presentation/pages/dive_detail_sections_page.dart`
- Test: `test/features/settings/presentation/pages/dive_detail_sections_page_test.dart`

- [ ] **Step 1: Write failing widget test**

Create `test/features/settings/presentation/pages/dive_detail_sections_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/settings/presentation/pages/dive_detail_sections_page.dart';

void main() {
  group('DiveDetailSectionsPage', () {
    testWidgets('renders all 17 section names', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiveDetailSectionsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final id in DiveDetailSectionId.values) {
        expect(find.text(id.displayName), findsOneWidget);
      }
    });

    testWidgets('renders 17 switches', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiveDetailSectionsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNWidgets(17));
    });

    testWidgets('renders drag handles', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiveDetailSectionsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle), findsNWidgets(17));
    });

    testWidgets('shows fixed sections note', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiveDetailSectionsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Header'), findsOneWidget);
      expect(find.textContaining('Dive Profile'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/pages/dive_detail_sections_page_test.dart`
Expected: Compilation error — `DiveDetailSectionsPage` does not exist.

- [ ] **Step 3: Implement DiveDetailSectionsPage**

Create `lib/features/settings/presentation/pages/dive_detail_sections_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class DiveDetailSectionsPage extends ConsumerWidget {
  const DiveDetailSectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(
      settingsProvider.select((s) => s.diveDetailSections),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Section Order & Visibility'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                ref.read(settingsProvider.notifier).resetDiveDetailSections();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Text('Reset to Default'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Fixed sections: Header, Dive Profile Chart',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Configurable sections (drag to reorder)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: sections.length,
              onReorder: (oldIndex, newIndex) {
                _onReorder(ref, sections, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final section = sections[index];
                return _SectionTile(
                  key: ValueKey(section.id),
                  section: section,
                  index: index,
                  onToggle: (visible) {
                    _onToggle(ref, sections, index, visible);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onReorder(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex--;
    final updated = List.of(sections);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }

  void _onToggle(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    int index,
    bool visible,
  ) {
    final updated = List.of(sections);
    updated[index] = updated[index].copyWith(visible: visible);
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    super.key,
    required this.section,
    required this.index,
    required this.onToggle,
  });

  final DiveDetailSectionConfig section;
  final int index;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: section.visible ? 1.0 : 0.5,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(
          section.id.displayName,
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: Text(
          section.id.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: section.visible,
          onChanged: onToggle,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/pages/dive_detail_sections_page_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/settings/presentation/pages/dive_detail_sections_page.dart test/features/settings/presentation/pages/dive_detail_sections_page_test.dart
git add lib/features/settings/presentation/pages/dive_detail_sections_page.dart test/features/settings/presentation/pages/dive_detail_sections_page_test.dart
git commit -m "feat: add DiveDetailSectionsPage with drag-and-drop reordering

ReorderableListView with visibility toggle switches per section.
Reset to Default in overflow menu. Dimmed styling for hidden sections."
```

---

## Task 6: Appearance Page Link and Router

**Files:**
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Add the "Dive Details" section to the Appearance page**

In `lib/features/settings/presentation/pages/appearance_page.dart`, after the "Dive Profile" section's last widget (the `ListTile` for default-metrics at line 358) and before the `const SizedBox(height: 8)` at line 359, insert:

```dart
          const Divider(),
          _buildSectionHeader(context, 'Dive Details'),
          ListTile(
            leading: const Icon(Icons.reorder),
            title: const Text('Section Order & Visibility'),
            subtitle: const Text('Choose which sections appear and their order'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/dive-detail-sections'),
          ),
```

- [ ] **Step 2: Add the route**

In `lib/core/router/app_router.dart`, add the import at the top:

```dart
import 'package:submersion/features/settings/presentation/pages/dive_detail_sections_page.dart';
```

Add a new `GoRoute` in the settings routes list, after the `appearance` route (after line 735):

```dart
              GoRoute(
                path: 'dive-detail-sections',
                name: 'diveDetailSections',
                builder: (context, state) =>
                    const DiveDetailSectionsPage(),
              ),
```

- [ ] **Step 3: Verify the app compiles and the route works**

Run: `flutter analyze`
Expected: No new errors.

- [ ] **Step 4: Format and commit**

```bash
dart format lib/features/settings/presentation/pages/appearance_page.dart lib/core/router/app_router.dart
git add lib/features/settings/presentation/pages/appearance_page.dart lib/core/router/app_router.dart
git commit -m "feat: add Dive Details section to Appearance page with route

Navigation tile in Appearance links to /settings/dive-detail-sections.
New GoRoute wires the DiveDetailSectionsPage into the router."
```

---

## Task 7: Dive Detail Page — Section Registry and Config-Driven Render Loop

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

This is the largest task. The goal is to replace the hardcoded section ordering in `_buildContent()` with a registry map and loop over the user's config, while preserving all existing behavior.

- [ ] **Step 1: Add import**

In `dive_detail_page.dart`, add the import:

```dart
import 'package:submersion/core/constants/dive_detail_sections.dart';
```

- [ ] **Step 2: Create the section registry getter**

Add a method to `_DiveDetailPageState` that maps each `DiveDetailSectionId` to a builder function. The builder returns `List<Widget>` (to handle the `SizedBox` spacers and spread patterns used by each section). Each builder preserves the exact existing data-driven visibility condition and widget construction.

Add this method to the `_DiveDetailPageState` class:

```dart
  /// Maps each configurable section ID to a builder that returns the widgets
  /// for that section (including spacing), or an empty list if the section's
  /// data-driven condition hides it.
  Map<DiveDetailSectionId, List<Widget> Function()> _sectionBuilders({
    required BuildContext context,
    required WidgetRef ref,
    required Dive dive,
    required UnitFormatter units,
    required AsyncValue<List<DiveDataSource>> computerReadingsAsync,
    required AppSettings settings,
  }) {
    return {
      DiveDetailSectionId.decoO2: () {
        if (dive.profile.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          ValueListenableBuilder<int?>(
            valueListenable: _selectedPointNotifier,
            builder: (context, selectedPointIndex, _) {
              return _buildDecoO2Panel(
                context,
                ref,
                dive,
                selectedPointIndex,
              );
            },
          ),
        ];
      },
      DiveDetailSectionId.sacSegments: () {
        if (dive.profile.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          ValueListenableBuilder<int?>(
            valueListenable: _selectedPointNotifier,
            builder: (context, selectedPointIndex, _) {
              return _buildSacSegmentsSection(
                context,
                ref,
                dive,
                selectedPointIndex,
              );
            },
          ),
        ];
      },
      DiveDetailSectionId.details: () {
        return [
          ValueListenableBuilder<String?>(
            valueListenable: _viewedSourceIdNotifier,
            builder: (context, viewedSourceId, _) {
              final dataSources = computerReadingsAsync.valueOrNull ?? [];
              final attribution = FieldAttributionService.computeAttribution(
                dataSources,
                viewedSourceId: viewedSourceId,
              );
              final showBadges =
                  settings.showDataSourceBadges && attribution.isNotEmpty;
              return _buildDetailsSection(
                context,
                ref,
                dive,
                units,
                attribution: showBadges ? attribution : null,
              );
            },
          ),
        ];
      },
      DiveDetailSectionId.environment: () {
        if (!_hasEnvironmentData(dive)) return [];
        return [
          const SizedBox(height: 24),
          _buildEnvironmentSection(context, dive, units),
        ];
      },
      DiveDetailSectionId.altitude: () {
        if (dive.altitude == null || dive.altitude! <= 0) return [];
        return [
          const SizedBox(height: 24),
          _buildAltitudeSection(context, ref, dive),
        ];
      },
      DiveDetailSectionId.tide: () {
        return [_buildTideSection(context, ref, dive)];
      },
      DiveDetailSectionId.weights: () {
        if (!_hasWeights(dive)) return [];
        return [
          const SizedBox(height: 24),
          _buildWeightSection(context, dive, units),
        ];
      },
      DiveDetailSectionId.tanks: () {
        if (dive.tanks.isEmpty) return [];
        return [_buildTanksSection(context, ref, dive, units)];
      },
      DiveDetailSectionId.buddies: () {
        return [
          const SizedBox(height: 24),
          _buildBuddiesSection(context, ref),
        ];
      },
      DiveDetailSectionId.signatures: () {
        return [
          const SizedBox(height: 24),
          BuddySignaturesSection(diveId: diveId),
        ];
      },
      DiveDetailSectionId.equipment: () {
        if (dive.equipment.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          _buildEquipmentSection(context, ref, dive),
        ];
      },
      DiveDetailSectionId.sightings: () {
        return [_buildSightingsSection(context, ref)];
      },
      DiveDetailSectionId.media: () {
        return [
          const SizedBox(height: 24),
          _buildMediaSection(context, ref, dive),
        ];
      },
      DiveDetailSectionId.tags: () {
        if (dive.tags.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          _buildTagsSection(context, dive),
        ];
      },
      DiveDetailSectionId.notes: () {
        return [
          const SizedBox(height: 24),
          _buildNotesSection(context, dive),
        ];
      },
      DiveDetailSectionId.customFields: () {
        if (dive.customFields.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          _buildCustomFieldsSection(context, dive),
        ];
      },
      DiveDetailSectionId.dataSources: () {
        return [
          const SizedBox(height: 24),
          ValueListenableBuilder<String?>(
            valueListenable: _viewedSourceIdNotifier,
            builder: (context, viewedSourceId, _) {
              final dataSources = computerReadingsAsync.valueOrNull ?? [];
              return DataSourcesSection(
                dataSources: dataSources,
                diveCreatedAt: dive.dateTime,
                diveId: dive.id,
                units: units,
                viewedSourceId: viewedSourceId,
                onTapSource: (sourceId) {
                  if (_viewedSourceIdNotifier.value == sourceId) {
                    _viewedSourceIdNotifier.value = null;
                  } else {
                    _viewedSourceIdNotifier.value = sourceId;
                  }
                },
                onSetPrimary: (readingId) => _onSetPrimaryDataSource(
                  context,
                  ref,
                  diveId: dive.id,
                  readingId: readingId,
                ),
                onUnlink: (readingId) => _onUnlinkDataSource(
                  context,
                  ref,
                  diveId: dive.id,
                  readingId: readingId,
                ),
              );
            },
          ),
        ];
      },
    };
  }
```

- [ ] **Step 3: Replace the hardcoded section list in _buildContent with the config-driven loop**

Replace the `children` list in `_buildContent()` (lines 237-380) with the following. Keep the fixed sections (header, profile) at the top, then loop over the user's config:

```dart
          children: [
            // Fixed: Header
            ValueListenableBuilder<String?>(
              valueListenable: _viewedSourceIdNotifier,
              builder: (context, viewedSourceId, _) {
                final dataSources = computerReadingsAsync.valueOrNull ?? [];
                final attribution = FieldAttributionService.computeAttribution(
                  dataSources,
                  viewedSourceId: viewedSourceId,
                );
                final showBadges =
                    settings.showDataSourceBadges && attribution.isNotEmpty;
                return _buildHeaderSection(
                  context,
                  ref,
                  dive,
                  units,
                  attribution: showBadges ? attribution : null,
                );
              },
            ),
            const SizedBox(height: 24),
            // Fixed: Dive Profile Chart
            if (dive.profile.isNotEmpty) ...[
              _buildProfileSection(context, ref, dive),
            ],
            // Configurable sections in user-defined order
            for (final section in settings.diveDetailSections)
              if (section.visible)
                ...builders[section.id]?.call() ?? [],
            const SizedBox(height: 32),
          ],
```

The `builders` variable should be computed just before the `body` assignment inside `_buildContent`:

```dart
    final builders = _sectionBuilders(
      context: context,
      ref: ref,
      dive: dive,
      units: units,
      computerReadingsAsync: computerReadingsAsync,
      settings: settings,
    );
```

- [ ] **Step 4: Remove the signature section special case**

The existing code has a `_buildSignatureSection` that only shows when `dive.courseId != null`. This maps to the `signatures` section ID (not `buddySignatures`). If this is a separate section from `BuddySignaturesSection`, it should be handled appropriately. Look at the existing code — if `_buildSignatureSection` is for course/instructor signatures (line 341-344), fold it into the `signatures` builder:

Update the `signatures` builder to include both buddy signatures and course signatures:

```dart
      DiveDetailSectionId.signatures: () {
        final widgets = <Widget>[
          const SizedBox(height: 24),
          BuddySignaturesSection(diveId: diveId),
        ];
        if (dive.courseId != null) {
          widgets.addAll([
            const SizedBox(height: 24),
            _buildSignatureSection(context, ref, dive),
          ]);
        }
        return widgets;
      },
```

- [ ] **Step 5: Verify the app compiles**

Run: `flutter analyze`
Expected: No new errors.

- [ ] **Step 6: Run full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format lib/features/dive_log/presentation/pages/dive_detail_page.dart
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "feat: config-driven section rendering on dive detail page

Replace hardcoded section order with a registry map and loop over the
user's diveDetailSections config. Fixed sections (header, profile)
remain at the top. All data-driven auto-hide conditions preserved."
```

---

## Task 8: Full Integration Verification

**Files:**
- No new files — verification only

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Run formatter**

Run: `dart format lib/ test/`
Expected: No formatting changes.

- [ ] **Step 4: Final commit (if any formatting fixes)**

Only if Step 3 produced changes:

```bash
git add -A
git commit -m "style: format code"
```
