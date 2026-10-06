# Bulk File Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import many dive files (FIT, UDDF, Subsurface XML, MacDive, Shearwater .db) in one wizard session with one merged review, cross-file duplicate detection, and a per-file summary (issue #501).

**Architecture:** Payload-level merge. Each file runs the existing detect → parse pipeline producing an `ImportPayload`; a new `PayloadMerger` folds N payloads into one (namespaced cross-file `uddfId`s, reference entities folded by name, dives never folded). Everything downstream — `UniversalAdapter.buildBundle`, `ImportDuplicateChecker` (extended with an intra-batch dive pass), review UI, `UddfEntityImporter`, consolidation — runs once on the merged payload. N=1 short-circuits to today's single-file flow, including CSV field mapping.

**Tech Stack:** Flutter 3.x, Riverpod (`StateNotifier`), Drift, file_picker, desktop_drop.

**Spec:** `docs/superpowers/specs/2026-07-06-bulk-file-import-design.md`

## Global Constraints

- Run `dart format .` on the WHOLE repo before every commit (CI checks the whole project).
- Run `flutter analyze` on the WHOLE project (never pipe through `tail`/`head` to gate a commit).
- New user-visible strings go in `lib/l10n/arb/app_en.arb` AND all 10 non-English locales (ar, de, es, fr, he, hu, it, nl, pt, zh), then regenerate with `flutter gen-l10n`.
- No emojis anywhere. No `Co-Authored-By` lines in commits.
- Run specific test files, not broad directories (Bash timeouts).
- If executing in a fresh worktree: `git submodule update --init --recursive`, `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs` first, or DB tests fail on missing `database.g.dart`.
- Subagents: never run bare `git stash`; verify you are in the correct worktree/branch before every commit.
- CSV files are NEVER part of a batch (they keep the single-file wizard). Folder pick is desktop-only (macOS/Windows/Linux).

## Key existing code facts (read before assuming)

- Dives reference other entities via per-payload string IDs, resolved by `UddfEntityImporter`:
  - `dive['site']?['uddfId']` (nested map) and fallback `dive['siteId']` → `siteIdMapping`
  - `dive['tripRef']`, `dive['diveCenterRef']`, `dive['courseRef']` (strings)
  - `dive['equipmentRefs']`, `dive['buddyRefs']`, `dive['diveGuideRefs']`, `dive['tagRefs']` (List of String)
  - Every reference entity's own ID key is `'uddfId'` (dive types use `'id'`, a semantic slug — do NOT namespace it).
- `ImportPayload` is `Map<ImportEntityType, List<Map<String, dynamic>>>` + `warnings` + `metadata` (`lib/features/universal_import/data/models/import_payload.dart`).
- `ImportDuplicateChecker.check(...)` (`lib/features/universal_import/data/services/import_duplicate_checker.dart:83`) does source-UUID pass then `DiveMatcher` fuzzy pass; `DiveMatchResult` is in `lib/features/dive_import/domain/services/dive_matcher.dart:79`.
- Wizard: `UniversalAdapter` (`lib/features/import_wizard/data/adapters/universal_adapter.dart`) supplies `acquisitionSteps` (Select File → Confirm Source → Map Fields), `buildBundle`, `checkDuplicates`, `performImport`.
- State: `UniversalImportState` (`lib/features/universal_import/presentation/providers/universal_import_state.dart`) holds scalar `fileBytes`/`fileName`.
- The notifier (`lib/features/universal_import/presentation/providers/universal_import_providers.dart`) has `pickFile()` (`allowMultiple: false`), `_parseAndCheckDuplicates()`, `_parserFor(format)`, `loadFileFromBytes()`.
- Drag-and-drop: `lib/shared/widgets/global_drop_target.dart:76` takes `details.files.first` only.

---

### Task 1: PayloadMerger service

**Files:**
- Create: `lib/features/universal_import/data/services/payload_merger.dart`
- Test: `test/features/universal_import/data/services/payload_merger_test.dart`

**Interfaces:**
- Consumes: `ImportPayload`, `ImportEntityType` (existing).
- Produces: `class FilePayload { final String fileId; final String fileName; final ImportPayload payload; }` and `class PayloadMerger { ImportPayload merge(List<FilePayload> inputs); }`. Merged payload metadata contains `'batchFileCount'` (int) and `'sourceFiles'` (List of String). Every entity map in the merged payload has `'_sourceFile'` (String, the display file name). Later tasks (5, 9) rely on these exact keys.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/universal_import/data/services/payload_merger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

ImportPayload payloadWith({
  List<Map<String, dynamic>> dives = const [],
  List<Map<String, dynamic>> sites = const [],
  List<Map<String, dynamic>> buddies = const [],
  List<Map<String, dynamic>> equipment = const [],
}) {
  return ImportPayload(
    entities: {
      if (dives.isNotEmpty) ImportEntityType.dives: dives,
      if (sites.isNotEmpty) ImportEntityType.sites: sites,
      if (buddies.isNotEmpty) ImportEntityType.buddies: buddies,
      if (equipment.isNotEmpty) ImportEntityType.equipment: equipment,
    },
  );
}

