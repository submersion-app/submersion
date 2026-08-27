# Subsurface Picture Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the photos a Subsurface logbook references via `<picture>` elements, resolving each foreign absolute path against a user-picked media folder.

**Architecture:** A parsed `<picture>` becomes a payload entry under a new `ImportEntityType.media`. Resolution adds no matching logic: each entry is dressed as a transient unsaved `MediaItem` and fed through the existing media repair ladder (`FolderCandidateSource.harvest`, `detectPrefixMove`, `buildRepairProposals`). A conditional fourth acquisition step collects the folder and shows match counts, and the adapter attaches resolved files to dives through the existing `diveIdByIndex` map.

**Tech Stack:** Flutter, Dart, Riverpod, Drift, `xml` package, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-26-subsurface-picture-import-design.md`

## Global Constraints

- **No em-dashes (U+2014) anywhere**, including code, comments, commit messages, and ARB strings. En-dashes as prose punctuation and " - " as prose punctuation are equally forbidden. Pre-existing em-dashes in files you touch stay as they are; do not add new ones.
- **No emojis** in code, comments, or documentation.
- **Immutability:** never mutate a domain entity or a caller's list in place. The one sanctioned exception is `PayloadMerger`, which already mutates its own freshly-deep-copied maps; follow the file's existing style there.
- **File size:** 200-400 lines typical, 800 maximum.
- **TDD:** the failing test is written and observed failing before the implementation, every time.
- **l10n:** every new user-facing string is added to all 11 ARB files: `en, ar, de, es, fr, he, hu, it, nl, pt, zh`. `zh` plurals use only the `other` branch; every other locale uses `one` and `other`.
- **Run `dart format .`** before each commit.
- **Never pipe `flutter test` into another command**: the pipeline reports the second command's exit status, so a failure reads as a pass.
- **Do not run two `flutter test` invocations concurrently** in this worktree.
- Schema stays at 161. This feature adds no migration.

## File Structure

**Created**

| File | Responsibility |
| --- | --- |
| `lib/features/universal_import/domain/services/import_media_resolver.dart` | Format-agnostic resolution of payload media entries against a folder root. Owns `ImportMediaResolution`. |
| `lib/features/import_wizard/presentation/widgets/photo_folder_step.dart` | The Photos acquisition step widget, desktop picker and mobile notice. |
| `test/features/universal_import/domain/services/import_media_resolver_test.dart` | Resolver tests over a real temp tree. |
| `test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart` | Step widget tests. |

**Modified**

| File | Change |
| --- | --- |
| `lib/features/universal_import/data/models/import_enums.dart` | `ImportEntityType.media` plus its two switch arms. |
| `lib/features/import_wizard/domain/models/import_bundle.dart` | `ImportEntityType.media`. |
| `lib/features/universal_import/data/services/payload_merger.dart` | Media appended without folding; `_diveIndex` rebased per file. |
| `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` | `_collectPictures` on both dive-walk paths. |
| `lib/features/media/data/services/media_import_service.dart` | `importLocalFileForDive` gains `latitude`, `longitude`, `subdirectory`. |
| `lib/features/universal_import/presentation/providers/universal_import_state.dart` | Photo folder root, resolution, skip flag. |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | `pickPhotoFolder`, `skipPhotos` notifier methods. |
| `lib/features/import_wizard/data/adapters/universal_adapter.dart` | Fourth acquisition step, media group in `buildBundle`, commit path. |
| `lib/l10n/arb/app_*.arb` (11 files) | Seven new `importWizard_photos_*` keys. |

---

### Task 1: Payload slot for media

Adds the enum member to both `ImportEntityType` declarations and teaches `PayloadMerger` to carry media across a multi-file batch. Dart's exhaustive switches will point at every site that must be updated; work through the analyzer until it is clean.

**Files:**
- Modify: `lib/features/universal_import/data/models/import_enums.dart:261-303`
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart:25-58`
- Modify: `lib/features/universal_import/data/services/payload_merger.dart:49-108`, `:183-210`
- Test: `test/features/universal_import/data/services/payload_merger_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `ImportEntityType.media` in both enums. Payload media entry keys, relied on by every later task: `filename` (`String`, the foreign absolute path), `offsetSeconds` (`int?`), `latitude` (`double?`), `longitude` (`double?`), `_diveIndex` (`int`, index into the payload's dive list).

- [ ] **Step 1: Write the failing test**

Append to `test/features/universal_import/data/services/payload_merger_test.dart`, inside the existing top-level `main()`:

```dart
  group('media', () {
    test('rebases _diveIndex onto the merged dive list', () {
      ImportPayload payloadWith({
        required int diveCount,
        required List<int> pictureDiveIndices,
      }) {
        return ImportPayload(
          entities: {
            ImportEntityType.dives: [
              for (var i = 0; i < diveCount; i++)
                {'uddfId': 'd$i', 'dateTime': DateTime(2025, 1, 1 + i)},
            ],
            ImportEntityType.media: [
              for (final index in pictureDiveIndices)
                {
                  'filename': '/home/jai/Pictures/p$index.jpg',
                  'offsetSeconds': 200,
                  '_diveIndex': index,
                },
            ],
          },
        );
      }

      final merged = const PayloadMerger().merge([
        FilePayload(
          fileId: 'f0',
          fileName: 'first.ssrf',
          payload: payloadWith(diveCount: 2, pictureDiveIndices: [0, 1]),
        ),
        FilePayload(
          fileId: 'f1',
          fileName: 'second.ssrf',
          payload: payloadWith(diveCount: 3, pictureDiveIndices: [0, 2]),
        ),
      ]);

      final dives = merged.entitiesOf(ImportEntityType.dives);
      final media = merged.entitiesOf(ImportEntityType.media);
      expect(dives, hasLength(5));
      expect(media, hasLength(4));
      // First file's pictures keep their indices; second file's shift by 2.
      expect(media.map((m) => m['_diveIndex']), [0, 1, 2, 4]);
    });

    test('never folds two pictures with the same filename', () {
      final payload = ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {'uddfId': 'd0', 'dateTime': DateTime(2025, 1, 1)},
          ],
          ImportEntityType.media: [
            {'filename': '/p/same.jpg', '_diveIndex': 0},
            {'filename': '/p/same.jpg', '_diveIndex': 0},
          ],
        },
      );

      final merged = const PayloadMerger().merge([
        FilePayload(fileId: 'f0', fileName: 'a.ssrf', payload: payload),
      ]);

      expect(merged.entitiesOf(ImportEntityType.media), hasLength(2));
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/universal_import/data/services/payload_merger_test.dart`
Expected: FAIL. `ImportEntityType.media` is not defined, so the file does not compile.

- [ ] **Step 3: Add the enum member to the parser-facing enum**

In `lib/features/universal_import/data/models/import_enums.dart`, add `media` as the last member before the `;`, and an arm to each of the two switches:

```dart
enum ImportEntityType {
  dives,
  sites,
  trips,
  equipment,
  equipmentSets,
  buddies,
  diveCenters,
  certifications,
  courses,
  tags,
  diveTypes,
  serviceRecords,
  media;

  String get displayName => switch (this) {
    // ... existing arms unchanged ...
    serviceRecords => 'Service Records',
    media => 'Photos',
  };

  String get shortName => switch (this) {
    // ... existing arms unchanged ...
    serviceRecords => 'Service',
    media => 'Photos',
  };
}
```

- [ ] **Step 4: Add the enum member to the wizard-facing enum**

In `lib/features/import_wizard/domain/models/import_bundle.dart`, append to `ImportEntityType`:

```dart
  /// Courses.
  courses,

  /// Photos referenced by an imported logbook.
  media,
}
```

- [ ] **Step 5: Teach PayloadMerger to carry media**

In `payload_merger.dart`, inside `merge`, capture the dive offset at the top of the per-input loop and add a media branch alongside the existing dives branch:

```dart
    for (final input in inputs) {
      warnings.addAll(input.payload.warnings);

      // Dives are appended without folding, so each file's dive indices shift
      // by the number of dives already collected. Captured BEFORE this input's
      // dives are added, so media can rebase onto the merged dive list.
      final diveOffset = (entities[ImportEntityType.dives] ?? const []).length;

      for (final type in ImportEntityType.values) {
        final items = input.payload.entitiesOf(type);
        if (items.isEmpty) continue;

        for (final original in items) {
          final item = _namespaced(original, input.fileId, type);
          item['_sourceFile'] = input.fileName;
          // Display names can collide (same basename in different folders);
          // the id is the collision-free key for per-file attribution.
          item['_sourceFileId'] = input.fileId;

          // Two pictures of the same file are both real, so media never
          // folds. Its dive pointer is rebased onto the merged dive list.
          if (type == ImportEntityType.media) {
            final index = item['_diveIndex'];
            if (index is int) item['_diveIndex'] = index + diveOffset;
            (entities[type] ??= []).add(item);
            continue;
          }

          if (type == ImportEntityType.dives) {
            (entities[type] ??= []).add(item);
            continue;
          }
```

The rest of the loop body is unchanged.

- [ ] **Step 6: Add the exhaustive-switch arm in `_foldKey`**

Media reaches `_foldKey` only if the branch above is ever removed, but the switch must stay exhaustive. Extend the existing null-returning group in `payload_merger.dart:197`:

```dart
      case ImportEntityType.dives:
      // Service records are events, not named entities: two services on the
      // same item are both real and must never fold together.
      case ImportEntityType.serviceRecords:
      // Media is handled before this point and has no name to fold on.
      case ImportEntityType.media:
        return null;
```

- [ ] **Step 7: Fix every other exhaustive switch the analyzer reports**

Run: `flutter analyze lib test`
Expected: a list of non-exhaustive switch errors across the import wizard and parsers. For each, add a `media` arm that matches the neighbouring reference-entity behaviour (media is not a duplicate-checked entity and has no repository, so the correct arm is almost always the same one `serviceRecords` uses). Do not add speculative behaviour: the goal is only to restore exhaustiveness.

Repeat `flutter analyze lib test` until it reports no issues. Per the project's CI rule, infos count as failures.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/payload_merger_test.dart`
Expected: PASS, both new tests included.

- [ ] **Step 9: Commit**

```bash
dart format .
git add -A
git commit -m "feat(import): add a media entity type to the import payload

Media never folds across files and carries a _diveIndex pointer, which
PayloadMerger rebases onto the merged dive list.

Refs #1147"
```

---

### Task 2: Parse `<picture>` elements

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart:95-160` (both dive-walk paths), plus a new private method near `_collectTags` at `:452`
- Test: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

**Interfaces:**
- Consumes: `ImportEntityType.media` from Task 1.
- Produces: payload entries under `ImportEntityType.media` with the keys listed in Task 1's Produces block.

- [ ] **Step 1: Write the failing tests**

Append to `main()` in `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`:

```dart
  group('picture parsing', () {
    test('parses filename, offset and gps, pointing at the owning dive',
        () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='40:00 min'>
  <picture filename='/home/jai/Pictures/2025/dive042.jpg' offset='+3:20 min' gps='18.465562 -66.084902'/>
</dive>
</dives>
</divelog>
'''),
      );

      final media = result.entitiesOf(ImportEntityType.media);
      expect(media, hasLength(1));
      expect(media.first['filename'], '/home/jai/Pictures/2025/dive042.jpg');
      expect(media.first['offsetSeconds'], 200);
      expect(media.first['latitude'], closeTo(18.465562, 1e-6));
      expect(media.first['longitude'], closeTo(-66.084902, 1e-6));
      expect(media.first['_diveIndex'], 0);
    });

    test('parses a negative offset', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00'>
  <picture filename='/p/before.jpg' offset='-1:05 min'/>
</dive>
</dives>
</divelog>
'''),
      );

      final media = result.entitiesOf(ImportEntityType.media);
      expect(media.single['offsetSeconds'], -65);
    });

    test('keeps a picture whose offset is unparseable, with a null offset',
        () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00'>
  <picture filename='/p/odd.jpg' offset='not a duration'/>
</dive>
</dives>
</divelog>
'''),
      );

      final media = result.entitiesOf(ImportEntityType.media);
      expect(media, hasLength(1));
      expect(media.single['offsetSeconds'], isNull);
    });

    test('keeps a Windows path verbatim for the resolver to normalise',
        () async {
      final result = await parser.parse(
        xmlBytes(r'''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00'>
  <picture filename='C:\Users\jai\Pictures\dive042.jpg' offset='+1:00 min'/>
</dive>
</dives>
</divelog>
'''),
      );

      final media = result.entitiesOf(ImportEntityType.media);
      expect(media.single['filename'], r'C:\Users\jai\Pictures\dive042.jpg');
    });

    test('drops a picture with no filename and warns', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00'>
  <picture offset='+1:00 min'/>
</dive>
</dives>
</divelog>
'''),
      );

      expect(result.entitiesOf(ImportEntityType.media), isEmpty);
      expect(
        result.warnings.any((w) => w.entityType == ImportEntityType.media),
        isTrue,
      );
    });

    test('collects pictures from trip-wrapped dives too, with correct indices',
        () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<trip date='2025-01-15' location='Bonaire'>
  <dive number='1' date='2025-01-15' time='10:00:00'>
    <picture filename='/p/trip.jpg' offset='+1:00 min'/>
  </dive>
</trip>
<dive number='2' date='2025-01-16' time='10:00:00'>
  <picture filename='/p/solo.jpg' offset='+2:00 min'/>
</dive>
</dives>
</divelog>
'''),
      );

      final media = result.entitiesOf(ImportEntityType.media);
      expect(media, hasLength(2));
      // Trip dives are walked first, so the trip picture points at dive 0.
      expect(
        media.map((m) => [m['filename'], m['_diveIndex']]),
        [
          ['/p/trip.jpg', 0],
          ['/p/solo.jpg', 1],
        ],
      );
    });

    test('omits the media key entirely when a logbook has no pictures',
        () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00'/>
</dives>
</divelog>
'''),
      );

      expect(result.entities.containsKey(ImportEntityType.media), isFalse);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --name "picture parsing"`
Expected: FAIL. Every test reports an empty media list, because nothing parses pictures yet.

- [ ] **Step 3: Add the picture collector**

In `subsurface_xml_parser.dart`, add this method immediately after `_collectTags` (which ends at `:469`):

```dart
  /// Collects `<picture>` elements from [diveElement] into [allMedia].
  ///
  /// Subsurface stores an absolute path from the exporting machine, so
  /// `filename` is kept verbatim and resolved later against a user-picked
  /// folder. `offset` is signed and relative to dive start; a picture taken
  /// before the dive began carries a negative offset. An unparseable offset
  /// costs the picture its timestamp, not its import, so it is kept with a
  /// null offset.
  void _collectPictures(
    XmlElement diveElement,
    int diveIndex,
    List<Map<String, dynamic>> allMedia,
    List<ImportWarning> warnings,
  ) {
    for (final picture in diveElement.findElements('picture')) {
      final filename = picture.getAttribute('filename')?.trim();
      if (filename == null || filename.isEmpty) {
        warnings.add(
          const ImportWarning(
            severity: ImportWarningSeverity.warning,
            message: 'Skipped a photo with no filename',
            entityType: ImportEntityType.media,
          ),
        );
        continue;
      }

      final gps = _parseGpsPair(picture.getAttribute('gps'));
      allMedia.add({
        'filename': filename,
        'offsetSeconds': _parseSignedDurationSeconds(
          picture.getAttribute('offset'),
        ),
        'latitude': gps?.$1,
        'longitude': gps?.$2,
        '_diveIndex': diveIndex,
      });
    }
  }

  /// Parses a signed Subsurface duration: '+3:20 min', '-1:05 min', '3:20 min'.
  ///
  /// Returns null when the value is absent or malformed. The sign applies to
  /// the whole duration, so '-1:05 min' is -65 seconds, not -60 plus 5.
  static int? _parseSignedDurationSeconds(String? value) {
    if (value == null || value.isEmpty) return null;
    final trimmed = value.trim();
    final negative = trimmed.startsWith('-');
    final magnitude = (negative || trimmed.startsWith('+'))
        ? trimmed.substring(1)
        : trimmed;
    final seconds = _parseDurationSeconds(magnitude);
    if (seconds == null) return null;
    return negative ? -seconds : seconds;
  }

  /// Parses a Subsurface `gps` attribute: two space-separated decimal degrees.
  static (double, double)? _parseGpsPair(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length != 2) return null;
    final latitude = double.tryParse(parts[0]);
    final longitude = double.tryParse(parts[1]);
    if (latitude == null || longitude == null) return null;
    return (latitude, longitude);
  }
