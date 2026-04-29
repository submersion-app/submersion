# MacDive Photo Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import dive photos referenced by MacDive from all three formats (native XML, SQLite, UDDF where present), and add the underlying "import photo from local path" infrastructure — which doesn't currently exist.

**Architecture:** New `ImportImageRef` payload entity (original path + dive sourceUuid + caption + position). New `PhotoResolver` service that tries direct-path → rebased-path → filename-match strategies. New optional `PhotoLinkingStep` wizard step injected *only* when the parsed payload carries image refs. Platform-gated: desktop implements full flow; mobile shows an "import from desktop" notice.

**Tech Stack:** Flutter, Dart 3, `file_picker`, `path` package, Drift, Riverpod, `flutter_test`.

**Dependencies:** Milestones 1-3 merged. Depends on `sourceUuid` on dives and on `MacDiveDbReader` / `MacDiveXmlReader` from Milestones 2-3.

**Sample data:** Real MacDive SQLite (6.7 MB) references 261 dive images via `ZDIVEIMAGE.ZPATH`. Paths are absolute to the machine where MacDive ran.

---

## File Structure

| File | Role | New / Modified |
|---|---|---|
| `lib/features/universal_import/data/models/import_image_ref.dart` | `ImportImageRef` value class. | Created |
| `lib/features/universal_import/data/models/import_payload.dart` | Add `List<ImportImageRef> imageRefs` top-level field. | Modified |
| `lib/features/universal_import/data/services/photo_resolver.dart` | Strategy-based resolver. | Created |
| `lib/features/universal_import/data/services/imported_photo_storage.dart` | Copies resolved photo bytes into app-managed media storage under the correct dive id. | Created |
| `lib/features/universal_import/data/services/macdive_db_reader.dart` | Extend to read `ZDIVEIMAGE` rows. | Modified |
| `lib/features/universal_import/data/services/macdive_xml_reader.dart` | Extend to read `<photos>` elements. | Modified |
| `lib/features/universal_import/data/services/macdive_xml_models.dart` | Add `List<MacDiveXmlPhoto>` to `MacDiveXmlDive`. | Modified |
| `lib/features/universal_import/data/services/macdive_raw_types.dart` | Add `MacDiveRawDiveImage`. | Modified |
| `lib/features/universal_import/data/services/macdive_dive_mapper.dart` | Convert photo rows to `ImportImageRef`. | Modified |
| `lib/features/universal_import/data/parsers/macdive_xml_parser.dart` | Emit `imageRefs` on payload. | Modified |
| `lib/features/universal_import/data/parsers/macdive_sqlite_parser.dart` | Emit `imageRefs` on payload. | Modified |
| `lib/features/universal_import/presentation/widgets/photo_linking_step.dart` | Wizard step UI. | Created |
| `lib/features/universal_import/presentation/providers/universal_import_state.dart` | Add photo-step state: rootDir, resolved results. | Modified |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Wire photo linking into import flow. | Modified |
| `lib/features/import_wizard/data/adapters/universal_adapter.dart` | Conditionally include PhotoLinkingStep in `acquisitionSteps`. | Modified |
| `test/features/universal_import/data/services/photo_resolver_test.dart` | Strategy tests. | Created |
| `test/features/universal_import/data/services/imported_photo_storage_test.dart` | Storage tests. | Created |
| `test/features/universal_import/presentation/widgets/photo_linking_step_test.dart` | Widget tests. | Created |
| `test/features/universal_import/data/parsers/macdive_xml_photo_test.dart` | XML photos end-to-end. | Created |
| `test/features/universal_import/data/parsers/macdive_sqlite_photo_test.dart` | SQLite photos end-to-end. | Created |

---

## Task 1: `ImportImageRef` model

**Files:**
- Create: `lib/features/universal_import/data/models/import_image_ref.dart`

- [ ] **Step 1: Define the value class**