void main() {
  const merger = PayloadMerger();

  group('PayloadMerger', () {
    test('namespaces colliding uddfIds across files', () {
      final a = payloadWith(
        sites: [
          {'uddfId': 'site_1', 'name': 'Blue Hole'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'site': {'uddfId': 'site_1', 'name': 'Blue Hole'},
          },
        ],
      );
      final b = payloadWith(
        sites: [
          {'uddfId': 'site_1', 'name': 'Shark Reef'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'site': {'uddfId': 'site_1', 'name': 'Shark Reef'},
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      final sites = merged.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(2));
      expect(sites[0]['uddfId'], 'f0:site_1');
      expect(sites[1]['uddfId'], 'f1:site_1');

      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect(
        (dives[0]['site'] as Map<String, dynamic>)['uddfId'],
        'f0:site_1',
      );
      expect(
        (dives[1]['site'] as Map<String, dynamic>)['uddfId'],
        'f1:site_1',
      );
    });

    test('folds same-name sites across files and rewrites dive refs', () {
      final a = payloadWith(
        sites: [
          {'uddfId': 's1', 'name': 'Blue Hole'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'site': {'uddfId': 's1', 'name': 'Blue Hole'},
          },
        ],
      );
      final b = payloadWith(
        sites: [
          {
            'uddfId': 's9',
            'name': 'blue hole ', // different case + trailing space
            'latitude': 12.2,
            'longitude': 43.1,
          },
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'site': {'uddfId': 's9', 'name': 'blue hole '},
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      final sites = merged.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(1));
      // Survivor is the first occurrence, enriched with the later file's
      // non-null fields.
      expect(sites[0]['uddfId'], 'f0:s1');
      expect(sites[0]['name'], 'Blue Hole');
      expect(sites[0]['latitude'], 12.2);

      // The second dive's site ref is rewritten to the survivor.
      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect(
        (dives[1]['site'] as Map<String, dynamic>)['uddfId'],
        'f0:s1',
      );
    });

    test('rewrites list refs (buddyRefs) through the alias map', () {
      final a = payloadWith(
        buddies: [
          {'uddfId': 'b1', 'name': 'Alice'},
        ],
      );
      final b = payloadWith(
        buddies: [
          {'uddfId': 'b7', 'name': 'ALICE'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'buddyRefs': ['b7'],
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      expect(merged.entitiesOf(ImportEntityType.buddies), hasLength(1));
      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['buddyRefs'], ['f0:b1']);
    });

    test('never folds dives, even identical ones', () {
      final dive = {
        'dateTime': DateTime(2026, 1, 1, 9),
        'maxDepth': 18.0,
      };
      final merged = merger.merge([
        FilePayload(
          fileId: 'f0',
          fileName: 'a.fit',
          payload: payloadWith(dives: [Map.of(dive)]),
        ),
        FilePayload(
          fileId: 'f1',
          fileName: 'b.uddf',
          payload: payloadWith(dives: [Map.of(dive)]),
        ),
      ]);
      expect(merged.entitiesOf(ImportEntityType.dives), hasLength(2));
    });

    test('equipment folds by name AND type, not name alone', () {
      final a = payloadWith(
        equipment: [
          {'uddfId': 'e1', 'name': 'Perdix', 'type': 'computer'},
        ],
      );
      final b = payloadWith(
        equipment: [
          {'uddfId': 'e2', 'name': 'Perdix', 'type': 'other'},
        ],
      );
      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);
      expect(merged.entitiesOf(ImportEntityType.equipment), hasLength(2));
    });

    test('stamps _sourceFile on every entity and batch metadata', () {
      final merged = merger.merge([
        FilePayload(
          fileId: 'f0',
          fileName: 'a.fit',
          payload: payloadWith(dives: [
            {'dateTime': DateTime(2026, 1, 1)},
          ]),
        ),
        FilePayload(
          fileId: 'f1',
          fileName: 'b.fit',
          payload: payloadWith(dives: [
            {'dateTime': DateTime(2026, 1, 2)},
          ]),
        ),
      ]);

      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['_sourceFile'], 'a.fit');
      expect(dives[1]['_sourceFile'], 'b.fit');
      expect(merged.metadata['batchFileCount'], 2);
      expect(merged.metadata['sourceFiles'], ['a.fit', 'b.fit']);
    });

    test('concatenates warnings from all files', () {
      final a = ImportPayload(
        entities: const {},
        warnings: const [ImportWarning(message: 'w1')],
      );
      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
      ]);
      expect(merged.warnings, hasLength(1));
    });
  });
}
```

Note: check `ImportWarning`'s constructor in `lib/features/universal_import/data/models/import_warning.dart` before writing the last test — adjust the named/positional parameters to the real signature.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/payload_merger_test.dart`
Expected: FAIL — `payload_merger.dart` does not exist.

- [ ] **Step 3: Implement PayloadMerger**

```dart
// lib/features/universal_import/data/services/payload_merger.dart
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// One parsed file's payload plus its batch identity.
class FilePayload {
  final String fileId; // stable per-file prefix key, e.g. 'f0'
  final String fileName; // display name, stamped as `_sourceFile`
  final ImportPayload payload;

  const FilePayload({
    required this.fileId,
    required this.fileName,
    required this.payload,
  });
}

/// Merges N per-file [ImportPayload]s into one batch payload.
///
/// - Every `uddfId` (and dive-side reference to one) is prefixed with the
///   file's id (`f0:site_1`) so IDs from different files cannot collide.
/// - Reference entities (sites, buddies, trips, dive centers, tags, dive
///   types, courses, equipment sets by normalized name; equipment by
///   name+type; certifications by name+agency) are folded across files:
///   the first occurrence survives, enriched with later files' non-null
///   fields, and dive-side references to folded entities are rewritten to
///   the survivor's id.
/// - Dives are NEVER folded; cross-file dive duplicates are left for the
///   duplicate checker so the user decides.
class PayloadMerger {
  const PayloadMerger();

  /// Dive map fields holding a single entity reference.
  static const _scalarRefFields = ['siteId', 'tripRef', 'diveCenterRef', 'courseRef'];

  /// Dive map fields holding a list of entity references.
  static const _listRefFields = [
    'equipmentRefs',
    'buddyRefs',
    'diveGuideRefs',
    'tagRefs',
  ];

  ImportPayload merge(List<FilePayload> inputs) {
    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    final warnings = <ImportWarning>[];
    // prefixed folded id -> prefixed survivor id
    final aliases = <String, String>{};
    // entity type -> fold key -> surviving map (already in `entities`)
    final survivors = <ImportEntityType, Map<String, Map<String, dynamic>>>{};

    for (final input in inputs) {
      warnings.addAll(input.payload.warnings);

      for (final type in ImportEntityType.values) {
        final items = input.payload.entitiesOf(type);
        if (items.isEmpty) continue;

        for (final original in items) {
          final item = _namespaced(original, input.fileId, type);
          item['_sourceFile'] = input.fileName;

          if (type == ImportEntityType.dives) {
            (entities[type] ??= []).add(item);
            continue;
          }

          final key = _foldKey(type, item);
          if (key == null) {
            (entities[type] ??= []).add(item);
            continue;
          }

          final byKey = survivors[type] ??= {};
          final survivor = byKey[key];
          if (survivor == null) {
            byKey[key] = item;
            (entities[type] ??= []).add(item);
          } else {
            // Enrich the survivor with fields it is missing.
            for (final entry in item.entries) {
              if (entry.key == 'uddfId' || entry.key == '_sourceFile') {
                continue;
              }
              final existing = survivor[entry.key];
              if (existing == null || (existing is String && existing.isEmpty)) {
                if (entry.value != null) survivor[entry.key] = entry.value;
              }
            }
            final foldedId = item['uddfId'] as String?;
            final survivorId = survivor['uddfId'] as String?;
            if (foldedId != null && survivorId != null) {
              aliases[foldedId] = survivorId;
            }
          }
        }
      }
    }

    _rewriteAliases(entities, aliases);

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {
        'batchFileCount': inputs.length,
        'sourceFiles': [for (final i in inputs) i.fileName],
      },
    );
  }

  /// Deep-copy [original] with all uddfId-style references prefixed.
  Map<String, dynamic> _namespaced(
    Map<String, dynamic> original,
    String fileId,
    ImportEntityType type,
  ) {
    final item = Map<String, dynamic>.of(original);

    // Dive types use a semantic slug in 'id', shared across files by design.
    if (type != ImportEntityType.diveTypes) {
      final uddfId = item['uddfId'];
      if (uddfId is String && uddfId.isNotEmpty) {
        item['uddfId'] = '$fileId:$uddfId';
      }
    }

    if (type == ImportEntityType.dives) {
      final site = item['site'];
      if (site is Map<String, dynamic>) {
        final copy = Map<String, dynamic>.of(site);
        final siteId = copy['uddfId'];
        if (siteId is String && siteId.isNotEmpty) {
          copy['uddfId'] = '$fileId:$siteId';
        }
        item['site'] = copy;
      }
      for (final field in _scalarRefFields) {
        final value = item[field];
        if (value is String && value.isNotEmpty) {
          item[field] = '$fileId:$value';
        }
      }
      for (final field in _listRefFields) {
        final value = item[field];
        if (value is List) {
          item[field] = [
            for (final ref in value)
              if (ref is String && ref.isNotEmpty) '$fileId:$ref' else ref,
          ];
        }
      }
    }

    if (type == ImportEntityType.equipmentSets) {
      final refs = item['equipmentRefs'];
      if (refs is List) {
        item['equipmentRefs'] = [
          for (final ref in refs)
            if (ref is String && ref.isNotEmpty) '$fileId:$ref' else ref,
        ];
      }
    }

    return item;
  }

  /// Cross-file fold key for reference entities; null means "never fold".
  String? _foldKey(ImportEntityType type, Map<String, dynamic> item) {
    final name = (item['name'] as String?)?.trim().toLowerCase();
    if (name == null || name.isEmpty) return null;

    switch (type) {
      case ImportEntityType.equipment:
        final typeValue = item['type'];
        final typeStr = typeValue is String
            ? typeValue.toLowerCase()
            : typeValue?.toString().toLowerCase() ?? 'other';
        return '$name|$typeStr';
      case ImportEntityType.certifications:
        final agency = item['agency'];
        final agencyStr = agency is String
            ? agency.toLowerCase()
            : agency?.toString().toLowerCase() ?? '';
        return '$name|$agencyStr';
      case ImportEntityType.dives:
        return null;
      case ImportEntityType.sites:
      case ImportEntityType.trips:
      case ImportEntityType.buddies:
      case ImportEntityType.diveCenters:
      case ImportEntityType.tags:
      case ImportEntityType.diveTypes:
      case ImportEntityType.courses:
      case ImportEntityType.equipmentSets:
        return name;
    }
  }

  void _rewriteAliases(
    Map<ImportEntityType, List<Map<String, dynamic>>> entities,
    Map<String, String> aliases,
  ) {
    if (aliases.isEmpty) return;

    String resolve(String id) => aliases[id] ?? id;

    for (final dive in entities[ImportEntityType.dives] ?? const []) {
      final site = dive['site'];
      if (site is Map<String, dynamic>) {
        final siteId = site['uddfId'];
        if (siteId is String) site['uddfId'] = resolve(siteId);
      }
      for (final field in _scalarRefFields) {
        final value = dive[field];
        if (value is String) dive[field] = resolve(value);
      }
      for (final field in _listRefFields) {
        final value = dive[field];
        if (value is List) {
          dive[field] = [
            for (final ref in value)
              if (ref is String) resolve(ref) else ref,
          ];
        }
      }
    }

    for (final set in entities[ImportEntityType.equipmentSets] ?? const []) {
      final refs = set['equipmentRefs'];
      if (refs is List) {
        set['equipmentRefs'] = [
          for (final ref in refs)
            if (ref is String) resolve(ref) else ref,
        ];
      }
    }
  }
}
```

Note: `ImportEntityType.values` iteration and the exhaustive switch must cover the real enum members (`dives, sites, trips, equipment, equipmentSets, buddies, diveCenters, certifications, courses, tags, diveTypes` — see `lib/features/universal_import/data/models/import_enums.dart:231`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/payload_merger_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/payload_merger.dart test/features/universal_import/data/services/payload_merger_test.dart
git commit -m "feat(import): add PayloadMerger for multi-file bulk import"
```

---

### Task 2: Intra-batch dive duplicate detection

**Files:**
- Modify: `lib/features/dive_import/domain/services/dive_matcher.dart` (add `inBatchIndex` to `DiveMatchResult`, ~line 79)
- Modify: `lib/features/universal_import/data/services/import_duplicate_checker.dart` (`check` at line 83, `_checkDiveDuplicates` at line 670)
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` (default-skip preselection ~line 273; bulk-consolidate eligibility ~line 512)
- Modify: `lib/features/import_wizard/presentation/widgets/entity_review_list.dart` (consolidate eligibility ~line 314)
- Modify: `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart` (guard `_buildExpanded` when `existingDiveId` is empty, ~line 126)
- Test: `test/features/universal_import/data/services/import_duplicate_checker_test.dart` (extend existing file)

**Interfaces:**
- Consumes: `DiveMatcher.calculateMatchScore(...)` / `isPossibleDuplicate(score)` (existing), `_sourceFile` key from Task 1.
- Produces: `DiveMatchResult.inBatchIndex` (`int?`, null for database matches; the earlier in-payload dive index for in-batch matches, with `diveId: ''`). `ImportDuplicateChecker.check(..., bool checkIntraBatch = false)`. Task 5 passes `checkIntraBatch: payload.metadata['batchFileCount'] != null && (payload.metadata['batchFileCount'] as int) > 1`.

- [ ] **Step 1: Write the failing tests** (append a group to the existing checker test file; mirror its existing helpers for building dives/payloads)

```dart
group('intra-batch dive duplicates', () {
  test('flags the later of two in-batch dives matching by sourceUuid', () {
    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'maxDepth': 18.0,
            'duration': const Duration(minutes: 45),
            'sourceUuid': 'uuid-1',
            '_sourceFile': 'a.fit',
          },
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'maxDepth': 18.0,
            'duration': const Duration(minutes: 45),
            'sourceUuid': 'uuid-1',
            '_sourceFile': 'b.uddf',
          },
        ],
      },
    );

    final result = const ImportDuplicateChecker().check(
      payload: payload,
      existingDives: const [],
      existingSites: const [],
      existingTrips: const [],
      existingEquipment: const [],
      existingBuddies: const [],
      existingDiveCenters: const [],
      existingCertifications: const [],
      existingTags: const [],
      existingDiveTypes: const [],
      checkIntraBatch: true,
    );

    expect(result.diveMatches, hasLength(1));
    final match = result.diveMatches[1]!;
    expect(match.inBatchIndex, 0);
    expect(match.diveId, '');
    expect(match.score, 1.0);
  });

  test('flags the later of two in-batch dives matching fuzzily', () {
    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9, 0),
            'maxDepth': 18.0,
            'duration': const Duration(minutes: 45),
          },
          {
            'dateTime': DateTime(2026, 1, 1, 9, 1), // 1 min apart
            'maxDepth': 18.2,
            'duration': const Duration(minutes: 44),
          },
        ],
      },
    );

    final result = const ImportDuplicateChecker().check(
      payload: payload,
      existingDives: const [],
      existingSites: const [],
      existingTrips: const [],
      existingEquipment: const [],
      existingBuddies: const [],
      existingDiveCenters: const [],
      existingCertifications: const [],
      existingTags: const [],
      existingDiveTypes: const [],
      checkIntraBatch: true,
    );

    expect(result.diveMatches.keys, [1]);
    expect(result.diveMatches[1]!.inBatchIndex, 0);
  });

  test('does not flag far-apart in-batch dives (time gate respected)', () {
    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'maxDepth': 18.0,
            'duration': const Duration(minutes: 45),
          },
          {
            'dateTime': DateTime(2026, 3, 1, 9), // months apart
            'maxDepth': 18.0,
            'duration': const Duration(minutes: 45),
          },
        ],
      },
    );

    final result = const ImportDuplicateChecker().check(
      payload: payload,
      existingDives: const [],
      existingSites: const [],
      existingTrips: const [],
      existingEquipment: const [],
      existingBuddies: const [],
      existingDiveCenters: const [],
      existingCertifications: const [],
      existingTags: const [],
      existingDiveTypes: const [],
      checkIntraBatch: true,
    );

    expect(result.diveMatches, isEmpty);
  });

  test('checkIntraBatch=false (default) preserves existing behavior', () {
    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'maxDepth': 18.0,
            'duration': const Duration(minutes: 45),
          },
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'maxDepth': 18.0,
            'duration': const Duration(minutes: 45),
          },
        ],
      },
    );

    final result = const ImportDuplicateChecker().check(
      payload: payload,
      existingDives: const [],
      existingSites: const [],
      existingTrips: const [],
      existingEquipment: const [],
      existingBuddies: const [],
      existingDiveCenters: const [],
      existingCertifications: const [],
      existingTags: const [],
      existingDiveTypes: const [],
    );

    expect(result.diveMatches, isEmpty);
  });

  test('in-batch duplicate is not double-reported against the database', () {
    // Dive 0 and dive 1 are the same dive; the DB also contains it.
    // Dive 1 must be reported as in-batch (of 0), dive 0 as a DB match.
    // Build an existing Dive entity the same way the file's other tests do.
    // ... use the existing test helpers in this file to construct `existing`.
  });
});
```

The last test's `existing` dive construction must copy the pattern already used in `import_duplicate_checker_test.dart` for DB-match tests (a `Dive` entity with `dateTime`, `maxDepth`, `runtime`). Fill it in from that file — do not invent a new construction style.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/import_duplicate_checker_test.dart`
Expected: FAIL — `checkIntraBatch` named parameter and `inBatchIndex` do not exist.

- [ ] **Step 3: Add `inBatchIndex` to `DiveMatchResult`**

In `lib/features/dive_import/domain/services/dive_matcher.dart`, add to the class (after `matchedExistingSource`):

```dart
  /// When non-null, this match is against ANOTHER DIVE IN THE SAME IMPORT
  /// BATCH (the dive at this payload index), not an existing database dive.
  /// [diveId] is empty for such matches. In-batch duplicates default to
  /// skip and are never eligible for consolidation (there is no existing
  /// dive to fold into).
  final int? inBatchIndex;
```

Add `this.inBatchIndex` to the constructor. If `DiveMatchResult` has a `copyWith`, extend it too.

- [ ] **Step 4: Add the intra-batch pass to `ImportDuplicateChecker`**

In `check(...)` add the parameter `bool checkIntraBatch = false` and pass it to `_checkDiveDuplicates`. In `_checkDiveDuplicates`, hoist the `handled` set declaration above pass 0, then insert BEFORE pass 0:

```dart
    // Pass I (batch imports only): match dives against EARLIER dives in the
    // same payload. Runs before the database passes so an in-batch duplicate
    // is not also double-reported against the database.
    if (checkIntraBatch) {
      final seenUuidAt = <String, int>{};
      for (var i = 0; i < importedDives.length; i++) {
        final uuid = importedDives[i]['sourceUuid'] as String?;
        if (uuid == null || uuid.isEmpty) continue;
        final earlier = seenUuidAt[uuid];
        if (earlier != null) {
          matches[i] = DiveMatchResult(
            diveId: '',
            inBatchIndex: earlier,
            score: _sourceUuidMatchScore,
            timeDifferenceMs: 0,
            siteName: importedDives[earlier]['_sourceFile'] as String?,
          );
          handled.add(i);
        } else {
          seenUuidAt[uuid] = i;
        }
      }

      for (var i = 1; i < importedDives.length; i++) {
        if (handled.contains(i)) continue;
        final dateTime = importedDives[i]['dateTime'] as DateTime?;
        if (dateTime == null) continue;
        final maxDepth = importedDives[i]['maxDepth'] as double? ?? 0;
        final durationSeconds =
            ((importedDives[i]['runtime'] as Duration?) ??
                    (importedDives[i]['duration'] as Duration?))
                ?.inSeconds ??
            0;

        for (var j = 0; j < i; j++) {
          if (handled.contains(j)) continue;
          final otherDateTime = importedDives[j]['dateTime'] as DateTime?;
          if (otherDateTime == null) continue;
          final otherDepth = importedDives[j]['maxDepth'] as double? ?? 0;
          final otherDuration =
              ((importedDives[j]['runtime'] as Duration?) ??
                      (importedDives[j]['duration'] as Duration?))
                  ?.inSeconds ??
              0;

          final score = matcher.calculateMatchScore(
            wearableStartTime: dateTime,
            wearableMaxDepth: maxDepth,
            wearableDurationSeconds: durationSeconds,
            existingStartTime: otherDateTime,
            existingMaxDepth: otherDepth,
            existingDurationSeconds: otherDuration,
          );

          if (matcher.isPossibleDuplicate(score)) {
            matches[i] = DiveMatchResult(
              diveId: '',
              inBatchIndex: j,
              score: score,
              timeDifferenceMs: dateTime
                  .difference(otherDateTime)
                  .inMilliseconds
                  .abs(),
              siteName: importedDives[j]['_sourceFile'] as String?,
            );
            handled.add(i);
            break;
          }
        }
      }
    }
```

- [ ] **Step 5: Exclude in-batch matches from consolidation and preselect skip**

In `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`:
- ~line 273: `if (match.matchedExistingSource) {` → `if (match.matchedExistingSource || match.inBatchIndex != null) {`
- ~line 512: append `&& match.inBatchIndex == null` to the consolidate-eligibility condition.

In `lib/features/import_wizard/presentation/widgets/entity_review_list.dart` ~line 314: append `&& match.inBatchIndex == null` to the same eligibility condition.

In `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart`, `_buildExpanded` (~line 126): before building `DiveComparisonCard`, add:

```dart
    if (widget.existingDiveId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.universalImport_review_inBatchDuplicate,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
```

(The l10n key is added in Task 3. If Task 3 has not run yet in your session, use the literal string `'Duplicate of another dive in this import batch.'` and leave a note; Task 3 replaces it.)

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/universal_import/data/services/import_duplicate_checker_test.dart`
Expected: PASS (new group and all pre-existing tests).

Run: `flutter test test/features/import_wizard/`
Expected: PASS (no regressions from the provider/widget edits). If this directory is too slow, run the specific provider/widget test files that exist in it.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "feat(import): detect duplicate dives across files within an import batch"
```

---

### Task 3: Localization strings for bulk import

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and all of `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

**Interfaces:**
- Produces l10n getters used by Tasks 2 and 5-9: exact key names below.

- [ ] **Step 1: Add English strings**

Add to `app_en.arb` (following the file's existing `universalImport_` section conventions, with `@`-metadata entries mirroring neighbors; `triage_parsing` and `triage_readyCount` use placeholders):

```json
"universalImport_action_selectFiles": "Select Files",
"universalImport_action_chooseFolder": "Choose Folder",
"universalImport_triage_title": "Files to Import",
"universalImport_triage_readyCount": "{count} {count, plural, =1{file} other{files}} ready to import",
"universalImport_triage_excludedCsv": "Import individually (CSV)",
"universalImport_triage_unsupported": "Unsupported format",
"universalImport_triage_parseFailed": "Could not be read",
"universalImport_triage_parsing": "Parsing file {current} of {total}…",
"universalImport_triage_cancelParsing": "Cancel",
"universalImport_triage_allExcluded": "None of the selected files can be imported together. CSV files must be imported one at a time.",
"universalImport_review_inBatchDuplicate": "Duplicate of another dive in this import batch.",
"universalImport_summary_filesTitle": "Files",
"universalImport_summary_fileImported": "{count} {count, plural, =1{dive} other{dives}} imported",
"universalImport_summary_fileNeedsIndividualImport": "Needs individual import",
"universalImport_summary_fileUnsupported": "Unsupported format",
"universalImport_summary_fileParseFailed": "Failed to read"
```

- [ ] **Step 2: Translate into all 10 other locales**

Add the same keys with translated values to each of ar, de, es, fr, he, hu, it, nl, pt, zh. Translate the values yourself (you are capable of this); match each locale's existing tone and any established translations of words like "file", "import", "duplicate" already present in that arb file. Preserve ICU plural syntax per locale (e.g. Arabic and Hebrew need the locale's plural categories if neighboring plurals in that file use them).

- [ ] **Step 3: Regenerate localizations and verify**

Run: `flutter gen-l10n`
Expected: exits 0, regenerated `app_localizations_*.dart` include the new getters.

Run: `flutter analyze`
Expected: no new issues. If Task 2 left the literal string in `duplicate_action_card.dart`, replace it now with `context.l10n.universalImport_review_inBatchDuplicate`.

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add lib/l10n
git add lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart
git commit -m "feat(l10n): add bulk import strings in all locales"
```

---

### Task 4: PickedImportFile model and state refactor

**Files:**
- Create: `lib/features/universal_import/data/models/picked_import_file.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_state.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart` (update every `copyWith(fileBytes:/fileName:)` call site)
- Test: `test/features/universal_import/data/models/picked_import_file_test.dart`
- Test: `test/features/universal_import/presentation/universal_import_state_test.dart` (create if absent)

**Interfaces:**
- Produces:

```dart
enum ImportFileStatus { pending, parsed, failed, excludedCsv, unsupported }

class PickedImportFile {
  final String name;
  final String? path;        // set for picker/drop files (bytes re-read lazily)
  final Uint8List? bytes;    // kept only when there is no path
  final DetectionResult detection;
  final ImportFileStatus status;
  final String? error;       // parse error message when status == failed
  final int diveCount;       // dives parsed from this file (0 until parsed)
  PickedImportFile copyWith({ImportFileStatus? status, String? error, int? diveCount});
}
```

- `UniversalImportState.files` (`List<PickedImportFile>`, default `const []`), `state.isBatch` (`files.length > 1`), `parseCurrent`/`parseTotal` (`int`, default 0). `fileBytes` and `fileName` become COMPUTED GETTERS (single-file compatibility):
  - `Uint8List? get fileBytes => files.length == 1 ? files.first.bytes : null;`
  - `String? get fileName => files.isEmpty ? null : (files.length == 1 ? files.first.name : '${files.length} files');`
- Tasks 5-9 rely on these exact names.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/universal_import/presentation/universal_import_state_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_state.dart';

PickedImportFile file(String name, {Uint8List? bytes, String? path}) {
  return PickedImportFile(
    name: name,
    path: path,
    bytes: bytes,
    detection: const DetectionResult(format: ImportFormat.uddf, confidence: 1),
    status: ImportFileStatus.pending,
  );
}

void main() {
  test('single file exposes fileBytes and fileName as before', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final state = UniversalImportState(files: [file('a.uddf', bytes: bytes)]);
    expect(state.fileName, 'a.uddf');
    expect(state.fileBytes, bytes);
    expect(state.isBatch, isFalse);
  });

  test('batch exposes a count label and null fileBytes', () {
    final state = UniversalImportState(
      files: [file('a.uddf', path: '/tmp/a'), file('b.fit', path: '/tmp/b')],
    );
    expect(state.fileName, '2 files');
    expect(state.fileBytes, isNull);
    expect(state.isBatch, isTrue);
  });

  test('copyWith replaces files and clearFiles empties them', () {
    final state = UniversalImportState(files: [file('a.uddf')]);
    final replaced = state.copyWith(files: [file('b.fit')]);
    expect(replaced.files.single.name, 'b.fit');
    expect(state.copyWith(clearFiles: true).files, isEmpty);
  });
}
```

Check `DetectionResult`'s actual constructor (`lib/features/universal_import/data/models/detection_result.dart`) — its `confidence` parameter may be `double` and required; match it.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/presentation/universal_import_state_test.dart`
Expected: FAIL — `picked_import_file.dart` does not exist; state has no `files`.

- [ ] **Step 3: Implement the model**

```dart
// lib/features/universal_import/data/models/picked_import_file.dart
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/detection_result.dart';

/// Lifecycle of one file within a bulk import batch.
enum ImportFileStatus {
  /// Detected as a supported, batchable format; awaiting parse.
  pending,

  /// Parsed successfully into the merged payload.
  parsed,

  /// Detection succeeded but parsing threw; the batch continues without it.
  failed,

  /// CSV: requires the single-file mapping wizard, excluded from batches.
  excludedCsv,

  /// Format not supported by any parser.
  unsupported,
}

/// One file selected for import (via picker, folder scan, or drop).
///
/// For picker/drop files [path] is set and [bytes] is null: bytes were read
/// once for format detection and discarded, then re-read lazily at parse
/// time so a large folder pick never holds every raw buffer at once.
class PickedImportFile {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final DetectionResult detection;
  final ImportFileStatus status;
  final String? error;
  final int diveCount;

  const PickedImportFile({
    required this.name,
    required this.detection,
    required this.status,
    this.path,
    this.bytes,
    this.error,
    this.diveCount = 0,
  });

  PickedImportFile copyWith({
    ImportFileStatus? status,
    String? error,
    int? diveCount,
  }) {
    return PickedImportFile(
      name: name,
      path: path,
      bytes: bytes,
      detection: detection,
      status: status ?? this.status,
      error: error ?? this.error,
      diveCount: diveCount ?? this.diveCount,
    );
  }
}
```

- [ ] **Step 4: Refactor `UniversalImportState`**

In `universal_import_state.dart`:
- Remove the `fileBytes` and `fileName` FIELDS (and their constructor/copyWith parameters).
- Add `final List<PickedImportFile> files;` (constructor default `const []`), `final int parseCurrent;`, `final int parseTotal;` (defaults 0).
- Add to `copyWith`: `List<PickedImportFile>? files, bool clearFiles = false, int? parseCurrent, int? parseTotal` with `files: clearFiles ? const [] : (files ?? this.files)`.
- Add `bool clearDetectionResult = false` to `copyWith` (`detectionResult: clearDetectionResult ? null : (detectionResult ?? this.detectionResult)`) — the existing null-keeps-old pattern would otherwise let a stale detection from a previous pick leak into a new batch.
- Add the computed getters and helper exactly as specified in Interfaces above, plus:

```dart
  /// True when more than one file was selected (batch import path).
  bool get isBatch => files.length > 1;

  /// Files awaiting batch parse.
  List<PickedImportFile> get pendingFiles =>
      [for (final f in files) if (f.status == ImportFileStatus.pending) f];
```

- [ ] **Step 5: Fix the notifier call sites (compile, no behavior change)**

In `universal_import_providers.dart`, replace every `copyWith(fileBytes: bytes, fileName: fileName, ...)` with a single-element files list:

```dart
        files: [
          PickedImportFile(
            name: fileName,
            bytes: bytes,
            detection: detection,
            status: ImportFileStatus.pending,
          ),
        ],
```

There are two such sites: `loadFileFromBytes` (~line 127) and `pickFile` (~line 188). `_parseAndCheckDuplicates` (~line 358) keeps reading `state.fileBytes` (now the getter). Search the whole repo for other `fileBytes:`/`fileName:` copyWith usages (`grep -rn "fileName:" lib/ | grep copyWith` style) and fix any stragglers — widgets only READ `state.fileName`, which still works.

- [ ] **Step 6: Run tests and analyze**

Run: `flutter test test/features/universal_import/presentation/universal_import_state_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: no errors (warnings pre-existing only).

Run: `flutter test test/features/universal_import/`
Expected: PASS — this directory is small enough; it guards the single-file flow.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "refactor(import): hold picked files as a list in wizard state"
```

---

### Task 5: Batch parse pipeline in the notifier

**Files:**
- Create: `lib/features/universal_import/data/parsers/parser_registry.dart` (extract format→parser mapping)
- Create: `lib/features/universal_import/data/services/batch_parse_service.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`
- Test: `test/features/universal_import/data/services/batch_parse_service_test.dart`

**Interfaces:**
- Consumes: `PayloadMerger`/`FilePayload` (Task 1), `PickedImportFile`/`ImportFileStatus` (Task 4), `checkIntraBatch` (Task 2).
- Produces:

```dart
// parser_registry.dart — non-CSV parser dispatch shared by single & batch paths
ImportParser parserForFormat(ImportFormat format);

// batch_parse_service.dart
class BatchParseResult {
  final List<FilePayload> parsed;
  final List<PickedImportFile> files; // same order, statuses/diveCount updated
  final bool cancelled;
}

class BatchParseService {
  const BatchParseService();
  Future<BatchParseResult> parseAll(
    List<PickedImportFile> files, {
    void Function(int current, int total)? onProgress,
    bool Function()? isCancelled,
  });
}
```

- Notifier gains: `pickFiles()` (replaces `pickFile()`; multi-select), `loadFilesFromPaths(List<String> paths)` (for drop target, Task 8), `cancelBatchParse()`; `confirmSource()` routes to `_parseBatch()` when `state.isBatch`.

- [ ] **Step 1: Extract the parser registry**

Create `parser_registry.dart` containing the non-CSV arm of the existing `_parserFor` switch (`universal_import_providers.dart:425`):

```dart
// lib/features/universal_import/data/parsers/parser_registry.dart
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/fit_import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/placeholder_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/shearwater_cloud_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

/// Parser for a self-describing (non-CSV) format. CSV needs per-file mapping
/// state and stays in the notifier's `_parserFor`.
ImportParser parserForFormat(ImportFormat format) {
  return switch (format) {
    ImportFormat.uddf => UddfImportParser(),
    ImportFormat.macdiveXml => const MacDiveXmlParser(),
    ImportFormat.macdiveSqlite => const MacDiveSqliteParser(),
    ImportFormat.subsurfaceXml => SubsurfaceXmlParser(),
    ImportFormat.fit => const FitImportParser(),
    ImportFormat.shearwaterDb => ShearwaterCloudParser(),
    _ => const PlaceholderParser(),
  };
}
```

Update the notifier's `_parserFor` to delegate its non-CSV arms to `parserForFormat(format)` (keep the CSV arm in place).

- [ ] **Step 2: Write the failing BatchParseService tests**

```dart
// test/features/universal_import/data/services/batch_parse_service_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/services/batch_parse_service.dart';

// The two Subsurface fixtures already in the repo.
const _fixtureDir = 'test/features/universal_import/data/parsers/fixtures';

PickedImportFile ssrfFile(String fixture) {
  return PickedImportFile(
    name: fixture,
    path: '$_fixtureDir/$fixture',
    detection: const DetectionResult(
      format: ImportFormat.subsurfaceXml,
      confidence: 1,
    ),
    status: ImportFileStatus.pending,
  );
}

void main() {
  const service = BatchParseService();

  test('parses all pending files and reports per-file dive counts', () async {
    final result = await service.parseAll([
      ssrfFile('dual-cylinder.ssrf'),
      ssrfFile('profile-events-variety.ssrf'),
    ]);

    expect(result.cancelled, isFalse);
    expect(result.parsed, hasLength(2));
    expect(result.files[0].status, ImportFileStatus.parsed);
    expect(result.files[1].status, ImportFileStatus.parsed);
    expect(result.files[0].diveCount, greaterThan(0));
  });

  test('a corrupt file is marked failed and the batch continues', () async {
    final corrupt = PickedImportFile(
      name: 'corrupt.uddf',
      bytes: Uint8List.fromList(utf8.encode('<uddf><broken')),
      detection: const DetectionResult(
        format: ImportFormat.uddf,
        confidence: 1,
      ),
      status: ImportFileStatus.pending,
    );

    final result = await service.parseAll([
      corrupt,
      ssrfFile('dual-cylinder.ssrf'),
    ]);

    expect(result.files[0].status, ImportFileStatus.failed);
    expect(result.files[0].error, isNotNull);
    expect(result.files[1].status, ImportFileStatus.parsed);
    expect(result.parsed, hasLength(1));
  });

  test('excluded and unsupported files are skipped untouched', () async {
    final csv = PickedImportFile(
      name: 'log.csv',
      bytes: Uint8List(0),
      detection: const DetectionResult(format: ImportFormat.csv, confidence: 1),
      status: ImportFileStatus.excludedCsv,
    );
    final result = await service.parseAll([csv, ssrfFile('dual-cylinder.ssrf')]);
    expect(result.files[0].status, ImportFileStatus.excludedCsv);
    expect(result.parsed, hasLength(1));
  });

  test('cancellation stops at the next file boundary', () async {
    var calls = 0;
    final result = await service.parseAll(
      [ssrfFile('dual-cylinder.ssrf'), ssrfFile('profile-events-variety.ssrf')],
      isCancelled: () => ++calls >= 2,
    );
    expect(result.cancelled, isTrue);
    expect(result.parsed.length, lessThan(2));
  });

  test('reports progress per file', () async {
    final seen = <(int, int)>[];
    await service.parseAll(
      [ssrfFile('dual-cylinder.ssrf'), ssrfFile('profile-events-variety.ssrf')],
      onProgress: (c, t) => seen.add((c, t)),
    );
    expect(seen, contains((1, 2)));
    expect(seen, contains((2, 2)));
  });
}
```

Note: a UDDF parser may swallow malformed XML into warnings instead of throwing; if the corrupt-file test fails because the parser returns an EMPTY payload rather than throwing, treat empty payloads as failures in the service (see Step 4 code, which does this).

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/batch_parse_service_test.dart`
Expected: FAIL — `batch_parse_service.dart` does not exist.

- [ ] **Step 4: Implement BatchParseService**

```dart
// lib/features/universal_import/data/services/batch_parse_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

/// Outcome of parsing a batch of files.
class BatchParseResult {
  final List<FilePayload> parsed;
  final List<PickedImportFile> files;
  final bool cancelled;

  const BatchParseResult({
    required this.parsed,
    required this.files,
    this.cancelled = false,
  });
}

/// Sequentially parses every pending file in a batch. Each file is isolated:
/// a parse failure marks that file failed and the batch continues. Bytes are
/// read lazily per file (path-backed files are only in memory while parsing).
class BatchParseService {
  const BatchParseService();

  Future<BatchParseResult> parseAll(
    List<PickedImportFile> files, {
    void Function(int current, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final updated = List<PickedImportFile>.of(files);
    final parsed = <FilePayload>[];
    final pendingTotal = files
        .where((f) => f.status == ImportFileStatus.pending)
        .length;
    var current = 0;

    for (var i = 0; i < updated.length; i++) {
      final file = updated[i];
      if (file.status != ImportFileStatus.pending) continue;

      if (isCancelled?.call() ?? false) {
        return BatchParseResult(
          parsed: parsed,
          files: updated,
          cancelled: true,
        );
      }

      current++;
      onProgress?.call(current, pendingTotal);

      try {
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();
        final parser = parserForFormat(file.detection.format);
        final options = ImportOptions(
          sourceApp: file.detection.sourceApp ?? SourceApp.generic,
          format: file.detection.format,
        );
        final payload = await parser.parse(bytes, options: options);

        if (payload.isEmpty) {
          final message = payload.warnings.isNotEmpty
              ? payload.warnings.first.message
              : 'No data could be parsed from the file';
          updated[i] = file.copyWith(
            status: ImportFileStatus.failed,
            error: message,
          );
          continue;
        }

        final diveCount = payload
            .entitiesOf(ImportEntityType.dives)
            .length;
        parsed.add(
          FilePayload(fileId: 'f$i', fileName: file.name, payload: payload),
        );
        updated[i] = file.copyWith(
          status: ImportFileStatus.parsed,
          diveCount: diveCount,
        );
      } catch (e) {
        updated[i] = file.copyWith(
          status: ImportFileStatus.failed,
          error: e.toString(),
        );
      }
    }

    return BatchParseResult(parsed: parsed, files: updated);
  }
}
```

Check `ImportOptions`'s constructor (`lib/features/universal_import/data/models/import_options.dart`) — the notifier builds it as `ImportOptions(sourceApp: ..., format: ...)`, so this matches.

- [ ] **Step 5: Run service tests**

Run: `flutter test test/features/universal_import/data/services/batch_parse_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Wire the notifier**

In `universal_import_providers.dart`:

1. Rename `pickFile()` to `pickFiles()` and change the picker call to `allowMultiple: true`. After a successful pick:

```dart
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      if (result.files.length == 1) {
        await _loadSingleFromPath(result.files.first);
        return;
      }

      await _loadBatchFromPaths([
        for (final f in result.files)
          if (f.path != null) f.path!,
      ]);
```

2. `_loadSingleFromPath(PlatformFile pickedFile)` is the existing single-file body of `pickFile()` (read bytes, `_detectFormat`, set one-element `files` list with `bytes` kept, `currentStep: sourceConfirmation`) — extract it verbatim.

3. Add the batch loader (also used by folder pick in Task 6 and drop in Task 8):

```dart
  /// Load many files by path: detect each (bytes read then discarded),
  /// classify CSV/unsupported as excluded, and enter the triage step.
  Future<void> _loadBatchFromPaths(List<String> paths) async {
    final files = <PickedImportFile>[];
    for (final path in paths) {
      final name = path.split(Platform.pathSeparator).last;
      try {
        final bytes = await File(path).readAsBytes();
        final detection = await _detectFormat(bytes);
        final status = detection.format == ImportFormat.csv
            ? ImportFileStatus.excludedCsv
            : detection.format.isSupported
            ? ImportFileStatus.pending
            : ImportFileStatus.unsupported;
        files.add(
          PickedImportFile(
            name: name,
            path: path,
            detection: detection,
            status: status,
          ),
        );
      } catch (e) {
        files.add(
          PickedImportFile(
            name: name,
            path: path,
            detection: const DetectionResult(
              format: ImportFormat.unknown,
              confidence: 0,
            ),
            status: ImportFileStatus.failed,
            error: e.toString(),
          ),
        );
      }
    }

    final firstPending = files.where(
      (f) => f.status == ImportFileStatus.pending,
    );
    state = state.copyWith(
      isLoading: false,
      files: files,
      // Gate providers key off detectionResult; use the first importable
      // file's detection so canAdvance behaves for batches too. When the
      // batch has no importable file, CLEAR any stale detection so the
      // wizard cannot advance past triage.
      detectionResult: firstPending.isNotEmpty
          ? firstPending.first.detection
          : null,
      clearDetectionResult: firstPending.isEmpty,
      currentStep: ImportWizardStep.sourceConfirmation,
    );
  }
```

4. Route `confirmSource()` for batches — insert at the very top of `confirmSource()`:

```dart
    if (state.isBatch) {
      await _parseBatch();
      return;
    }
```

5. Add batch parse + merge + dedup:

```dart
  bool _batchParseCancelled = false;

  /// Cooperative cancel; takes effect at the next file boundary.
  void cancelBatchParse() {
    _batchParseCancelled = true;
  }

  Future<void> _parseBatch() async {
    _batchParseCancelled = false;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      parseTotal: state.pendingFiles.length,
      parseCurrent: 0,
    );

    const service = BatchParseService();
    final result = await service.parseAll(
      state.files,
      onProgress: (current, total) {
        state = state.copyWith(parseCurrent: current, parseTotal: total);
      },
      isCancelled: () => _batchParseCancelled,
    );

    if (result.cancelled) {
      // Stay on triage; reset parse bookkeeping so a re-run starts clean.
      state = state.copyWith(
        isLoading: false,
        files: result.files,
        parseCurrent: 0,
        parseTotal: 0,
        currentStep: ImportWizardStep.sourceConfirmation,
      );
      return;
    }

    if (result.parsed.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        files: result.files,
        error: 'No data could be parsed from the selected files',
      );
      return;
    }

    final payload = const PayloadMerger().merge(result.parsed);
    final dupResult = await _checkDuplicates(payload);
    final selections = _defaultSelections(payload, dupResult);

    state = state.copyWith(
      isLoading: false,
      files: result.files,
      payload: payload,
      duplicateResult: dupResult,
      selections: selections,
      currentStep: ImportWizardStep.review,
    );
  }
```

6. Factor the default-selection block out of `_parseAndCheckDuplicates` (lines 392-408) into a private helper used by both paths:

```dart
  Map<ImportEntityType, Set<int>> _defaultSelections(
    ImportPayload payload,
    ImportDuplicateResult dupResult,
  ) {
    final selections = <ImportEntityType, Set<int>>{};
    for (final type in payload.availableTypes) {
      final items = payload.entitiesOf(type);
      final allIndices = Set<int>.from(List.generate(items.length, (i) => i));
      if (type == ImportEntityType.dives) {
        selections[type] = allIndices.difference(
          Set<int>.from(dupResult.diveMatches.keys),
        );
      } else {
        final dups = dupResult.duplicates[type] ?? const {};
        selections[type] = allIndices.difference(dups);
      }
    }
    return selections;
  }
```

7. Thread `checkIntraBatch` through `_checkDuplicates` — in its `checker.check(...)` call add:

```dart
      checkIntraBatch: (payload.metadata['batchFileCount'] as int? ?? 1) > 1,
```

Do the SAME in `UniversalAdapter.checkDuplicates` (`universal_adapter.dart:308`, the `checker.check(...)` call).

8. Update `FileSelectionStep`'s `onPressed` call from `.pickFile()` to `.pickFiles()` (`lib/features/universal_import/presentation/widgets/file_selection_step.dart:43`).

- [ ] **Step 7: Analyze and run the feature's tests**

Run: `flutter analyze`
Expected: no errors.

Run: `flutter test test/features/universal_import/`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "feat(import): batch parse pipeline with merge and cross-file dedup"
```

---

### Task 6: Folder pick and multi-select UI on the Select File step

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart` (add `pickFolder()`)
- Modify: `lib/features/universal_import/presentation/widgets/file_selection_step.dart`
- Test: `test/features/universal_import/presentation/file_selection_step_test.dart` (create if absent; check for an existing widget test first)

**Interfaces:**
- Consumes: `_loadBatchFromPaths` (Task 5), l10n keys `universalImport_action_selectFiles` / `universalImport_action_chooseFolder` (Task 3).
- Produces: `UniversalImportNotifier.pickFolder()`; static extension allowlist `BatchParseService.importableExtensions`.

- [ ] **Step 1: Add the extension allowlist and `pickFolder()`**

In `batch_parse_service.dart` add:

```dart
  /// File extensions worth scanning for in a folder pick.
  static const importableExtensions = {
    'fit',
    'uddf',
    'xml',
    'ssrf',
    'db',
    'sqlite',
    'csv', // included so CSVs surface in triage as "import individually"
  };
```

In the notifier add:

```dart
  /// Desktop only: pick a folder and recursively gather importable files.
  Future<void> pickFolder() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentStep: ImportWizardStep.fileSelection,
    );

    try {
      final dirPath = await FilePicker.getDirectoryPath();
      if (dirPath == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final paths = await scanFolderForImportableFiles(dirPath);
      if (paths.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No importable files found in the selected folder',
        );
        return;
      }

      if (paths.length == 1) {
        // Single hit: behave exactly like a single-file pick.
        final bytes = await File(paths.first).readAsBytes();
        final detection = await _detectFormat(bytes);
        state = state.copyWith(
          isLoading: false,
          files: [
            PickedImportFile(
              name: paths.first.split(Platform.pathSeparator).last,
              path: paths.first,
              bytes: bytes,
              detection: detection,
              status: ImportFileStatus.pending,
            ),
          ],
          detectionResult: detection,
          currentStep: ImportWizardStep.sourceConfirmation,
        );
        return;
      }

      await _loadBatchFromPaths(paths);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to scan folder: $e',
      );
    }
  }
```

And a top-level function in `batch_parse_service.dart` (testable without the notifier):

```dart
/// Recursively list files under [dirPath] whose extension is importable.
/// Hidden directories (dot-prefixed) are skipped. Results sorted by path
/// for a stable batch order.
Future<List<String>> scanFolderForImportableFiles(String dirPath) async {
  final paths = <String>[];
  await for (final entity in Directory(dirPath).list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final segments = entity.path.split(Platform.pathSeparator);
    if (segments.any((s) => s.startsWith('.'))) continue;
    final dot = entity.path.lastIndexOf('.');
    if (dot < 0) continue;
    final ext = entity.path.substring(dot + 1).toLowerCase();
    if (BatchParseService.importableExtensions.contains(ext)) {
      paths.add(entity.path);
    }
  }
  paths.sort();
  return paths;
}
```

- [ ] **Step 2: Write a unit test for the folder scan**

Append to `test/features/universal_import/data/services/batch_parse_service_test.dart`:

```dart
  test('scanFolderForImportableFiles filters by extension recursively',
      () async {
    final dir = await Directory.systemTemp.createTemp('bulk_scan_test');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/a.fit').writeAsBytes([0]);
    await Directory('${dir.path}/sub').create();
    await File('${dir.path}/sub/b.uddf').writeAsBytes([0]);
    await File('${dir.path}/notes.txt').writeAsBytes([0]);
    await Directory('${dir.path}/.hidden').create();
    await File('${dir.path}/.hidden/c.fit').writeAsBytes([0]);

    final paths = await scanFolderForImportableFiles(dir.path);
    expect(paths, hasLength(2));
    expect(paths.any((p) => p.endsWith('a.fit')), isTrue);
    expect(paths.any((p) => p.endsWith('b.uddf')), isTrue);
  });
```

Run: `flutter test test/features/universal_import/data/services/batch_parse_service_test.dart`
Expected: PASS.

- [ ] **Step 3: Update `FileSelectionStep`**

In `file_selection_step.dart`, replace the single button block (lines 22-45) with the pick-files button plus a desktop-only folder button:

```dart
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open),
              label: Text(
                state.isLoading
                    ? context.l10n.universalImport_label_detecting
                    : hasFile
                    ? context.l10n.universalImport_action_changeFile
                    : context.l10n.universalImport_action_selectFiles,
              ),
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(universalImportNotifierProvider.notifier)
                        .pickFiles(),
            ),
          ),
          if (_isDesktop) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: Text(context.l10n.universalImport_action_chooseFolder),
                onPressed: state.isLoading
                    ? null
                    : () => ref
                          .read(universalImportNotifierProvider.notifier)
                          .pickFolder(),
              ),
            ),
          ],
```

Add to the widget (mirroring `global_drop_target.dart:32`):

```dart
  static bool get _isDesktop {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }
```

with imports `import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;`. Also update the `hasFile` card so a batch shows the count (the `state.fileName` getter already yields "N files", so no change needed there).

- [ ] **Step 4: Widget test**

```dart
// test/features/universal_import/presentation/file_selection_step_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_selection_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget harness() {
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: FileSelectionStep()),
    ),
  );
}

void main() {
  testWidgets('desktop shows Choose Folder button', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(harness());
    expect(find.text('Choose Folder'), findsOneWidget);
    expect(find.text('Select Files'), findsOneWidget);
  });

  testWidgets('mobile hides Choose Folder button', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(harness());
    expect(find.text('Choose Folder'), findsNothing);
  });
}
```

Check the real import path for `AppLocalizations` (`lib/l10n/arb/app_localizations.dart` per the l10n.yaml `output-localization-file`) and how other widget tests in `test/features/universal_import/presentation/` build their harness — copy their pattern if one exists.

Run: `flutter test test/features/universal_import/presentation/file_selection_step_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "feat(import): multi-select picker and desktop folder pick"
```

---

### Task 7: File triage step

**Files:**
- Create: `lib/features/universal_import/presentation/widgets/file_triage_step.dart`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (Confirm Source step builder, line 159-169)
- Test: `test/features/universal_import/presentation/file_triage_step_test.dart`

**Interfaces:**
- Consumes: `state.files`, `state.isBatch`, `state.parseCurrent/parseTotal`, `cancelBatchParse()` (Tasks 4-5), l10n keys (Task 3).
- Produces: `FileTriageStep` widget; `SourceConfirmationOrTriageStep` dispatcher used by the adapter.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/universal_import/presentation/file_triage_step_test.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_triage_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

PickedImportFile file(String name, ImportFormat format, ImportFileStatus status) {
  return PickedImportFile(
    name: name,
    path: '/tmp/$name',
    detection: DetectionResult(format: format, confidence: 1),
    status: status,
  );
}

void main() {
  testWidgets('lists files with format names and greys excluded ones',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(universalImportNotifierProvider.notifier)
        .debugSetFilesForTest([
      file('a.fit', ImportFormat.fit, ImportFileStatus.pending),
      file('b.csv', ImportFormat.csv, ImportFileStatus.excludedCsv),
      file('c.xyz', ImportFormat.unknown, ImportFileStatus.unsupported),
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileTriageStep()),
        ),
      ),
    );

    expect(find.text('a.fit'), findsOneWidget);
    expect(find.text('Garmin FIT'), findsOneWidget);
    expect(find.text('Import individually (CSV)'), findsOneWidget);
    expect(find.text('Unsupported format'), findsOneWidget);
    expect(find.text('1 file ready to import'), findsOneWidget);
  });
}
```

Add the test hook to the notifier (visible-for-testing setter):

```dart
  @visibleForTesting
  void debugSetFilesForTest(List<PickedImportFile> files) {
    state = state.copyWith(
      files: files,
      currentStep: ImportWizardStep.sourceConfirmation,
    );
  }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/presentation/file_triage_step_test.dart`
Expected: FAIL — `file_triage_step.dart` does not exist.

- [ ] **Step 3: Implement FileTriageStep**

```dart
// lib/features/universal_import/presentation/widgets/file_triage_step.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Batch replacement for the Confirm Source step: lists every selected file
/// with its detected format and whether it will join the batch. Shows parse
/// progress with a cancel affordance while the batch is being parsed.
class FileTriageStep extends ConsumerWidget {
  const FileTriageStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final readyCount = state.files
        .where((f) =>
            f.status == ImportFileStatus.pending ||
            f.status == ImportFileStatus.parsed)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            readyCount > 0
                ? l10n.universalImport_triage_readyCount(readyCount)
                : l10n.universalImport_triage_allExcluded,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (state.isLoading) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: state.parseTotal > 0
                      ? state.parseCurrent / state.parseTotal
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.universalImport_triage_parsing(
                        state.parseCurrent,
                        state.parseTotal,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(universalImportNotifierProvider.notifier)
                          .cancelBatchParse(),
                      child: Text(l10n.universalImport_triage_cancelParsing),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: state.files.length,
            itemBuilder: (context, index) {
              final file = state.files[index];
              return _FileTriageTile(file: file);
            },
          ),
        ),
      ],
    );
  }
}