```

- [ ] **Step 4: Call the collector from both dive-walk paths**

In `parse`, declare the accumulator next to `allTags` and `allBuddies`:

```dart
      final allTags = <String, Map<String, dynamic>>{};
      final allBuddies = <String, Map<String, dynamic>>{};
      final allMedia = <Map<String, dynamic>>[];
```

In the trip-wrapped walk, after `_collectBuddies(...)` and before `dives.add(diveData)`:

```dart
              _collectTags(diveElement, diveData, allTags);
              _collectBuddies(diveElement, diveData, allBuddies);
              // dives.length is this dive's index, because the picture is
              // collected before the dive is appended.
              _collectPictures(diveElement, dives.length, allMedia, warnings);
              dives.add(diveData);
```

In the standalone walk, make the identical insertion:

```dart
            _collectTags(diveElement, diveData, allTags);
            _collectBuddies(diveElement, diveData, allBuddies);
            _collectPictures(diveElement, dives.length, allMedia, warnings);
            dives.add(diveData);
```

Then file the results alongside the other entity types, next to the existing `if (allTags.isNotEmpty)` block:

```dart
      if (allMedia.isNotEmpty) entities[ImportEntityType.media] = allMedia;
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: PASS, including the pre-existing tests in the file.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "feat(import): parse Subsurface <picture> elements