```dart
/// A photo referenced by a dive in the source dataset. Carries the
/// original filesystem path (absolute on the machine that wrote the
/// import), the caption (if any), the dive it belongs to (by source
/// UUID), and a display position for ordering.
class ImportImageRef {
  final String originalPath;
  final String? caption;
  final String diveSourceUuid;
  final int position;
  final String? sourceUuid;  // MacDive image UUID, if present

  const ImportImageRef({
    required this.originalPath,
    required this.diveSourceUuid,
    this.caption,
    this.position = 0,
    this.sourceUuid,
  });

  /// Filename component of [originalPath]. Used for filename-fallback
  /// resolution when the original absolute path doesn't exist.
  String get filename {
    final idx = originalPath.lastIndexOf('/');
    final idx2 = originalPath.lastIndexOf(r'\');
    final split = idx > idx2 ? idx : idx2;
    return split >= 0 ? originalPath.substring(split + 1) : originalPath;
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/universal_import/data/models/import_image_ref.dart`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/features/universal_import/data/models/import_image_ref.dart
git commit -m "feat(import): add ImportImageRef model"
```

---

## Task 2: Extend `ImportPayload` with `imageRefs`

**Files:**
- Modify: `lib/features/universal_import/data/models/import_payload.dart`
- Test: `test/features/universal_import/data/models/import_payload_test.dart`

- [ ] **Step 1: Write failing test**

```dart
test('ImportPayload carries imageRefs', () {
  final payload = const ImportPayload(
    entities: {},
    warnings: [],
    imageRefs: [
      ImportImageRef(originalPath: '/photos/a.jpg', diveSourceUuid: 'dive-1'),
    ],
  );
  expect(payload.imageRefs.length, 1);
  expect(payload.imageRefs.first.filename, 'a.jpg');
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Add the field**

In `lib/features/universal_import/data/models/import_payload.dart`:

```dart
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';

class ImportPayload {
  final Map<ImportEntityType, List<Map<String, dynamic>>> entities;
  final List<ImportWarning> warnings;
  final Map<String, dynamic> metadata;
  final List<ImportImageRef> imageRefs;   // <-- NEW

  const ImportPayload({
    required this.entities,
    this.warnings = const [],
    this.metadata = const {},
    this.imageRefs = const [],
  });
  // … existing methods unchanged …
}
```

Update the `isEmpty` getter if needed to still consider imageRefs-only payloads as non-empty:
```dart
bool get isEmpty => entities.values.every((l) => l.isEmpty) && imageRefs.isEmpty;
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): ImportPayload carries imageRefs"
```

---

## Task 3: `PhotoResolver` service

**Files:**
- Create: `lib/features/universal_import/data/services/photo_resolver.dart`
- Create: `test/features/universal_import/data/services/photo_resolver_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('photo_resolver_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('direct path match returns resolved photo with bytes', () async {
    final file = File('${tmp.path}/a.jpg')..writeAsBytesSync([1, 2, 3, 4]);
    final refs = [ImportImageRef(originalPath: file.path, diveSourceUuid: 'd1')];

    final results = await PhotoResolver(rootDir: null).resolveAll(refs);
    expect(results.length, 1);
    expect(results.first.kind, PhotoResolutionKind.directPath);
    expect(results.first.bytes, [1, 2, 3, 4]);
  });

  test('rebased path finds file when prefix differs', () async {
    // Simulate original path /Users/other/Photos/a.jpg; file sits at
    // <tmp>/Photos/a.jpg so rebase root must be <tmp>.
    final subdir = Directory('${tmp.path}/Photos')..createSync();
    final file = File('${subdir.path}/a.jpg')..writeAsBytesSync([9]);
    final refs = [ImportImageRef(
      originalPath: '/Users/other/Photos/a.jpg', diveSourceUuid: 'd1')];

    final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
    expect(results.first.kind, PhotoResolutionKind.rebased);
    expect(results.first.bytes, [9]);
  });

  test('filename fallback scans root when direct + rebased both fail', () async {
    final subdir = Directory('${tmp.path}/deep/nested')..createSync(recursive: true);
    final file = File('${subdir.path}/b.jpg')..writeAsBytesSync([7]);
    final refs = [ImportImageRef(
      originalPath: '/other/machine/b.jpg', diveSourceUuid: 'd1')];

    final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
    expect(results.first.kind, PhotoResolutionKind.filenameMatch);
    expect(results.first.bytes, [7]);
  });

  test('returns miss when nothing matches', () async {
    final refs = [ImportImageRef(originalPath: '/nowhere/x.jpg', diveSourceUuid: 'd1')];
    final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
    expect(results.first.kind, PhotoResolutionKind.miss);
    expect(results.first.bytes, isNull);
  });
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';

enum PhotoResolutionKind { directPath, rebased, filenameMatch, miss }

class ResolvedPhoto {
  final ImportImageRef ref;
  final PhotoResolutionKind kind;
  final String? resolvedPath;
  final Uint8List? bytes;
  final String? errorMessage;

  const ResolvedPhoto({
    required this.ref,
    required this.kind,
    this.resolvedPath,
    this.bytes,
    this.errorMessage,
  });
}

/// Given a list of [ImportImageRef]s and an optional user-selected root
/// directory, tries direct path → rebased path → filename match, in that
/// order.
class PhotoResolver {
  final String? rootDir;
  const PhotoResolver({required this.rootDir});

  Future<List<ResolvedPhoto>> resolveAll(List<ImportImageRef> refs) async {
    final filenameIndex = rootDir == null ? null : await _indexByFilename(rootDir!);
    final results = <ResolvedPhoto>[];
    for (final ref in refs) {
      results.add(await _resolveOne(ref, filenameIndex));
    }
    return results;
  }

  Future<ResolvedPhoto> _resolveOne(
    ImportImageRef ref,
    Map<String, List<String>>? filenameIndex,
  ) async {
    // 1. Direct.
    final direct = File(ref.originalPath);
    if (await direct.exists()) {
      final bytes = await direct.readAsBytes();
      return ResolvedPhoto(
        ref: ref, kind: PhotoResolutionKind.directPath,
        resolvedPath: ref.originalPath, bytes: bytes,
      );
    }

    if (rootDir == null) {
      return ResolvedPhoto(ref: ref, kind: PhotoResolutionKind.miss);
    }

    // 2. Rebase: replace a common prefix of originalPath with rootDir.
    final rebased = _tryRebase(ref.originalPath, rootDir!);
    if (rebased != null) {
      final f = File(rebased);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        return ResolvedPhoto(
          ref: ref, kind: PhotoResolutionKind.rebased,
          resolvedPath: rebased, bytes: bytes,
        );
      }
    }

    // 3. Filename match.
    final candidates = filenameIndex?[ref.filename] ?? const [];
    if (candidates.isNotEmpty) {
      final f = File(candidates.first);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        return ResolvedPhoto(
          ref: ref, kind: PhotoResolutionKind.filenameMatch,
          resolvedPath: candidates.first, bytes: bytes,
        );
      }
    }

    return ResolvedPhoto(ref: ref, kind: PhotoResolutionKind.miss);
  }

  /// Reduce to common filename endings under [rootDir] for O(1) filename lookup.
  Future<Map<String, List<String>>> _indexByFilename(String rootDir) async {
    final index = <String, List<String>>{};
    final dir = Directory(rootDir);
    if (!await dir.exists()) return index;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final idx = entity.path.lastIndexOf(Platform.pathSeparator);
        final name = idx >= 0 ? entity.path.substring(idx + 1) : entity.path;
        index.putIfAbsent(name, () => <String>[]).add(entity.path);
      }
    }
    return index;
  }

  /// Try to rebase by finding the longest tail of [original] that exists
  /// below [root]. E.g. /Users/other/Pictures/Diving/a.jpg → find
  /// <root>/Pictures/Diving/a.jpg, then <root>/Diving/a.jpg, then <root>/a.jpg.
  String? _tryRebase(String original, String root) {
    final parts = original.split(RegExp(r'[\\/]+')).where((p) => p.isNotEmpty).toList();
    for (var start = 0; start < parts.length; start++) {
      final candidate = '${root.endsWith('/') ? root.substring(0, root.length - 1) : root}'
        '/${parts.sublist(start).join('/')}';
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): PhotoResolver with direct/rebased/filename strategies"
```

---

## Task 4: `ImportedPhotoStorage` — copy resolved photos to app media dir

**Files:**
- Create: `lib/features/universal_import/data/services/imported_photo_storage.dart`
- Create: `test/features/universal_import/data/services/imported_photo_storage_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('writes resolved photo to <appMedia>/dive/<diveId>/<position>-<filename>', () async {
  final tmp = Directory.systemTemp.createTempSync('ips_');
  addTearDown(() { if (tmp.existsSync()) tmp.deleteSync(recursive: true); });

  final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
  final stored = await storage.store(
    diveId: 'dive-uuid-1',
    ref: const ImportImageRef(
      originalPath: '/orig/a.jpg', diveSourceUuid: 'dive-uuid-1', position: 2,
    ),
    bytes: Uint8List.fromList([1, 2, 3]),
  );

  expect(stored.existsSync(), isTrue);
  expect(stored.path, endsWith('dive/dive-uuid-1/2-a.jpg'));
  expect(await stored.readAsBytes(), [1, 2, 3]);
});

test('avoids collisions by appending counter if name exists', () async {
  final tmp = Directory.systemTemp.createTempSync('ips_');
  addTearDown(() { if (tmp.existsSync()) tmp.deleteSync(recursive: true); });

  final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
  final ref1 = const ImportImageRef(originalPath: 'a.jpg', diveSourceUuid: 'd', position: 1);
  final ref2 = const ImportImageRef(originalPath: 'a.jpg', diveSourceUuid: 'd', position: 1);
  final f1 = await storage.store(diveId: 'd', ref: ref1, bytes: Uint8List.fromList([1]));
  final f2 = await storage.store(diveId: 'd', ref: ref2, bytes: Uint8List.fromList([2]));
  expect(f1.path, isNot(equals(f2.path)));
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';

class ImportedPhotoStorage {
  final String mediaRoot;
  const ImportedPhotoStorage({required this.mediaRoot});

  /// Copies [bytes] into `<mediaRoot>/dive/<diveId>/<position>-<filename>`,
  /// creating directories as needed. Appends `-N` before the extension on
  /// filename collision. Returns the written File.
  Future<File> store({
    required String diveId,
    required ImportImageRef ref,
    required Uint8List bytes,
  }) async {
    final dir = Directory('$mediaRoot/dive/$diveId');
    await dir.create(recursive: true);
    final desiredName = '${ref.position}-${ref.filename}';
    final target = await _uniqueName(dir, desiredName);
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  Future<File> _uniqueName(Directory dir, String desired) async {
    var f = File('${dir.path}/$desired');
    if (!await f.exists()) return f;
    final dot = desired.lastIndexOf('.');
    final stem = dot >= 0 ? desired.substring(0, dot) : desired;
    final ext = dot >= 0 ? desired.substring(dot) : '';
    var n = 1;
    while (true) {
      f = File('${dir.path}/$stem-$n$ext');
      if (!await f.exists()) return f;
      n++;
    }
  }
}
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): ImportedPhotoStorage copies resolved photos into app media"
```

---

## Task 5: Extend `MacDiveDbReader` to read `ZDIVEIMAGE`

**Files:**
- Modify: `lib/features/universal_import/data/services/macdive_raw_types.dart`
- Modify: `lib/features/universal_import/data/services/macdive_db_reader.dart`
- Modify: `test/features/universal_import/data/services/macdive_db_reader_test.dart`
- Modify: `test/fixtures/macdive_sqlite/build_synthetic_db.dart`

- [ ] **Step 1: Add `ZDIVEIMAGE` to the synthetic DB builder**

In `build_synthetic_db.dart`:

```dart
  db.execute('''
    CREATE TABLE ZDIVEIMAGE ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZPOSITION INTEGER, ZRELATIONSHIPDIVE INTEGER,
      ZCAPTION VARCHAR, ZORIGINALPATH VARCHAR, ZPATH VARCHAR, ZUUID VARCHAR );
  ''');
  db.execute('''INSERT INTO ZDIVEIMAGE (Z_PK, ZPOSITION, ZRELATIONSHIPDIVE, ZCAPTION, ZPATH, ZORIGINALPATH, ZUUID) VALUES
    (1, 0, 1, 'Shark!', '/Users/test/Pictures/Diving/shark.jpg', '/old/Pictures/shark.jpg', 'img-uuid-1'),
    (2, 1, 1, null, '/Users/test/Pictures/Diving/turtle.jpg', null, 'img-uuid-2'),
    (3, 0, 2, 'Reef', '/Users/test/Pictures/Diving/reef.jpg', null, 'img-uuid-3');''');
```

- [ ] **Step 2: Add the raw type**

In `macdive_raw_types.dart`:

```dart
class MacDiveRawDiveImage {
  final int pk;
  final String uuid;
  final int diveFk;
  final int position;
  final String? caption;
  final String? path;
  final String? originalPath;
  const MacDiveRawDiveImage({
    required this.pk, required this.uuid, required this.diveFk, this.position = 0,
    this.caption, this.path, this.originalPath,
  });
}
```

Add `List<MacDiveRawDiveImage> diveImages` to `MacDiveRawLogbook`.

- [ ] **Step 3: Write failing test**

```dart
test('reads ZDIVEIMAGE rows', () async {
  final f = buildSyntheticMacDiveDb('${Directory.systemTemp.path}/mdi_${DateTime.now().microsecondsSinceEpoch}.sqlite');
  final logbook = await MacDiveDbReader.readAll(Uint8List.fromList(await f.readAsBytes()));
  expect(logbook.diveImages.length, 3);
  final first = logbook.diveImages.firstWhere((i) => i.pk == 1);
  expect(first.caption, 'Shark!');
  expect(first.path, '/Users/test/Pictures/Diving/shark.jpg');
});
```

- [ ] **Step 4: Extend the reader**

Add a `_readDiveImages` helper and include in `readAll`:

```dart
static List<MacDiveRawDiveImage> _readDiveImages(Database db) {
  try {
    return db.select('SELECT * FROM ZDIVEIMAGE').map((r) => MacDiveRawDiveImage(
      pk: r['Z_PK'] as int,
      uuid: (r['ZUUID'] as String?) ?? '',
      diveFk: r['ZRELATIONSHIPDIVE'] as int? ?? 0,
      position: r['ZPOSITION'] as int? ?? 0,
      caption: _str(r['ZCAPTION']),
      path: _str(r['ZPATH']),
      originalPath: _str(r['ZORIGINALPATH']),
    )).toList();
  } catch (_) { return const []; }
}
```

And include `diveImages: _readDiveImages(db)` in the `MacDiveRawLogbook` constructor.

- [ ] **Step 5: Run — expect PASS.**

- [ ] **Step 6: Commit**

```bash
git commit -am "feat(import): MacDiveDbReader reads ZDIVEIMAGE rows"
```

---

## Task 6: Extend `MacDiveXmlReader` to read `<photos>`

**Files:**
- Modify: `lib/features/universal_import/data/services/macdive_xml_models.dart`
- Modify: `lib/features/universal_import/data/services/macdive_xml_reader.dart`
- Modify: `test/fixtures/macdive_xml/` (extend one fixture with photos)
- Modify: `test/features/universal_import/data/services/macdive_xml_reader_test.dart`

- [ ] **Step 1: Add `MacDiveXmlPhoto`**

In `macdive_xml_models.dart`:

```dart
class MacDiveXmlPhoto {
  final String path;
  final String? caption;
  final int position;
  const MacDiveXmlPhoto({required this.path, this.caption, this.position = 0});
}
```

Add to `MacDiveXmlDive`: `final List<MacDiveXmlPhoto> photos;` with `this.photos = const []`.

- [ ] **Step 2: Extend fixture**

Edit `test/fixtures/macdive_xml/metric_small.xml` — add inside the `<dive>`:

```xml
        <photos>
            <photo><path>/Users/test/Pictures/a.jpg</path><caption>Shark</caption></photo>
            <photo><path>/Users/test/Pictures/b.jpg</path></photo>
        </photos>
```

- [ ] **Step 3: Write failing test**

```dart
test('reads <photos><photo> elements with path and caption', () async {
  final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
  final dive = MacDiveXmlReader.parse(content).dives.first;
  expect(dive.photos.length, 2);
  expect(dive.photos.first.path, '/Users/test/Pictures/a.jpg');
  expect(dive.photos.first.caption, 'Shark');
});
```

- [ ] **Step 4: Run — expect FAIL.**

- [ ] **Step 5: Extend reader**

In `_parseDive`, after the other list parsers, add:

```dart
photos: _parsePhotos(el),
```

And the helper:

```dart
static List<MacDiveXmlPhoto> _parsePhotos(XmlElement dive) {
  final g = dive.findElements('photos').firstOrNull;
  if (g == null) return const [];
  var idx = 0;
  return g.findElements('photo').map((p) {
    final path = p.findElements('path').firstOrNull?.innerText.trim() ?? '';
    final caption = p.findElements('caption').firstOrNull?.innerText.trim();
    final position = idx++;
    return MacDiveXmlPhoto(
      path: path,
      caption: (caption == null || caption.isEmpty) ? null : caption,
      position: position,
    );
  }).where((p) => p.path.isNotEmpty).toList();
}
```

- [ ] **Step 6: Run — expect PASS.**

- [ ] **Step 7: Commit**

```bash
git commit -am "feat(import): MacDiveXmlReader reads <photos><photo>"
```

---

## Task 7: Parsers emit `imageRefs` on payload

**Files:**
- Modify: `lib/features/universal_import/data/services/macdive_dive_mapper.dart`
- Modify: `lib/features/universal_import/data/parsers/macdive_xml_parser.dart`
- Modify: `lib/features/universal_import/data/parsers/macdive_sqlite_parser.dart`
- Create: `test/features/universal_import/data/parsers/macdive_xml_photo_test.dart`
- Create: `test/features/universal_import/data/parsers/macdive_sqlite_photo_test.dart`

- [ ] **Step 1: Write failing tests**

`macdive_xml_photo_test.dart`:

```dart
test('MacDiveXmlParser emits imageRefs from <photos>', () async {
  final bytes = Uint8List.fromList(utf8.encode(await File('test/fixtures/macdive_xml/metric_small.xml').readAsString()));
  final payload = await MacDiveXmlParser().parse(bytes);
  expect(payload.imageRefs.length, 2);
  expect(payload.imageRefs.first.caption, 'Shark');
  expect(payload.imageRefs.first.diveSourceUuid, '20240601090000-ABC123');
});
```

`macdive_sqlite_photo_test.dart`:

```dart
test('MacDiveSqliteParser emits imageRefs from ZDIVEIMAGE', () async {
  final f = buildSyntheticMacDiveDb('${Directory.systemTemp.path}/msp_${DateTime.now().microsecondsSinceEpoch}.sqlite');
  final payload = await MacDiveSqliteParser().parse(Uint8List.fromList(await f.readAsBytes()));
  expect(payload.imageRefs.length, 3);
  final sharkRef = payload.imageRefs.firstWhere((r) => r.caption == 'Shark!');
  expect(sharkRef.diveSourceUuid, 'dive-uuid-1');
  expect(sharkRef.originalPath, '/Users/test/Pictures/Diving/shark.jpg');
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Extend `MacDiveDiveMapper`**

Before returning the payload, build imageRefs:

```dart
final imageRefs = <ImportImageRef>[];
for (final img in logbook.diveImages) {
  final dive = logbook.dives.firstWhere(
    (d) => d.pk == img.diveFk,
    orElse: () => null as dynamic, // handled below
  );
  final diveUuid = dive is MacDiveRawDive ? dive.uuid : null;
  if (diveUuid == null || diveUuid.isEmpty) continue;
  final path = img.path ?? img.originalPath;
  if (path == null || path.isEmpty) continue;
  imageRefs.add(ImportImageRef(
    originalPath: path,
    diveSourceUuid: diveUuid,
    caption: img.caption,
    position: img.position,
    sourceUuid: img.uuid.isEmpty ? null : img.uuid,
  ));
}
return ImportPayload(
  entities: entities,
  warnings: const [],
  metadata: {'source': 'macdive_sqlite', 'diveCount': logbook.dives.length},
  imageRefs: imageRefs,   // <-- NEW
);
```

(Clean up the `orElse` pattern — use a nullable lookup instead.)

- [ ] **Step 4: Extend `MacDiveXmlParser`**

In the `for (final dive in logbook.dives)` loop, also collect photos:

```dart
final imageRefs = <ImportImageRef>[];
for (final dive in logbook.dives) {
  // ... existing mapping ...
  final diveUuid = dive.identifier;
  if (diveUuid != null && dive.photos.isNotEmpty) {
    for (final p in dive.photos) {
      imageRefs.add(ImportImageRef(
        originalPath: p.path,
        diveSourceUuid: diveUuid,
        caption: p.caption,
        position: p.position,
      ));
    }
  }
}
return ImportPayload(
  entities: entities,
  warnings: warnings,
  metadata: {...},
  imageRefs: imageRefs,
);
```

- [ ] **Step 5: Run — expect PASS.**

- [ ] **Step 6: Commit**

```bash
git commit -am "feat(import): MacDive parsers emit imageRefs"
```

---

## Task 8: Wizard state additions

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_state.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`

- [ ] **Step 1: Add photo-step fields to state**

In `universal_import_state.dart`:

```dart
class UniversalImportState {
  // ... existing fields ...
  final String? photoRootDir;
  final List<ResolvedPhoto>? resolvedPhotos;
  final bool photoLinkingSkipped;

  UniversalImportState({
    // ... existing ...
    this.photoRootDir,
    this.resolvedPhotos,
    this.photoLinkingSkipped = false,
  });

  UniversalImportState copyWith({
    // ... existing ...
    String? photoRootDir,
    bool clearPhotoRootDir = false,
    List<ResolvedPhoto>? resolvedPhotos,
    bool clearResolvedPhotos = false,
    bool? photoLinkingSkipped,
  }) { /* delegate with overrides */ }
}
```

- [ ] **Step 2: Add methods to notifier**

In `universal_import_providers.dart` (`UniversalImportNotifier` class):

```dart
Future<void> setPhotoRoot(String dirPath) async {
  state = state.copyWith(photoRootDir: dirPath, isLoading: true);
  final refs = state.payload?.imageRefs ?? const <ImportImageRef>[];
  final resolver = PhotoResolver(rootDir: dirPath);
  final results = await resolver.resolveAll(refs);
  state = state.copyWith(resolvedPhotos: results, isLoading: false);
}

void skipPhotoLinking() {
  state = state.copyWith(photoLinkingSkipped: true);
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/universal_import/presentation/providers/universal_import_state.dart lib/features/universal_import/presentation/providers/universal_import_providers.dart
git commit -m "feat(import): wizard state for photo linking step"
```

---

## Task 9: `PhotoLinkingStep` widget

**Files:**
- Create: `lib/features/universal_import/presentation/widgets/photo_linking_step.dart`
- Create: `test/features/universal_import/presentation/widgets/photo_linking_step_test.dart`

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('shows photo count when payload has imageRefs', (tester) async {
  final container = ProviderContainer(overrides: [
    universalImportNotifierProvider.overrideWith((ref) {
      final n = UniversalImportNotifier(ref);
      n.state = UniversalImportState(
        payload: ImportPayload(entities: {}, imageRefs: List.filled(42, const ImportImageRef(originalPath: 'x', diveSourceUuid: 'd'))),
      );
      return n;
    }),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: PhotoLinkingStep())),
  ));
  expect(find.text('42 photo references found'), findsOneWidget);
});