class _FileTriageTile extends StatelessWidget {
  const _FileTriageTile({required this.file});

  final PickedImportFile file;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final excluded = file.status == ImportFileStatus.excludedCsv ||
        file.status == ImportFileStatus.unsupported ||
        file.status == ImportFileStatus.failed;

    final (IconData icon, String? statusLabel) = switch (file.status) {
      ImportFileStatus.pending => (Icons.insert_drive_file, null),
      ImportFileStatus.parsed => (Icons.check_circle_outline, null),
      ImportFileStatus.failed => (
          Icons.error_outline,
          l10n.universalImport_triage_parseFailed,
        ),
      ImportFileStatus.excludedCsv => (
          Icons.block,
          l10n.universalImport_triage_excludedCsv,
        ),
      ImportFileStatus.unsupported => (
          Icons.help_outline,
          l10n.universalImport_triage_unsupported,
        ),
    };

    return ListTile(
      enabled: !excluded,
      leading: Icon(
        icon,
        color: excluded
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.primary,
      ),
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(statusLabel ?? file.detection.format.displayName),
    );
  }
}
```

- [ ] **Step 4: Swap the Confirm Source step builder in the adapter**

In `universal_adapter.dart`, replace the Confirm Source `builder` (line 162):

```dart
      builder: (context) => const SourceConfirmationOrTriageStep(),