Collects filename, signed offset and gps from both dive-walk paths,
pointing each picture at its owning dive by index.

Refs #1147"
```

---

### Task 3: Import media resolver

Resolution reuses the media repair ladder wholesale. This task adds the adapter
between payload maps and that ladder, plus one prerequisite fix to the harvest.

**Prerequisite: the harvest's basename extraction is POSIX-only.**
`folder_candidate_source.dart:41` builds its filename index with
`path.lastIndexOf('/')`. On a Windows host `Directory.list` yields
`C:\Photos\dive042.jpg`, so that search returns -1 and the whole path becomes
the index key. Every filename lookup then misses. This is a pre-existing defect
in the repair feature, not something this feature introduces, but resolution
cannot work on Windows until it is fixed, and Windows is a first-class target
for this feature (many Subsurface users export from it).

The foreign side of the comparison has the mirror problem, and it is ours to
own: a logbook exported from Windows carries `C:\Users\jai\...` regardless of
which platform imports it, so the resolver must normalise the separators it
feeds the ladder rather than assuming the exporting machine matched this one.

Steps 1 and 2 below fix the harvest and commit it separately, so a reviewer can
judge that change on its own.

**Files:**
- Modify: `lib/features/media/data/services/repair/folder_candidate_source.dart:36-48`
- Create: `lib/features/universal_import/domain/services/import_media_resolver.dart`
- Test: `test/features/media/data/services/repair/folder_candidate_source_test.dart`
- Test: `test/features/universal_import/domain/services/import_media_resolver_test.dart`

**Interfaces:**
- Consumes: payload media entry keys from Task 1. `FolderCandidateSource` (`lib/features/media/data/services/repair/folder_candidate_source.dart:14`), `detectPrefixMove` and `buildRepairProposals` (`lib/features/media/domain/services/media_repair_matcher.dart:8`, `:83`), `RepairConfidence` and `RepairProposal` (`lib/features/media/domain/services/media_repair_types.dart:4`, `:65`).
- Produces:
  - `class ImportMediaResolution` with `final Map<int, String> resolvedPathByIndex`, `final int reRootedCount`, `final int filenameOnlyCount`, `final int notFoundCount`, and `int get matchedCount => resolvedPathByIndex.length`.
  - `class ImportMediaResolver` with `Future<ImportMediaResolution> resolve({required List<Map<String, dynamic>> media, required String rootPath})`.

- [ ] **Step 1: Make the harvest's basename extraction platform-correct**

Add a failing test to
`test/features/media/data/services/repair/folder_candidate_source_test.dart`
that asserts the index is keyed by basename, not by full path:

```dart
  test('indexes candidates by basename, not by full path', () async {
    final root = await Directory.systemTemp.createTemp('harvest_basename_');
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });
    final nested = Directory(p.join(root.path, 'Trips', 'Bonaire'));
    await nested.create(recursive: true);
    File(p.join(nested.path, 'dive042.jpg')).writeAsStringSync('bytes');

    final harvest =
        await FolderCandidateSource(roots: [root.path]).harvest(const []);

    expect(harvest.byFilename.keys, contains('dive042.jpg'));
  });
```

Run: `flutter test test/features/media/data/services/repair/folder_candidate_source_test.dart`
Expected: PASS on macOS and Linux, because `lastIndexOf('/')` happens to be
right there. The test exists to lock the contract in place before the change
and to fail on Windows, where the current code is broken.

Then replace the hand-rolled split at `folder_candidate_source.dart:41` with
the platform-aware helper, adding `import 'package:path/path.dart' as p;` to
the file's imports:

```dart
          final path = entity.path;
          // p.basename follows the host's separator. A hand-rolled
          // lastIndexOf('/') silently indexes the entire path as the key on
          // Windows, where Directory.list yields backslash-separated paths.
          final name = p.basename(path).toLowerCase();
```

Run the test file again and confirm it still passes.

- [ ] **Step 2: Commit the harvest fix**

```bash
dart format .
git add -A
git commit -m "fix(media): key the repair harvest by basename on every platform

lastIndexOf('/') indexed the whole path as the key on Windows, so every
filename lookup missed.