testWidgets('has a "Pick folder" action', (tester) async {
  // Similar setup, then verify
  // expect(find.text('Pick folder'), findsOneWidget);
});

testWidgets('shows "Skip" and "Photos import not supported" on mobile', (tester) async {
  // Test with platform override to iOS.
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement the widget**

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

class PhotoLinkingStep extends ConsumerWidget {
  const PhotoLinkingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final refs = state.payload?.imageRefs ?? const [];
    final notifier = ref.read(universalImportNotifierProvider.notifier);
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
         defaultTargetPlatform == TargetPlatform.android);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${refs.length} photo references found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (isMobile) ...[
            const Text('Photo import is not available on this platform. '
                'Run the import from a desktop device and photos will be '
                'attached to the dives. Tap Next to continue without photos.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: notifier.skipPhotoLinking,
              child: const Text('Continue without photos'),
            ),
          ] else ...[
            if (state.photoRootDir == null) ...[
              const Text('Where are your photos stored?'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await FilePicker.pickDirectory();
                  if (picked != null) await notifier.setPhotoRoot(picked);
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('Pick folder'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: notifier.skipPhotoLinking,
                child: const Text('Skip photos'),
              ),
            ] else if (state.resolvedPhotos == null) ...[
              const CircularProgressIndicator(),
              const SizedBox(width: 8),
              const Text('Scanning…'),
            ] else ...[
              _SummaryRow(results: state.resolvedPhotos!),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final picked = await FilePicker.pickDirectory();
                      if (picked != null) await notifier.setPhotoRoot(picked);
                    },
                    child: const Text('Change folder'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: notifier.skipPhotoLinking,
                    child: const Text('Skip remaining'),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<ResolvedPhoto> results;
  const _SummaryRow({required this.results});

  @override
  Widget build(BuildContext context) {
    final found = results.where((r) => r.kind != PhotoResolutionKind.miss).length;
    return Text('$found found, ${results.length - found} missing');
  }
}

// Helper to get directory from file_picker (different platforms differ).
extension on FilePicker {
  static Future<String?> pickDirectory() async {
    return await FilePicker.platform.getDirectoryPath();
  }
}
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): PhotoLinkingStep widget"
```

---

## Task 10: Inject photo step into `UniversalAdapter.acquisitionSteps`

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart`
- Modify: `test/features/import_wizard/data/adapters/universal_adapter_test.dart`

- [ ] **Step 1: Write failing test**

```dart
test('acquisitionSteps includes PhotoLinkingStep only when payload has imageRefs', () {
  // Case A: no image refs -> steps length N.
  // Case B: with image refs -> steps length N+1, and last step builds PhotoLinkingStep.
});
```

- [ ] **Step 2: Extend `acquisitionSteps`**

The existing `acquisitionSteps` is a fixed list. Change to read-state-aware:

```dart
@override
List<WizardStepDef> get acquisitionSteps {
  final base = <WizardStepDef>[
    WizardStepDef(label: 'Select File', …),
    WizardStepDef(label: 'Confirm Source', …),
    WizardStepDef(label: 'Map Fields', …),
  ];
  final state = _ref.read(universalImportNotifierProvider);
  final hasPhotos = (state.payload?.imageRefs.isNotEmpty ?? false) &&
      !state.photoLinkingSkipped;
  if (hasPhotos) {
    base.add(WizardStepDef(
      label: 'Link Photos',
      icon: Icons.photo_library_outlined,
      builder: (context) => const PhotoLinkingStep(),
      canAdvance: _photoStepReadyProvider,
      // Skip auto-advance so user always has a chance to interact.
    ));
  }
  return base;
}
```

Where `_photoStepReadyProvider` is defined nearby:

```dart
final _photoStepReadyProvider = Provider<bool>((ref) {
  final s = ref.watch(universalImportNotifierProvider);
  return s.photoLinkingSkipped || s.resolvedPhotos != null;
});
```

(The wizard infrastructure must support this dynamic-steps pattern. If not, add a `shouldInclude` predicate to `WizardStepDef` and filter at render time — search `lib/features/import_wizard/domain/models/wizard_step_def.dart` and update its consumer in `unified_import_wizard.dart`.)

- [ ] **Step 3: Commit**

```bash
git commit -am "feat(import): conditionally inject PhotoLinkingStep when payload has photos"
```

---

## Task 11: Actually write photos during import

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` `performImport`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart` (if writing happens there)
- Test: `test/features/import_wizard/data/adapters/universal_adapter_photo_test.dart`

- [ ] **Step 1: Write failing integration test**

```dart
test('performImport copies resolved photos to app media and links them to dives', () async {
  // Build synthetic DB, parse, set a root dir with matching files, run performImport.
  // Then verify the target file exists under <appMediaRoot>/dive/<newDiveId>/0-shark.jpg.
});
```

(This requires test-only file system setup and a stubbed `appMediaRoot` — use a provider override.)

- [ ] **Step 2: Implement**

After `importer.import(…)` completes in `performImport`, if `resolvedPhotos` is non-null:

```dart
final storage = ImportedPhotoStorage(mediaRoot: await _resolveAppMediaRoot());
// Map source dive UUID -> new DB id. Requires importer to return the mapping.
final sourceUuidToDiveId = result.sourceUuidToDiveId;  // add to UddfEntityImportResult
for (final resolved in state.resolvedPhotos ?? const <ResolvedPhoto>[]) {
  if (resolved.bytes == null) continue;
  final diveId = sourceUuidToDiveId[resolved.ref.diveSourceUuid];
  if (diveId == null) continue;
  final file = await storage.store(
    diveId: diveId, ref: resolved.ref, bytes: resolved.bytes!,
  );
  await _ref.read(divePhotoRepositoryProvider).attach(
    diveId: diveId, filePath: file.path, caption: resolved.ref.caption,
    position: resolved.ref.position,
  );
}
```

Extend `UddfEntityImportResult` to carry `Map<String, String> sourceUuidToDiveId` so photo attachment can find the newly-created dive by its source UUID.

- [ ] **Step 3: Commit**

```bash
git commit -am "feat(import): write resolved photos to app media during import"
```

---

## Task 12: Real-sample photo integration test

**Files:**
- Create: `test/features/universal_import/data/parsers/macdive_sqlite_photos_real_test.dart`

- [ ] **Step 1: Write gated test**

```dart
@Tags(['real-data'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

const _path = '/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/MacDive.sqlite';

void main() {
  test('real MacDive SQLite emits 261 imageRefs', () async {
    final file = File(_path);
    if (!file.existsSync()) { markTestSkipped('No real sample'); return; }
    final bytes = Uint8List.fromList(await file.readAsBytes());
    final payload = await MacDiveSqliteParser().parse(bytes);
    expect(payload.imageRefs.length, 261);
  });
}
```

- [ ] **Step 2: Run.** Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git commit -am "test(import): MacDive SQLite real-sample photo count"
```

---

## Task 13: CHANGELOG + final sweep

- [ ] **Step 1: CHANGELOG entry**

```markdown
### Added
- Photo import from MacDive SQLite and MacDive XML exports. When the
  wizard detects photo references, it asks where to find the photos and
  copies matched files into Submersion's media storage, linking each to
  its source dive. Strategies: direct path → rebased path → filename
  fallback. Photo import is desktop-only; mobile devices will see a
  notice directing users to the desktop app.
```

- [ ] **Step 2: Final sweep**

```
dart format lib/ test/
flutter analyze
flutter test
```

- [ ] **Step 3: Commit**

```bash
git commit -am "chore: changelog for MacDive photo import"
```

---

## Self-Review Checklist

- [x] Spec requirement "direct → rebased → filename" strategies → Task 3.
- [x] Spec requirement "platform gate for mobile" → Task 9 (`isMobile` branch) and Task 11 note.
- [x] Spec requirement "caption + position preserved" → Tasks 1, 4, 5, 6.
- [x] Spec requirement "photos step conditional on payload having refs" → Task 10.
- [x] Spec requirement "UDDF photos out of scope for this milestone unless MacDive emits them" → not implemented in this plan; document in release notes.
- [x] `ImportedPhotoStorage` collision handling: Task 4 test covers it.
- [x] Test for photo linking with missing bytes — covered by `PhotoResolutionKind.miss` behavior; add explicit storage-skips-miss test if not covered.

## Notes for the executor

- `file_picker.getDirectoryPath()` on macOS requires `com.apple.security.files.user-selected.read-write` entitlement — already granted in the project's `.entitlements` files.
- Large photo folders (10k+ files) make `_indexByFilename` slow (O(n)). For this milestone, that's fine — MacDive users typically keep their dive photos in a focused folder. If it becomes a perf issue, switch to lazy filename lookup triggered per miss.
- The storage path `<mediaRoot>/dive/<diveId>/<position>-<filename>` should match whatever pattern existing dive-photo code expects. Search `dive_photo_repository` for the current convention and align.
- If `sourceUuidToDiveId` doesn't exist on `UddfEntityImportResult` yet, add it as the first step of Task 11 — it's a small change to existing importer code.