```

and add at the bottom of the file (or in `file_triage_step.dart` — keep it with the triage widget):

```dart
/// Shows [FileTriageStep] for multi-file batches and the classic
/// [SourceConfirmationStep] for single files.
class SourceConfirmationOrTriageStep extends ConsumerWidget {
  const SourceConfirmationOrTriageStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBatch = ref.watch(
      universalImportNotifierProvider.select((s) => s.isBatch),
    );
    return isBatch ? const FileTriageStep() : const SourceConfirmationStep();
  }
}
```

(Place it in `file_triage_step.dart` with the needed imports; the adapter imports that file.)

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/universal_import/presentation/file_triage_step_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "feat(import): file triage step for multi-file batches"
```

---

### Task 8: Multi-file drag-and-drop (and dropped folders)

**Files:**
- Modify: `lib/shared/widgets/global_drop_target.dart` (`_handleDrop`, lines 58-105)
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart` (add `loadFilesFromPaths`)
- Test: none new (drop plumbing is platform I/O; the loader it calls is covered by Task 5's tests). Manual verification in Task 11.

**Interfaces:**
- Consumes: `_loadBatchFromPaths`, `scanFolderForImportableFiles` (Tasks 5-6).
- Produces: `UniversalImportNotifier.loadFilesFromPaths(List<String> paths)` — public wrapper:

```dart
  /// Load multiple files by path (drag-and-drop). Resets prior state and
  /// enters the triage step. Marks the load as external so the wizard does
  /// not reset it on init.
  Future<void> loadFilesFromPaths(List<String> paths) async {
    state = const UniversalImportState().copyWith(isLoading: true);
    await _loadBatchFromPaths(paths);
    state = state.copyWith(wasLoadedExternally: true);
  }