Refs #1147"
```

- [ ] **Step 3: Write the failing resolver tests**

Create `test/features/universal_import/domain/services/import_media_resolver_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/universal_import/domain/services/import_media_resolver.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('import_media_resolver_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<void> writeFile(String relativePath) async {
    final file = File(p.join(root.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString('bytes');
  }

  Map<String, dynamic> picture(String filename, {int index = 0}) => {
        'filename': filename,
        'offsetSeconds': 200,
        '_diveIndex': index,
      };

  test('re-roots a whole moved tree', () async {
    await writeFile(p.join('2025', 'dive042.jpg'));
    await writeFile(p.join('2025', 'dive043.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [
        picture('/home/jai/Pictures/2025/dive042.jpg'),
        picture('/home/jai/Pictures/2025/dive043.jpg', index: 1),
      ],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 2);
    expect(resolution.reRootedCount, 2);
    expect(resolution.filenameOnlyCount, 0);
    expect(resolution.notFoundCount, 0);
    expect(
      resolution.resolvedPathByIndex[0],
      p.join(root.path, '2025', 'dive042.jpg'),
    );
  });

  test('falls back to a filename match in a reorganised tree', () async {
    await writeFile(p.join('Archive', 'Bonaire', 'dive042.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [picture('/home/jai/Pictures/2025/dive042.jpg')],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 1);
    expect(resolution.filenameOnlyCount, 1);
    expect(resolution.reRootedCount, 0);
    expect(
      resolution.resolvedPathByIndex[0],
      p.join(root.path, 'Archive', 'Bonaire', 'dive042.jpg'),
    );
  });

  test('reports a picture that is nowhere under the root', () async {
    await writeFile(p.join('2025', 'other.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [picture('/home/jai/Pictures/2025/missing.jpg')],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 0);
    expect(resolution.notFoundCount, 1);
    expect(resolution.resolvedPathByIndex, isEmpty);
  });

  test('resolves an ambiguous filename to a single candidate', () async {
    await writeFile(p.join('a', 'dive042.jpg'));
    await writeFile(p.join('b', 'dive042.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [picture('/home/jai/Pictures/dive042.jpg')],
      rootPath: root.path,
    );

    // One picture yields at most one resolved path; which of the two
    // candidates wins is not contractual, only that it resolves exactly once
    // and is reported as a filename-only match.
    expect(resolution.matchedCount, 1);
    expect(resolution.filenameOnlyCount, 1);
  });

  test('reports every picture as not found when the root does not exist',
      () async {
    final resolution = await const ImportMediaResolver().resolve(
      media: [picture('/home/jai/Pictures/dive042.jpg')],
      rootPath: p.join(root.path, 'no-such-folder'),
    );

    expect(resolution.matchedCount, 0);
    expect(resolution.notFoundCount, 1);
  });

  test('resolves a path exported from Windows', () async {
    await writeFile(p.join('2025', 'dive042.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [picture(r'C:\Users\jai\Pictures\2025\dive042.jpg')],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 1);
    expect(
      resolution.resolvedPathByIndex[0],
      p.join(root.path, '2025', 'dive042.jpg'),
    );
  });

  test('foreignBasename treats both separators as separators', () {
    expect(foreignBasename(r'C:\Users\jai\dive.jpg'), 'dive.jpg');
    expect(foreignBasename('/home/jai/dive.jpg'), 'dive.jpg');
    expect(foreignBasename('dive.jpg'), 'dive.jpg');
  });

  test('skips a picture whose filename is missing or empty', () async {
    final resolution = await const ImportMediaResolver().resolve(
      media: [
        {'offsetSeconds': 1, '_diveIndex': 0},
        {'filename': '', '_diveIndex': 1},
      ],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 0);
    expect(resolution.notFoundCount, 2);
  });
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `flutter test test/features/universal_import/domain/services/import_media_resolver_test.dart`
Expected: FAIL. `import_media_resolver.dart` does not exist, so the file does not compile.

- [ ] **Step 5: Write the resolver**

Create `lib/features/universal_import/domain/services/import_media_resolver.dart`:

```dart
import 'package:submersion/features/media/data/services/repair/folder_candidate_source.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_matcher.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

/// The outcome of resolving a payload's media entries against a folder root.
class ImportMediaResolution {
  const ImportMediaResolution({
    required this.resolvedPathByIndex,
    required this.reRootedCount,
    required this.filenameOnlyCount,
    required this.notFoundCount,
  });

  const ImportMediaResolution.empty()
      : resolvedPathByIndex = const {},
        reRootedCount = 0,
        filenameOnlyCount = 0,
        notFoundCount = 0;

  /// Local path on this machine, keyed by the picture's index in the payload
  /// media list. A picture that resolved to nothing is absent.
  final Map<int, String> resolvedPathByIndex;

  /// Matched by re-rooting the whole moved tree. The strongest signal here:
  /// the picture sits at the same relative position it did on the exporting
  /// machine.
  final int reRootedCount;

  /// Matched on filename alone, somewhere under the root. Weaker: a
  /// reorganised library resolves this way, and so does a coincidence.
  final int filenameOnlyCount;

  /// Found nowhere under the root.
  final int notFoundCount;

  int get matchedCount => resolvedPathByIndex.length;
}

/// Resolves the foreign absolute paths a logbook references against a folder
/// the user picked on this machine.
///
/// Deliberately format-agnostic: it knows only the payload media contract
/// (`filename` plus a position in the list), so a UDDF `<link ref>` parser can
/// feed the same resolver without changing anything here.
///
/// No matching logic lives in this class. Resolution is the media repair
/// ladder, reached by dressing each picture as a transient unsaved
/// [MediaItem]: harvest the folder into a filename index, detect a wholesale
/// tree move, then run the ladder. Keeping the two features on one matcher
/// means a moved photo library is interpreted the same way whether the user
/// arrives via import or via repair.
class ImportMediaResolver {
  const ImportMediaResolver();

  Future<ImportMediaResolution> resolve({
    required List<Map<String, dynamic>> media,
    required String rootPath,
  }) async {
    if (media.isEmpty) return const ImportMediaResolution.empty();

    // A picture with no usable filename can never resolve, but it still has
    // to be counted, so it is excluded from the ladder and added to the
    // not-found tally at the end.
    final items = <int, MediaItem>{};
    for (var i = 0; i < media.length; i++) {
      final filename = (media[i]['filename'] as String?)?.trim();
      if (filename == null || filename.isEmpty) continue;
      items[i] = _transientItem(filename);
    }

    if (items.isEmpty) {
      return ImportMediaResolution(
        resolvedPathByIndex: const {},
        reRootedCount: 0,
        filenameOnlyCount: 0,
        notFoundCount: media.length,
      );
    }

    final indices = items.keys.toList();
    final rows = [for (final index in indices) items[index]!];

    final harvest = await FolderCandidateSource(roots: [rootPath]).harvest(rows);
    final prefixMove = detectPrefixMove(
      brokenPaths: [for (final row in rows) row.filePath!],
      foundPaths: harvest.foundPaths,
    );
    final proposals = buildRepairProposals(
      brokenRows: rows,
      candidatesByFilename: harvest.byFilename,
      prefixMove: prefixMove,
      foundPaths: harvest.foundPaths,
    );

    final resolved = <int, String>{};
    var reRooted = 0;
    var filenameOnly = 0;
    var notFound = media.length - items.length;

    for (var i = 0; i < proposals.length; i++) {
      final proposal = proposals[i];
      final path = proposal.candidate?.path;
      if (proposal.confidence == RepairConfidence.unmatched || path == null) {
        notFound++;
        continue;
      }
      resolved[indices[i]] = path;
      if (proposal.viaPrefixMove) {
        reRooted++;
      } else {
        filenameOnly++;
      }
    }

    return ImportMediaResolution(
      resolvedPathByIndex: resolved,
      reRootedCount: reRooted,
      filenameOnlyCount: filenameOnly,
      notFoundCount: notFound,
    );
  }

  /// A [MediaItem] that is never persisted. It exists only to satisfy the
  /// repair ladder's parameter type; the ladder reads `filePath` and
  /// `originalFilename` and nothing else.
  ///
  /// The path came from another machine, possibly another platform, so both
  /// fields are normalised here rather than left for the ladder to guess.
  /// `originalFilename` is set explicitly because the ladder prefers it over
  /// parsing the path, which spares it the separator question entirely.
  static MediaItem _transientItem(String foreignPath) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      filePath: foreignPath.replaceAll(r'\', '/'),
      originalFilename: foreignBasename(foreignPath),
      takenAt: epoch,
      createdAt: epoch,
      updatedAt: epoch,
    );
  }
}

/// Basename of a path produced by an unknown platform.
///
/// `p.basename` follows the HOST's separator, which is the wrong question for
/// a path that arrived in a file: a logbook exported from Windows carries
/// `C:\Users\jai\dive.jpg` no matter which platform imports it. Both
/// separators are therefore treated as separators, which is safe in practice
/// because a photo filename containing a literal backslash is vanishingly rare
/// next to the certainty of Windows-exported logbooks.
@visibleForTesting
String foreignBasename(String path) {
  final index = path.lastIndexOf(RegExp(r'[/\\]'));
  return index < 0 ? path : path.substring(index + 1);
}
```

Add `import 'package:flutter/foundation.dart' show visibleForTesting;` for the
annotation.

If `MediaItem`'s constructor rejects any of these arguments, read
`lib/features/media/domain/entities/media_item.dart:111-160` and supply exactly
the required parameters. Do not add fields the ladder does not read.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/universal_import/domain/services/import_media_resolver_test.dart`
Expected: PASS, all seven tests.

If the re-root test resolves as a filename-only match instead, check that
`detectPrefixMove` received at least two broken paths: it deliberately returns
null below two, because one coincidental filename is not evidence of a move.

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(import): resolve referenced photos against a picked folder

Dresses each payload media entry as a transient MediaItem and runs it
through the existing media repair ladder, so import and repair read a
moved photo library the same way.

Refs #1147"
```

---

### Task 4: Let the media writer carry coordinates and a destination

`importLocalFileForDive` is currently shaped for the OCR scan flow that
introduced it: it always writes into `scanned_logs/` and never sets
coordinates. Widen it without disturbing that caller.

**Files:**
- Modify: `lib/features/media/data/services/media_import_service.dart:70-100`
- Test: `test/features/media/data/services/media_import_service_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `importLocalFileForDive({required File sourceFile, required String diveId, DateTime? takenAt, double? latitude, double? longitude, String subdirectory = 'scanned_logs'})`.

- [ ] **Step 1: Write the failing test**

Append to `main()` in `test/features/media/data/services/media_import_service_test.dart`, following the file's existing setup for building a service with a fake repository and a temp documents directory:

```dart
  group('importLocalFileForDive coordinates and destination', () {
    test('stores coordinates and writes into the requested subdirectory',
        () async {
      final source = File(p.join(tempDir.path, 'photo.jpg'))
        ..writeAsStringSync('bytes');

      final created = await service.importLocalFileForDive(
        sourceFile: source,
        diveId: 'dive-1',
        takenAt: DateTime.utc(2025, 1, 15, 10, 3, 20),
        latitude: 18.465562,
        longitude: -66.084902,
        subdirectory: 'imported_photos',
      );

      expect(created.latitude, closeTo(18.465562, 1e-6));
      expect(created.longitude, closeTo(-66.084902, 1e-6));
      expect(created.takenAt, DateTime.utc(2025, 1, 15, 10, 3, 20));
      expect(p.basename(p.dirname(created.filePath!)), 'imported_photos');
    });

    test('defaults to scanned_logs with no coordinates', () async {
      final source = File(p.join(tempDir.path, 'scan.jpg'))
        ..writeAsStringSync('bytes');

      final created = await service.importLocalFileForDive(
        sourceFile: source,
        diveId: 'dive-1',
      );

      expect(created.latitude, isNull);
      expect(created.longitude, isNull);
      expect(p.basename(p.dirname(created.filePath!)), 'scanned_logs');
    });
  });
```

If the test file has no shared `service` and `tempDir`, build them inside the
group exactly as the file's existing groups do. Do not introduce a second
fake repository style.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/media/data/services/media_import_service_test.dart --name "coordinates and destination"`
Expected: FAIL. `latitude`, `longitude` and `subdirectory` are not named parameters of `importLocalFileForDive`.

- [ ] **Step 3: Widen the method**

In `media_import_service.dart`, replace the signature and the two lines that
depend on it:

```dart
  /// Copies [sourceFile] into the app documents directory (subdir
  /// [subdirectory]) and creates a localFile media row linked to [diveId].
  ///
  /// [subdirectory] defaults to 'scanned_logs' for the OCR scan flow that
  /// introduced this method; file imports pass their own so an imported
  /// logbook's photos are not filed as scanned pages.
  ///
  /// [latitude] and [longitude] are the photo's own coordinates when the
  /// source recorded them, which is not the same as the dive site's.
  Future<MediaItem> importLocalFileForDive({
    required File sourceFile,
    required String diveId,
    DateTime? takenAt,
    double? latitude,
    double? longitude,
    String subdirectory = 'scanned_logs',
  }) async {
    final docs = await _documentsDirectory();
    final dir = Directory(p.join(docs.path, subdirectory));
    await dir.create(recursive: true);
    final sourceExt = p.extension(sourceFile.path);
    final ext = sourceExt.isEmpty ? '.jpg' : sourceExt;
    final destName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = await sourceFile.copy(p.join(dir.path, destName));
    final now = DateTime.now();
    final item = MediaItem(
      id: '',
      diveId: diveId,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      filePath: dest.path,
      originalFilename: p.basename(sourceFile.path),
      latitude: latitude,
      longitude: longitude,
      takenAt: takenAt ?? now,
      createdAt: now,
      updatedAt: now,
    );
    final created = await _mediaRepository.createMedia(item);
    onMediaCreated?.call(created.id);
    return created;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/media/data/services/media_import_service_test.dart`
Expected: PASS, including the pre-existing tests.

- [ ] **Step 5: Check the destination-name collision guard**

`destName` is a millisecond timestamp. Two photos copied inside the same
millisecond would collide and the second `copy` would overwrite the first.
Confirm whether the existing code already guards this. If it does not, add a
counter suffix mirroring `zip_expansion_service.dart:210`:

```dart
    var destName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    var destPath = p.join(dir.path, destName);
    var counter = 1;
    while (File(destPath).existsSync()) {
      destName = '${DateTime.now().millisecondsSinceEpoch}_${counter++}$ext';
      destPath = p.join(dir.path, destName);
    }
    final dest = await sourceFile.copy(destPath);
```

Add a test that imports two files back to back and asserts two distinct
`filePath` values.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "feat(media): let importLocalFileForDive carry coordinates and a destination

The OCR caller keeps its scanned_logs default; file imports pass their
own subdirectory and the photo's own coordinates.

Refs #1147"
```

---

### Task 5: Wizard state for the photo folder

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_state.dart:64-170`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`
- Test: `test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`

**Interfaces:**
- Consumes: `ImportMediaResolver` and `ImportMediaResolution` from Task 3, `ImportEntityType.media` from Task 1.
- Produces:
  - `UniversalImportState` fields `final String? photoFolderPath`, `final ImportMediaResolution? photoResolution`, `final bool photosSkipped`, all threaded through `copyWith`.
  - Notifier methods `Future<void> resolvePhotosIn(String rootPath)` and `void skipPhotos()`.
  - `final universalAdapterPhotosReadyProvider` and `final universalAdapterNoPhotosProvider`, both `Provider<bool>`.

- [ ] **Step 1: Write the failing test**

Append to the notifier test file:

```dart
  group('photo folder resolution', () {
    test('resolvePhotosIn stores the root and the resolution', () async {
      final root = await Directory.systemTemp.createTemp('wizard_photos_');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });
      final photo = File(p.join(root.path, 'dive042.jpg'))
        ..writeAsStringSync('bytes');

      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        universalImportNotifierProvider.notifier,
      );

      notifier.debugSetPayload(
        ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'uddfId': 'd0', 'dateTime': DateTime(2025, 1, 15)},
            ],
            ImportEntityType.media: [
              {
                'filename': '/home/jai/Pictures/dive042.jpg',
                '_diveIndex': 0,
              },
            ],
          },
        ),
      );

      await notifier.resolvePhotosIn(root.path);

      final state = container.read(universalImportNotifierProvider);
      expect(state.photoFolderPath, root.path);
      expect(state.photoResolution?.matchedCount, 1);
      expect(state.photoResolution?.resolvedPathByIndex[0], photo.path);
      expect(state.photosSkipped, isFalse);
    });

    test('skipPhotos clears any resolution and marks the step done', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        universalImportNotifierProvider.notifier,
      );

      notifier.skipPhotos();

      final state = container.read(universalImportNotifierProvider);
      expect(state.photosSkipped, isTrue);
      expect(state.photoResolution, isNull);
      expect(container.read(universalAdapterPhotosReadyProvider), isTrue);
    });

    test('the step is ready with no pictures and not ready with unhandled ones',
        () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        universalImportNotifierProvider.notifier,
      );

      notifier.debugSetPayload(
        const ImportPayload(entities: {}),
      );
      expect(container.read(universalAdapterNoPhotosProvider), isTrue);
      expect(container.read(universalAdapterPhotosReadyProvider), isTrue);

      notifier.debugSetPayload(
        ImportPayload(
          entities: {
            ImportEntityType.media: [
              {'filename': '/p/a.jpg', '_diveIndex': 0},
            ],
          },
        ),
      );
      expect(container.read(universalAdapterNoPhotosProvider), isFalse);
      expect(container.read(universalAdapterPhotosReadyProvider), isFalse);
    });
  });
```

If the test file has no `buildContainer` helper or no way to seed a payload,
follow whatever seam the file's existing tests use. If it needs a new test-only
seam, add `@visibleForTesting void debugSetPayload(ImportPayload payload)` to
the notifier rather than reaching into private state.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_notifier_test.dart --name "photo folder resolution"`
Expected: FAIL to compile: `photoFolderPath`, `resolvePhotosIn`, `skipPhotos` and the two providers do not exist.

- [ ] **Step 3: Add the state fields**

In `universal_import_state.dart`, add three fields near `photoPathsByBaseName`
at `:77`, with the same documentation density as its neighbours:

```dart
  /// Folder the user picked to resolve a logbook's referenced photos against.
  /// Null until the Photos step runs, and on mobile where it cannot be picked.
  final String? photoFolderPath;

  /// Outcome of resolving the payload's media entries against
  /// [photoFolderPath]. Null when no folder has been picked.
  final ImportMediaResolution? photoResolution;

  /// True once the user has explicitly chosen to import without photos.
  /// Distinct from a null [photoResolution], which only means undecided.
  final bool photosSkipped;
```

Add them to the constructor with `this.photosSkipped = false`, and thread all
three through `copyWith`. Both nullable fields must be clearable, so each gets
a `clearX` flag exactly as `clearPayload` does at
`universal_import_state.dart:187`. The exact `copyWith` body lines are given in
Step 4.

- [ ] **Step 4: Add the notifier methods and providers**

In `universal_import_providers.dart`:

```dart
  /// Resolves the payload's referenced photos against [rootPath].
  ///
  /// Never throws into the wizard: a scan failure resolves to zero matches and
  /// the user can pick a different folder or skip. Photos must not be able to
  /// block a dive import.
  Future<void> resolvePhotosIn(String rootPath) async {
    final media = state.payload?.entitiesOf(ImportEntityType.media);
    if (media == null || media.isEmpty) return;

    state = state.copyWith(photoFolderPath: rootPath, isLoading: true);
    ImportMediaResolution resolution;
    try {
      resolution = await const ImportMediaResolver().resolve(
        media: media,
        rootPath: rootPath,
      );
    } catch (e) {
      _log.warning('Photo resolution failed under $rootPath: $e');
      resolution = ImportMediaResolution(
        resolvedPathByIndex: const {},
        reRootedCount: 0,
        filenameOnlyCount: 0,
        notFoundCount: media.length,
      );
    }
    state = state.copyWith(
      photoResolution: resolution,
      photosSkipped: false,
      isLoading: false,
    );
  }

  /// Proceeds without photos.
  void skipPhotos() {
    state = state.copyWith(
      photosSkipped: true,
      clearPhotoResolution: true,
      clearPhotoFolderPath: true,
    );
  }
```

`clearPhotoResolution` and `clearPhotoFolderPath` follow the file's existing
`clearX` flag convention (`clearPayload` at
`universal_import_state.dart:187`, applied at `:238` as
`payload: clearPayload ? null : (payload ?? this.payload)`). Add both flags to
the `copyWith` parameter list and apply them the same way:

```dart
      photoFolderPath: clearPhotoFolderPath
          ? null
          : (photoFolderPath ?? this.photoFolderPath),
      photoResolution: clearPhotoResolution
          ? null
          : (photoResolution ?? this.photoResolution),
      photosSkipped: photosSkipped ?? this.photosSkipped,
```

Add a `LoggerService` field if the notifier does not already have one, matching
its neighbours.

Then add the two providers next to `universalAdapterMappingReadyProvider`:

```dart
/// True when the parsed payload references no photos at all. Used as the
/// Photos step's auto-advance condition, so the step is invisible for every
/// import that has nothing to resolve.
final universalAdapterNoPhotosProvider = Provider<bool>((ref) {
  final payload = ref.watch(
    universalImportNotifierProvider.select((s) => s.payload),
  );
  return (payload?.entitiesOf(ImportEntityType.media) ?? const []).isEmpty;
});

/// True when the Photos step has nothing left to ask. Deliberately looser
/// than [universalAdapterNoPhotosProvider]: a user who picked a folder or
/// chose to skip may advance, but the step is never auto-advanced past a
/// decision they have not made.
final universalAdapterPhotosReadyProvider = Provider<bool>((ref) {
  if (ref.watch(universalAdapterNoPhotosProvider)) return true;
  final state = ref.watch(universalImportNotifierProvider);
  return state.photosSkipped || state.photoResolution != null;
});
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`
Expected: PASS, including the pre-existing tests.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "feat(import): hold the picked photo folder and its resolution in wizard state

Refs #1147"
```

---

### Task 6: The Photos step widget

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/photo_folder_step.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the other 10 ARB files
- Test: `test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart`

**Interfaces:**
- Consumes: `universalAdapterNoPhotosProvider`, `universalImportNotifierProvider`, `resolvePhotosIn`, `skipPhotos` from Task 5.
- Produces: `class PhotoFolderStep extends ConsumerWidget` with `const PhotoFolderStep({super.key, this.pickFolderOverride})` where `pickFolderOverride` is `Future<String?> Function()?`, injected so widget tests never open a native picker. `media_sources_section_view.dart:64` already uses exactly this seam; follow it.

- [ ] **Step 1: Add the English strings**

Add to `lib/l10n/arb/app_en.arb`, keeping the file's alphabetical-ish grouping
with the other `importWizard_` keys:

```json
  "importWizard_photos_stepLabel": "Photos",
  "@importWizard_photos_stepLabel": {
    "description": "Wizard step label for resolving photos referenced by an imported logbook"
  },
  "importWizard_photos_foundCount": "{count, plural, one{1 photo referenced in this logbook} other{{count} photos referenced in this logbook}}",
  "@importWizard_photos_foundCount": {
    "description": "Count of photos the imported logbook refers to",
    "placeholders": {"count": {"type": "int"}}
  },
  "importWizard_photos_chooseFolder": "Choose photo folder...",
  "@importWizard_photos_chooseFolder": {
    "description": "Button that opens a folder picker for locating referenced photos"
  },
  "importWizard_photos_scanning": "Scanning folder...",
  "@importWizard_photos_scanning": {
    "description": "Progress label while the picked folder is being scanned"
  },
  "importWizard_photos_matchSummary": "{matched} matched, {byName} by filename only, {missing} not found",
  "@importWizard_photos_matchSummary": {
    "description": "Result of resolving referenced photos against the picked folder",
    "placeholders": {"matched": {"type": "int"}, "byName": {"type": "int"}, "missing": {"type": "int"}}
  },
  "importWizard_photos_skip": "Skip photos",
  "@importWizard_photos_skip": {
    "description": "Button to continue the import without photos"
  },
  "importWizard_photos_mobileUnsupported": "Importing photos needs a folder on this device's disk. Run this import on a computer to include them. Dives and sites import normally.",
  "@importWizard_photos_mobileUnsupported": {
    "description": "Shown on mobile, where a photo folder cannot be picked"
  },
```

- [ ] **Step 2: Add the same keys to the other 10 ARB files**

Add the value lines (no `@` metadata blocks: those live only in `app_en.arb`)
to each of `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`,
`app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`.

`de`:
```json
  "importWizard_photos_stepLabel": "Fotos",
  "importWizard_photos_foundCount": "{count, plural, one{1 Foto in diesem Logbuch referenziert} other{{count} Fotos in diesem Logbuch referenziert}}",
  "importWizard_photos_chooseFolder": "Fotoordner wählen...",
  "importWizard_photos_scanning": "Ordner wird durchsucht...",
  "importWizard_photos_matchSummary": "{matched} zugeordnet, {byName} nur über den Dateinamen, {missing} nicht gefunden",
  "importWizard_photos_skip": "Fotos überspringen",
  "importWizard_photos_mobileUnsupported": "Für den Fotoimport wird ein Ordner auf dem Speicher dieses Geräts benötigt. Führe diesen Import an einem Computer aus, um Fotos einzuschließen. Tauchgänge und Tauchplätze werden normal importiert.",
```

`es`:
```json
  "importWizard_photos_stepLabel": "Fotos",
  "importWizard_photos_foundCount": "{count, plural, one{1 foto referenciada en este cuaderno} other{{count} fotos referenciadas en este cuaderno}}",
  "importWizard_photos_chooseFolder": "Elegir carpeta de fotos...",
  "importWizard_photos_scanning": "Explorando la carpeta...",
  "importWizard_photos_matchSummary": "{matched} coincidencias, {byName} solo por nombre de archivo, {missing} no encontradas",
  "importWizard_photos_skip": "Omitir fotos",
  "importWizard_photos_mobileUnsupported": "Importar fotos requiere una carpeta en el disco de este dispositivo. Ejecuta esta importación en un ordenador para incluirlas. Las inmersiones y los puntos de buceo se importan con normalidad.",
```

`fr`:
```json
  "importWizard_photos_stepLabel": "Photos",
  "importWizard_photos_foundCount": "{count, plural, one{1 photo référencée dans ce carnet} other{{count} photos référencées dans ce carnet}}",
  "importWizard_photos_chooseFolder": "Choisir un dossier de photos...",
  "importWizard_photos_scanning": "Analyse du dossier...",
  "importWizard_photos_matchSummary": "{matched} associées, {byName} par nom de fichier uniquement, {missing} introuvables",
  "importWizard_photos_skip": "Ignorer les photos",
  "importWizard_photos_mobileUnsupported": "L'import de photos nécessite un dossier sur le disque de cet appareil. Lancez cet import sur un ordinateur pour les inclure. Les plongées et les sites s'importent normalement.",
```

`it`:
```json
  "importWizard_photos_stepLabel": "Foto",
  "importWizard_photos_foundCount": "{count, plural, one{1 foto referenziata in questo diario} other{{count} foto referenziate in questo diario}}",
  "importWizard_photos_chooseFolder": "Scegli la cartella delle foto...",
  "importWizard_photos_scanning": "Scansione della cartella...",
  "importWizard_photos_matchSummary": "{matched} associate, {byName} solo per nome file, {missing} non trovate",
  "importWizard_photos_skip": "Salta le foto",
  "importWizard_photos_mobileUnsupported": "L'importazione delle foto richiede una cartella sul disco di questo dispositivo. Esegui questa importazione su un computer per includerle. Immersioni e siti vengono importati normalmente.",
```

`nl`:
```json
  "importWizard_photos_stepLabel": "Foto's",
  "importWizard_photos_foundCount": "{count, plural, one{1 foto waarnaar dit logboek verwijst} other{{count} foto's waarnaar dit logboek verwijst}}",
  "importWizard_photos_chooseFolder": "Fotomap kiezen...",
  "importWizard_photos_scanning": "Map wordt gescand...",
  "importWizard_photos_matchSummary": "{matched} gekoppeld, {byName} alleen op bestandsnaam, {missing} niet gevonden",
  "importWizard_photos_skip": "Foto's overslaan",
  "importWizard_photos_mobileUnsupported": "Voor het importeren van foto's is een map op de schijf van dit apparaat nodig. Voer deze import uit op een computer om ze mee te nemen. Duiken en duikstekken worden normaal geïmporteerd.",
```

`pt`:
```json
  "importWizard_photos_stepLabel": "Fotos",
  "importWizard_photos_foundCount": "{count, plural, one{1 foto referenciada neste diário} other{{count} fotos referenciadas neste diário}}",
  "importWizard_photos_chooseFolder": "Escolher pasta de fotos...",
  "importWizard_photos_scanning": "A analisar a pasta...",
  "importWizard_photos_matchSummary": "{matched} correspondidas, {byName} apenas pelo nome do ficheiro, {missing} não encontradas",
  "importWizard_photos_skip": "Ignorar fotos",
  "importWizard_photos_mobileUnsupported": "Importar fotos requer uma pasta no disco deste dispositivo. Execute esta importação num computador para as incluir. Os mergulhos e locais são importados normalmente.",
```

`hu`:
```json
  "importWizard_photos_stepLabel": "Fényképek",
  "importWizard_photos_foundCount": "{count, plural, one{1 fénykép szerepel ebben a naplóban} other{{count} fénykép szerepel ebben a naplóban}}",
  "importWizard_photos_chooseFolder": "Fényképmappa kiválasztása...",
  "importWizard_photos_scanning": "Mappa vizsgálata...",
  "importWizard_photos_matchSummary": "{matched} párosítva, {byName} csak fájlnév alapján, {missing} nem található",
  "importWizard_photos_skip": "Fényképek kihagyása",
  "importWizard_photos_mobileUnsupported": "A fényképek importálásához az eszköz lemezén lévő mappa szükséges. Futtasd ezt az importálást számítógépen, hogy a fényképek is bekerüljenek. A merülések és a merülőhelyek normálisan importálódnak.",