```

- [ ] **Step 1: Rework `_handleDrop`**

Replace the single-file section of `_handleDrop` (from the `// Read the first file only` comment through the `handleIncomingFile` call) with:

```dart
    // Expand any dropped folders (desktop) into their importable files.
    final paths = <String>[];
    for (final xFile in details.files) {
      final path = xFile.path;
      if (path.isEmpty) continue;
      if (FileSystemEntity.isDirectorySync(path)) {
        paths.addAll(await scanFolderForImportableFiles(path));
      } else {
        paths.add(path);
      }
    }

    if (paths.isEmpty) return;
    if (!mounted) return;

    if (paths.length > 1) {
      await ref
          .read(universalImportNotifierProvider.notifier)
          .loadFilesFromPaths(paths);
      if (!mounted) return;
      context.go('/transfer/import-wizard');
      return;
    }

    // Single file: keep the existing byte-based path (share-intent parity).
    final Uint8List bytes;
    try {
      bytes = await File(paths.first).readAsBytes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dropTarget_error_readFailed)),
        );
      }
      return;
    }

    if (!mounted) return;

    final shouldNavigate = await handleIncomingFile(
      bytes: bytes,
      fileName: paths.first.split(Platform.pathSeparator).last,
      currentPath: currentPath,
      notifier: ref.read(universalImportNotifierProvider.notifier),
      messenger: ScaffoldMessenger.of(context),
      unsupportedFileMessage: context.l10n.dropTarget_error_unsupportedFile,
    );
```

Add `import 'dart:io';` and the import for `scanFolderForImportableFiles` (`batch_parse_service.dart`). Keep the rest of the method (wizard-active guard, `shouldNavigate` navigation) as is.

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: no errors.

- [ ] **Step 3: Format and commit**

```bash
dart format .
git add -A lib
git commit -m "feat(import): accept multi-file and folder drops"
```

---

### Task 9: Source-file attribution in review and per-file summary

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (`_diveToEntityItem` ~line 550; `performImport` ~line 386)
- Modify: `lib/features/import_wizard/domain/models/unified_import_result.dart` (add `fileOutcomes`)
- Create: `lib/features/import_wizard/domain/models/import_file_outcome.dart`
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart` (render per-file section)
- Test: `test/features/import_wizard/import_file_outcome_test.dart`

**Interfaces:**
- Consumes: `_sourceFile` key (Task 1), `state.files` (Task 4).
- Produces:

```dart
enum ImportFileOutcomeStatus { imported, parseFailed, needsIndividualImport, unsupported }

class ImportFileOutcome {
  final String fileName;
  final String formatName;
  final ImportFileOutcomeStatus status;
  final int importedDives; // meaningful when status == imported
  final String? error;
}
```

and `UnifiedImportResult.fileOutcomes` (`List<ImportFileOutcome>`, default `const []`).

- [ ] **Step 1: Create the model + failing test**

```dart
// lib/features/import_wizard/domain/models/import_file_outcome.dart
/// Per-file result line shown on the bulk import summary.
enum ImportFileOutcomeStatus {
  imported,
  parseFailed,
  needsIndividualImport,
  unsupported,
}