```

`ar`:
```json
  "importWizard_photos_stepLabel": "الصور",
  "importWizard_photos_foundCount": "{count, plural, one{صورة واحدة مشار إليها في هذا السجل} other{{count} صور مشار إليها في هذا السجل}}",
  "importWizard_photos_chooseFolder": "اختر مجلد الصور...",
  "importWizard_photos_scanning": "جارٍ فحص المجلد...",
  "importWizard_photos_matchSummary": "{matched} مطابقة، {byName} بالاسم فقط، {missing} غير موجودة",
  "importWizard_photos_skip": "تخطي الصور",
  "importWizard_photos_mobileUnsupported": "يتطلب استيراد الصور مجلدًا على قرص هذا الجهاز. شغّل هذا الاستيراد على جهاز كمبيوتر لتضمينها. تُستورد الغطسات والمواقع بشكل طبيعي.",
```

`he`:
```json
  "importWizard_photos_stepLabel": "תמונות",
  "importWizard_photos_foundCount": "{count, plural, one{תמונה אחת מוזכרת ביומן הזה} other{{count} תמונות מוזכרות ביומן הזה}}",
  "importWizard_photos_chooseFolder": "בחר תיקיית תמונות...",
  "importWizard_photos_scanning": "סורק את התיקייה...",
  "importWizard_photos_matchSummary": "{matched} הותאמו, {byName} לפי שם קובץ בלבד, {missing} לא נמצאו",
  "importWizard_photos_skip": "דלג על התמונות",
  "importWizard_photos_mobileUnsupported": "ייבוא תמונות מחייב תיקייה בדיסק של המכשיר הזה. הרץ את הייבוא במחשב כדי לכלול אותן. צלילות ואתרים מיובאים כרגיל.",
```

`zh` (plural uses only the `other` branch, matching the file's convention):
```json
  "importWizard_photos_stepLabel": "照片",
  "importWizard_photos_foundCount": "{count, plural, other{此日志引用了 {count} 张照片}}",
  "importWizard_photos_chooseFolder": "选择照片文件夹...",
  "importWizard_photos_scanning": "正在扫描文件夹...",
  "importWizard_photos_matchSummary": "已匹配 {matched} 张，仅按文件名匹配 {byName} 张，未找到 {missing} 张",
  "importWizard_photos_skip": "跳过照片",
  "importWizard_photos_mobileUnsupported": "导入照片需要此设备磁盘上的文件夹。请在电脑上运行此导入以包含照片。潜水记录和潜点会正常导入。",
```

- [ ] **Step 3: Regenerate localizations and verify**

Run: `flutter gen-l10n`
Then: `flutter analyze lib`
Expected: no issues. CI regenerates l10n but never verifies it, so a
generation failure caught here is one that would otherwise reach main.

- [ ] **Step 4: Write the failing widget tests**

Create `test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/import_wizard/presentation/widgets/photo_folder_step.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        // Pin the locale: an unpinned host adopts the test device locale and
        // the string assertions below stop matching.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('shows the referenced photo count and a folder button',
      (tester) async {
    final root = await Directory.systemTemp.createTemp('photo_step_');
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });
    File(p.join(root.path, 'dive042.jpg')).writeAsStringSync('bytes');

    await tester.pumpWidget(
      host(
        PhotoFolderStep(pickFolderOverride: () async => root.path),
        overrides: [/* seed a payload carrying one picture */],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 photo referenced in this logbook'), findsOneWidget);
    expect(find.text('Choose photo folder...'), findsOneWidget);

    await tester.tap(find.text('Choose photo folder...'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 matched'), findsOneWidget);
  });

  testWidgets('offers to skip photos', (tester) async {
    await tester.pumpWidget(
      host(
        const PhotoFolderStep(),
        overrides: [/* seed a payload carrying one picture */],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Skip photos'), findsOneWidget);
  });

  testWidgets('explains the limitation instead of picking on mobile',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      host(
        const PhotoFolderStep(),
        overrides: [/* seed a payload carrying one picture */],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose photo folder...'), findsNothing);
    expect(
      find.textContaining('Run this import on a computer'),
      findsOneWidget,
    );
  });
}
```

Replace each `/* seed a payload carrying one picture */` comment with the
override that seeds this payload, using whichever seam the wizard's existing
widget tests use for the same job:

```dart
ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {'uddfId': 'd0', 'dateTime': DateTime(2025, 1, 15)},
    ],
    ImportEntityType.media: [
      {'filename': '/home/jai/Pictures/dive042.jpg', '_diveIndex': 0},
    ],
  },
)
```

- [ ] **Step 5: Run the tests to verify they fail**

Run: `flutter test test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart`
Expected: FAIL. `photo_folder_step.dart` does not exist.

- [ ] **Step 6: Write the widget**

Create `lib/features/import_wizard/presentation/widgets/photo_folder_step.dart`.
It is a `ConsumerWidget` with these rules:

- Read the payload's media count. Render
  `context.l10n.importWizard_photos_foundCount(count)`.
- On a desktop platform (`Platform.isMacOS || Platform.isWindows || Platform.isLinux`,
  guarded so it is testable via `defaultTargetPlatform`), render a button
  labelled `importWizard_photos_chooseFolder` that calls
  `pickFolderOverride?.call() ?? FilePicker.getDirectoryPath()` and, on a
  non-null result, `resolvePhotosIn(path)`.
- While `isLoading`, render `importWizard_photos_scanning` with a progress
  indicator.
- Once `photoResolution` is non-null, render
  `importWizard_photos_matchSummary(matched, byName, missing)` using
  `matchedCount`, `filenameOnlyCount` and `notFoundCount`. Show the picked
  folder path underneath.
- On a non-desktop platform, render `importWizard_photos_mobileUnsupported`
  and no picker.
- Always render a `importWizard_photos_skip` action that calls `skipPhotos()`.

Follow `media_sources_section_view.dart:60-80` for the picker seam and
`media_repair_wizard_page.dart` for the pane layout idiom. Keep the file under
200 lines; if it grows past that, the summary block is the natural private
widget to extract.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart`
Expected: PASS, all three tests.

- [ ] **Step 8: Commit**

```bash
dart format .
git add -A
git commit -m "feat(import): add the Photos step for locating referenced photos

Desktop picks a folder and sees the match counts; mobile is told plainly
that photo import needs a computer rather than silently receiving a
subset.

Refs #1147"
```

---

### Task 7: Wire the step into the wizard and attach the photos

The last task connects the pieces: register the step, surface the media group
in Review, and write the resolved files at commit.

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart:176-207` (step registration), `:224-299` (`buildBundle`), `:578-596` (commit), `:870-935` (`attachImportedPhotos` neighbourhood)
- Test: `test/features/import_wizard/data/adapters/universal_adapter_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1 through 6.
- Produces: no new public API. `UnifiedImportResult.attachedPhotoCount` and `.unmatchedPhotoCount` (already declared at `unified_import_result.dart:34` and `:39`) gain a second producer.

- [ ] **Step 1: Write the failing test**

Append to `test/features/import_wizard/data/adapters/universal_adapter_test.dart`:

```dart
  group('resolved photo attachment', () {
    test('attaches each resolved photo to its own dive', () async {
      final attached = <({String path, String diveId, DateTime? takenAt})>[];

      final count = await UniversalImportAdapter.attachResolvedPhotos(
        media: [
          {
            'filename': '/home/jai/Pictures/a.jpg',
            'offsetSeconds': 200,
            '_diveIndex': 0,
          },
          {
            'filename': '/home/jai/Pictures/b.jpg',
            'offsetSeconds': null,
            '_diveIndex': 1,
          },
        ],
        resolvedPathByIndex: const {
          0: '/Users/eric/Photos/a.jpg',
          1: '/Users/eric/Photos/b.jpg',
        },
        diveIdByIndex: const {0: 'dive-a', 1: 'dive-b'},
        removedDiveIds: const {},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
          {'dateTime': DateTime.utc(2025, 1, 16, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          attached.add((path: file.path, diveId: diveId, takenAt: takenAt));
        },
      );

      expect(count, 2);
      expect(attached[0].diveId, 'dive-a');
      // Dive start plus the 3:20 offset.
      expect(attached[0].takenAt, DateTime.utc(2025, 1, 15, 10, 3, 20));
      expect(attached[1].diveId, 'dive-b');
      // No offset: falls back to the dive's own start.
      expect(attached[1].takenAt, DateTime.utc(2025, 1, 16, 10));
    });

    test('drops photos whose dive was folded away by consolidation', () async {
      var attachCalls = 0;

      final count = await UniversalImportAdapter.attachResolvedPhotos(
        media: [
          {'filename': '/p/a.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
        ],
        resolvedPathByIndex: const {0: '/Users/eric/Photos/a.jpg'},
        diveIdByIndex: const {0: 'dive-a'},
        removedDiveIds: const {'dive-a'},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          attachCalls++;
        },
      );

      expect(count, 0);
      expect(attachCalls, 0);
    });

    test('counts a failed copy without failing the import', () async {
      final count = await UniversalImportAdapter.attachResolvedPhotos(
        media: [
          {'filename': '/p/a.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
          {'filename': '/p/b.jpg', 'offsetSeconds': 0, '_diveIndex': 0},
        ],
        resolvedPathByIndex: const {0: '/x/a.jpg', 1: '/x/b.jpg'},
        diveIdByIndex: const {0: 'dive-a'},
        removedDiveIds: const {},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          if (file.path.endsWith('b.jpg')) {
            throw const FileSystemException('copy failed');
          }
        },
      );

      expect(count, 1);
    });

    test('passes the picture coordinates through', () async {
      double? seenLatitude;

      await UniversalImportAdapter.attachResolvedPhotos(
        media: [
          {
            'filename': '/p/a.jpg',
            'offsetSeconds': 0,
            'latitude': 18.465562,
            'longitude': -66.084902,
            '_diveIndex': 0,
          },
        ],
        resolvedPathByIndex: const {0: '/x/a.jpg'},
        diveIdByIndex: const {0: 'dive-a'},
        removedDiveIds: const {},
        dives: [
          {'dateTime': DateTime.utc(2025, 1, 15, 10)},
        ],
        attach: (file, diveId, takenAt, latitude, longitude) async {
          seenLatitude = latitude;
        },
      );

      expect(seenLatitude, closeTo(18.465562, 1e-6));
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart --name "resolved photo attachment"`
Expected: FAIL. `attachResolvedPhotos` is not defined.

- [ ] **Step 3: Write the attach helper**

In `universal_adapter.dart`, add this static method next to
`attachImportedPhotos` at `:879`. It is deliberately static and pure so it can
be tested without a container, exactly as its neighbour is:

```dart
  /// Attaches resolved photos to the dives that survived import.
  ///
  /// Each payload media entry names its dive by `_diveIndex`, so unlike
  /// [attachImportedPhotos] this needs no one-dive-per-file rule: a
  /// multi-dive logbook attaches each photo to exactly the dive that
  /// referenced it.
  ///
  /// A copy failure is counted and skipped rather than thrown: the dive
  /// import has already succeeded and must not be undone by a photo. Unlike
  /// [attachImportedPhotos], the failure is not silent, because the caller
  /// reports the shortfall against the resolved count.
  ///
  /// Returns the number of photos actually attached.
  static Future<int> attachResolvedPhotos({
    required List<Map<String, dynamic>> media,
    required Map<int, String> resolvedPathByIndex,
    required Map<int, String> diveIdByIndex,
    required Set<String> removedDiveIds,
    required List<Map<String, dynamic>> dives,
    required Future<void> Function(
      File file,
      String diveId,
      DateTime? takenAt,
      double? latitude,
      double? longitude,
    ) attach,
  }) async {
    var attachedCount = 0;

    for (final entry in resolvedPathByIndex.entries) {
      final mediaIndex = entry.key;
      if (mediaIndex < 0 || mediaIndex >= media.length) continue;
      final picture = media[mediaIndex];

      final diveIndex = picture['_diveIndex'];
      if (diveIndex is! int) continue;
      final diveId = diveIdByIndex[diveIndex];
      if (diveId == null || removedDiveIds.contains(diveId)) continue;

      DateTime? takenAt;
      if (diveIndex >= 0 && diveIndex < dives.length) {
        final start = dives[diveIndex]['dateTime'] as DateTime?;
        final offsetSeconds = picture['offsetSeconds'];
        takenAt = start == null
            ? null
            : (offsetSeconds is int
                ? start.add(Duration(seconds: offsetSeconds))
                : start);
      }

      try {
        await attach(
          File(entry.value),
          diveId,
          takenAt,
          asDoubleOrNull(picture['latitude']),
          asDoubleOrNull(picture['longitude']),
        );
        attachedCount++;
      } catch (e) {
        _log.warning('Failed to attach imported photo ${entry.value}: $e');
      }
    }

    return attachedCount;
  }
```

If the file has no `_log`, use whatever logging idiom the adapter already uses.
`asDoubleOrNull` is already imported in this file (it is used by
`_diveToEntityItem` at `:689`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart --name "resolved photo attachment"`
Expected: PASS, all four tests.

- [ ] **Step 5: Register the Photos step**

In `acquisitionSteps` at `:176`, append a fourth step after Map Fields:

```dart
    WizardStepDef(
      label: 'Photos',
      icon: Icons.photo_library_outlined,
      builder: (context) => const PhotoFolderStep(),
      canAdvance: universalAdapterPhotosReadyProvider,
      // Stricter than canAdvance on purpose: the step auto-skips only when
      // the logbook references no photos at all, never past a decision the
      // user has not made.
      canAutoAdvance: universalAdapterNoPhotosProvider,
      autoAdvance: true,
    ),
```

- [ ] **Step 6: Surface the media group in Review**

In `buildBundle` at `:285`, after the courses group:

```dart
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.media,
      payload.entitiesOf(ui.ImportEntityType.media),
      _mediaToEntityItem,
    );
```

And add the converter next to `_courseToEntityItem` at `:860`:

```dart
  EntityItem _mediaToEntityItem(Map<String, dynamic> data) {
    final filename = (data['filename'] as String?) ?? '';
    final base = filename.isEmpty ? 'Unnamed' : p.basename(filename);
    return EntityItem(title: base, subtitle: filename);
  }
```

- [ ] **Step 7: Call the attach helper at commit**

In the commit path at `:578`, immediately after the existing
`attachImportedPhotos` call, add the resolved-photo attachment. Both can run:
they cover different sources and neither double-counts, because ZIP sidecars
and `<picture>` references never describe the same file.

```dart
    // Attach photos the logbook referenced by absolute path, resolved
    // against the folder the user picked in the Photos step.
    final resolution = notifierState.photoResolution;
    final resolvedPhotos = resolution == null
        ? 0
        : await attachResolvedPhotos(
            media: payload.entitiesOf(ui.ImportEntityType.media),
            resolvedPathByIndex: resolution.resolvedPathByIndex,
            diveIdByIndex: result.diveIdByIndex,
            removedDiveIds: removedDiveIds,
            dives: payload.entitiesOf(ui.ImportEntityType.dives),
            attach: (file, diveId, takenAt, latitude, longitude) async {
              await _ref
                  .read(mediaImportServiceProvider)
                  .importLocalFileForDive(
                    sourceFile: file,
                    diveId: diveId,
                    takenAt: takenAt,
                    latitude: latitude,
                    longitude: longitude,
                    subdirectory: 'imported_photos',
                  );
            },
          );
```

Then fold the counts into the result the method already builds, adding to the
existing `attachedPhotoCount` and `unmatchedPhotoCount` rather than replacing
them:

```dart
      attachedPhotoCount: attachedPhotos + resolvedPhotos,
      unmatchedPhotoCount:
          notifierState.unmatchedPhotoCount + (resolution?.notFoundCount ?? 0),
```

Locate the existing `UnifiedImportResult(...)` construction in this method and
adjust those two arguments in place.

- [ ] **Step 8: Verify the whole feature analyzes and the suite passes**

Run: `flutter analyze lib test`
Expected: no issues, infos included.

Run: `flutter test`
Expected: PASS.

If a single file fails here but passes when run alone, that is a known
cross-test interference pattern in this repo, not a defect in this change.
Re-run the lone file to confirm before investigating.

- [ ] **Step 9: Commit**

```bash
dart format .
git add -A
git commit -m "feat(import): attach Subsurface-referenced photos to their dives

Registers the Photos step, shows the photos in review, and writes each
resolved file against the dive that referenced it, carrying the
picture's own offset and coordinates.

Closes #1147"
```

---

## Manual verification

After Task 7, before opening the PR, confirm the feature on a real desktop run.
Automated tests cover the units; this checks the seams they cannot.

1. Export a small logbook from Subsurface with photos attached to at least two
   dives, so `detectPrefixMove` has the two paths it needs to fire.
2. Copy the photo folder to a different location than the export references.
3. Import the `.ssrf`. Confirm the Photos step appears, that picking the copied
   folder reports the expected match counts, and that the summary reports the
   attached total.
4. Open one of the imported dives and confirm the photo is attached with a
   sensible capture time.
5. Import a Subsurface file with no `<picture>` elements and confirm the Photos
   step never appears.