class ImportFileOutcome {
  final String fileName;
  final String formatName;
  final ImportFileOutcomeStatus status;
  final int importedDives;
  final String? error;

  const ImportFileOutcome({
    required this.fileName,
    required this.formatName,
    required this.status,
    this.importedDives = 0,
    this.error,
  });
}
```

Add to `UnifiedImportResult` (check its constructor and any `copyWith`):

```dart
  /// Per-file outcomes for bulk imports; empty for single-file/DC imports.
  final List<ImportFileOutcome> fileOutcomes;
```

with constructor default `this.fileOutcomes = const []`.

Test (`test/features/import_wizard/import_file_outcome_test.dart`) — a construction smoke test plus the adapter mapping helper below:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/import_file_outcome.dart';

void main() {
  test('defaults', () {
    const outcome = ImportFileOutcome(
      fileName: 'a.fit',
      formatName: 'Garmin FIT',
      status: ImportFileOutcomeStatus.imported,
    );
    expect(outcome.importedDives, 0);
    expect(outcome.error, isNull);
  });
}
```

- [ ] **Step 2: Dive row attribution in review**

In `universal_adapter.dart` `_diveToEntityItem` (~line 569, the `parts` list), append after the duration part:

```dart
    final sourceFile = data['_sourceFile'] as String?;
    if (sourceFile != null && sourceFile.isNotEmpty) parts.add(sourceFile);
```

(Only merged payloads carry `_sourceFile`, so single-file review is unchanged.)

- [ ] **Step 3: Compute per-file outcomes in `performImport`**

At the end of `performImport` (before the final `return UnifiedImportResult(...)`), build outcomes when the batch has files:

```dart
    final pickedFiles = notifierState.files;
    var fileOutcomes = const <ImportFileOutcome>[];
    if (pickedFiles.length > 1) {
      // Count imported dives per source file. `result.diveIdByIndex` maps
      // payload dive index -> created dive id; exclude dives later removed
      // by consolidation cleanup.
      final dives = payload.entitiesOf(ui.ImportEntityType.dives);
      final importedByFile = <String, int>{};
      result.diveIdByIndex.forEach((index, diveId) {
        if (removedDiveIds.contains(diveId)) return;
        final source = dives[index]['_sourceFile'] as String?;
        if (source != null) {
          importedByFile[source] = (importedByFile[source] ?? 0) + 1;
        }
      });

      fileOutcomes = [
        for (final f in pickedFiles)
          ImportFileOutcome(
            fileName: f.name,
            formatName: f.detection.format.displayName,
            status: switch (f.status) {
              ImportFileStatus.parsed ||
              ImportFileStatus.pending =>
                ImportFileOutcomeStatus.imported,
              ImportFileStatus.failed => ImportFileOutcomeStatus.parseFailed,
              ImportFileStatus.excludedCsv =>
                ImportFileOutcomeStatus.needsIndividualImport,
              ImportFileStatus.unsupported =>
                ImportFileOutcomeStatus.unsupported,
            },
            importedDives: importedByFile[f.name] ?? 0,
            error: f.error,
          ),
      ];
    }
```

and add `fileOutcomes: fileOutcomes,` to the returned `UnifiedImportResult`. Verify the exact name of `result.diveIdByIndex` in `UddfEntityImportResult` (`lib/features/dive_import/data/services/uddf_entity_importer.dart`) — the codebase memory records it as `diveIdByIndex`; confirm and adjust. Imports needed: `import_file_outcome.dart`, `picked_import_file.dart`.

- [ ] **Step 4: Render the section in the summary step**

Read `lib/features/import_wizard/presentation/widgets/import_summary_step.dart` first. Insert, after the existing counts/consolidation section and following the file's layout idioms:

```dart
        if (result.fileOutcomes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            context.l10n.universalImport_summary_filesTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final outcome in result.fileOutcomes)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                switch (outcome.status) {
                  ImportFileOutcomeStatus.imported => Icons.check_circle_outline,
                  ImportFileOutcomeStatus.parseFailed => Icons.error_outline,
                  ImportFileOutcomeStatus.needsIndividualImport => Icons.block,
                  ImportFileOutcomeStatus.unsupported => Icons.help_outline,
                },
              ),
              title: Text(outcome.fileName, overflow: TextOverflow.ellipsis),
              subtitle: Text(switch (outcome.status) {
                ImportFileOutcomeStatus.imported => context.l10n
                    .universalImport_summary_fileImported(
                        outcome.importedDives),
                ImportFileOutcomeStatus.parseFailed =>
                  context.l10n.universalImport_summary_fileParseFailed,
                ImportFileOutcomeStatus.needsIndividualImport => context
                    .l10n.universalImport_summary_fileNeedsIndividualImport,
                ImportFileOutcomeStatus.unsupported =>
                  context.l10n.universalImport_summary_fileUnsupported,
              }),
            ),
        ],
```

Adapt variable names (`result`, `theme`) to what the widget actually has in scope.

- [ ] **Step 5: Run tests and analyze**

Run: `flutter test test/features/import_wizard/import_file_outcome_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: no errors.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "feat(import): per-file attribution in review and summary"
```

---

### Task 10: End-to-end batch integration test

**Files:**
- Test: `test/features/universal_import/bulk_import_integration_test.dart`

**Interfaces:**
- Consumes everything: `BatchParseService`, `PayloadMerger`, `ImportDuplicateChecker(checkIntraBatch: true)`, `UddfEntityImporter`.

- [ ] **Step 1: Study the existing round-trip test setup**

Read `test/features/dive_import/uddf_import_source_uuid_test.dart` — it builds an in-memory database, repositories, and runs `UddfEntityImporter.import`. Mirror its setup helpers exactly (database construction, `ImportRepositories`, diver creation).

- [ ] **Step 2: Write the integration test**

Test flow (real code following the studied setup):

1. Parse the two `.ssrf` fixtures via `BatchParseService.parseAll` (as in Task 5's test).
2. Additionally craft a third in-memory `FilePayload` whose payload contains one dive duplicating (same `dateTime`/`maxDepth`/`duration`) a dive from fixture 1, and a site named identically (different case) to a site in fixture 1 — this exercises fold + intra-batch dedup without needing a third fixture file.
3. `PayloadMerger().merge(...)` the three.
4. Assert: merged metadata `batchFileCount == 3`; the duplicated site appears ONCE in `entitiesOf(sites)`; every dive has `_sourceFile`.
5. Run `ImportDuplicateChecker().check(payload: merged, existingDives: [], ..., checkIntraBatch: true)` — assert the crafted duplicate dive is in `diveMatches` with `inBatchIndex` non-null and no other dive is flagged.
6. Import everything EXCEPT the in-batch duplicate (selections = all dive indices minus flagged ones; all sites/etc. selected) through `UddfEntityImporter.import` into the in-memory DB.
7. Assert: dive count in DB equals selected count; the folded site was created once; dives from both fixture files link to their sites (query dives and check `siteId` non-null for dives that referenced the folded site).
8. FK-ON round trip: after import, run `PRAGMA foreign_keys = ON; PRAGMA foreign_key_check;` via the database's `customSelect` and assert zero rows (see the [fk-off-tests] guidance: dive_log tests run FK OFF by default, so this pragma check is the guard).

- [ ] **Step 3: Run it**

Run: `flutter test test/features/universal_import/bulk_import_integration_test.dart`
Expected: PASS. Iterate on assertions if fixture contents differ from assumptions (e.g. site names in the `.ssrf` files) — inspect the fixtures rather than weakening assertions.

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add test/features/universal_import/bulk_import_integration_test.dart
git commit -m "test(import): end-to-end bulk import batch integration test"
```

---

### Task 11: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Whole-project analyze and format check**

Run: `flutter analyze`
Expected: zero errors, no new warnings versus main.

Run: `dart format --set-exit-if-changed .`
Expected: exit 0. If not, `dart format .` and amend/commit.

- [ ] **Step 2: Run the affected test suites (specific files, not broad dirs)**

```bash
flutter test test/features/universal_import/data/services/payload_merger_test.dart \
  test/features/universal_import/data/services/batch_parse_service_test.dart \
  test/features/universal_import/data/services/import_duplicate_checker_test.dart \
  test/features/universal_import/presentation/universal_import_state_test.dart \
  test/features/universal_import/presentation/file_selection_step_test.dart \
  test/features/universal_import/presentation/file_triage_step_test.dart \
  test/features/import_wizard/import_file_outcome_test.dart \
  test/features/universal_import/bulk_import_integration_test.dart
```

Expected: all PASS. Then run the pre-existing suites most likely to regress:

```bash
flutter test test/features/universal_import/data/services/format_detector_test.dart
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

- [ ] **Step 3: Manual smoke test on macOS (use the superpowers:verification-before-completion skill)**

Run: `flutter run -d macos`
- Pick 2+ files (mixed FIT/UDDF/ssrf) via Select Files → triage lists formats → Next parses with progress → merged review shows source-file subtitles → import → summary shows per-file table.
- Pick a single file → wizard behaves exactly as before (Confirm Source, CSV mapping if CSV).
- Drag 3 files onto the window → triage opens. Drag a folder → its importable files appear.
- Re-import the same batch → dives flagged as database duplicates.

- [ ] **Step 4: Commit any fixes, then report**

Report results honestly, including anything skipped (e.g. Windows/Linux folder pick untested).
