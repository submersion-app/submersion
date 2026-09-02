# Photo and Video GPS Readers (Plan A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Populate `media.latitude/longitude` on every platform by reading GPS from JPEG/HEIC EXIF, QuickTime location metadata, and GoPro GPMF telemetry with pure Dart, so the site-suggestion feature (Plan B) has coordinates to work with on desktop.

**Architecture:** The existing pure-Dart capture-time reader is split into a shared ISO-BMFF box walker, a shared EXIF loader (JPEG + HEIC), and thin consumers. New readers (`local_gps_reader`, `quicktime_location_reader`, `gpmf_gps_reader`) sit beside them and are wired into `ExifExtractor` (after the `native_exif` block, mirroring the `takenAt ??=` fallback) and the desktop gallery picker. Every reader returns null on malformed input and never throws out of its public function.

**Tech Stack:** Dart `dart:io` `RandomAccessFile` seeks; `package:image ^4.3.0` (resolved 4.9.1) for JPEG EXIF and `ExifData.gpsIfd`; `flutter_test`; `--dart-define` gated real-sample tests.

**Spec:** `docs/superpowers/specs/2026-08-26-photo-gps-site-suggestions-design.md` (Section 2). Plan B (`2026-08-26-photo-gps-site-suggestions.md`) implements the rest of the spec and does not depend on this plan.

## Global Constraints

- Worktree: `.claude/worktrees/photo-gps-site-suggestions`, branch `worktree-photo-gps-site-suggestions`. Run every command from that directory.
- No em-dashes anywhere (code, comments, commits). No emojis in code or docs.
- Files stay under 800 lines; target 200-400.
- TDD: write the failing test, run it, implement, run again, commit.
- `dart format .` before every commit; `flutter analyze` must be clean (infos are fatal in CI).
- Timestamps stay wall-clock-UTC as today; this plan does not touch time handling.
- Coordinates are decimal degrees, latitude in [-90, 90], longitude in [-180, 180]; `(0, 0)` is treated as "no fix" everywhere, matching `MediaRepository.getGpsFromDiveMedia`'s `!= 0` guard.
- Never read a video's `mdat` wholesale. Read only the boxes and the individual samples you need, and cap every length you trust from the file.
- Run tests one file at a time as shown; do not overlap `flutter test` runs.

---

## File map

New files (all under `lib/features/media/data/services/` unless noted):

| File | Responsibility |
| --- | --- |
| `gps_fix.dart` | `GpsFix` record typedef and `isPlausibleFix` validation |
| `isobmff_boxes.dart` | ISO-BMFF/QuickTime box walking over `RandomAccessFile` and byte buffers; big-endian readers |
| `local_exif_loader.dart` | `readLocalExif(File, mime)`: JPEG and HEIC to `img.ExifData` |
| `local_gps_reader.dart` | `gpsFromExif(ExifData)` and the `readLocalGps(File, mime)` dispatcher |
| `quicktime_location_reader.dart` | `parseIso6709` and `readQuickTimeLocation(File)` (`udta > ©xyz`, `meta > keys/ilst`) |
| `gpmf_gps_reader.dart` | GoPro `gpmd` track locator, sample iterator, KLV parser, `readGpmfGps(File)` |
| `test/helpers/media_container_fixtures.dart` | Shared byte builders for MP4/HEIC/JPEG fixtures |
| `test/features/media/data/services/video_gps_real_sample_test.dart` | Gated real-sample tests |

Modified:

| File | Change |
| --- | --- |
| `capture_time_reader.dart` | Delegates JPEG/HEIC EXIF loading and box walking to the new files; keeps the `mvhd` reader |
| `exif_extractor.dart` | `lat ??=` / `lon ??=` from `readLocalGps` after the `native_exif` block |
| `photo_picker_service_desktop.dart` | `AssetInfo.latitude/longitude` from `readLocalGps` |

---

### Task 1: Shared ISO-BMFF box walker

**Files:**
- Create: `lib/features/media/data/services/isobmff_boxes.dart`
- Create: `test/helpers/media_container_fixtures.dart`
- Modify: `lib/features/media/data/services/capture_time_reader.dart` (remove the private box helpers, import the shared ones)
- Test: `test/features/media/data/services/isobmff_boxes_test.dart`

**Interfaces:**
- Produces:
  - `class BoxRange { const BoxRange(this.start, this.end); final int start; final int end; int get length; }`
  - `BoxRange? findBox(RandomAccessFile raf, int start, int end, String type)`
  - `List<BoxRange> findBoxes(RandomAccessFile raf, int start, int end, String type)`
  - `BoxRange? findBoxInBytes(Uint8List b, int start, int end, String type)`
  - `List<BoxRange> findBoxesInBytes(Uint8List b, int start, int end, String type)`
  - `int beU16(Uint8List b, int o)`, `int beU32(Uint8List b, int o)`, `int beU64(Uint8List b, int o)`, `int beS32(Uint8List b, int o)`, `int beS16(Uint8List b, int o)`
  - `String fourCC(Uint8List b, int o)`
  - `int readByteAt(RandomAccessFile raf, int position)`, `int readU32At(RandomAccessFile raf, int position)`, `int readU64At(RandomAccessFile raf, int position)`, `Uint8List readBytesAt(RandomAccessFile raf, int position, int length)`
  - Test helpers in `test/helpers/media_container_fixtures.dart`: `u16(int)`, `u32(int)`, `u64(int)`, `box(String type, List<int> payload, {bool largeSize = false})`, `fullBox(String type, List<int> payload, {int version = 0})` (prepends version + 3 zero flag bytes), `jpegWithExif(void Function(img.ExifData) configure)` returning `Uint8List`

- [ ] **Step 1: Write the shared fixture helpers**

Create `test/helpers/media_container_fixtures.dart`:

```dart
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Big-endian byte builders for hand-assembling ISO-BMFF (MP4/MOV/HEIC)
/// boxes in tests. A box is [size:uint32][type:4 ascii][payload].
List<int> u16(int v) => [(v >> 8) & 0xff, v & 0xff];

List<int> u32(int v) => [
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
];

List<int> u64(int v) => [...u32(v >> 32), ...u32(v & 0xffffffff)];

/// When [largeSize] is set the box uses the 64-bit form (size field == 1,
/// followed by an 8-byte size).
List<int> box(String type, List<int> payload, {bool largeSize = false}) {
  if (largeSize) {
    return [
      ...u32(1),
      ...type.codeUnits,
      ...u64(16 + payload.length),
      ...payload,
    ];
  }
  return [...u32(8 + payload.length), ...type.codeUnits, ...payload];
}

/// A FullBox: a box whose payload starts with 1 version byte + 3 flag bytes.
List<int> fullBox(String type, List<int> payload, {int version = 0}) =>
    box(type, [version, 0, 0, 0, ...payload]);

/// A 4x4 JPEG whose EXIF was populated by [configure] (dates, GPS, ...).
/// `encodeJpg` embeds whatever is on `image.exif`.
Uint8List jpegWithExif(void Function(img.ExifData exif) configure) {
  final image = img.Image(width: 4, height: 4);
  configure(image.exif);
  return img.encodeJpg(image);
}
```

- [ ] **Step 2: Write the failing box-walker test**

Create `test/features/media/data/services/isobmff_boxes_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

import '../../../../helpers/media_container_fixtures.dart';

void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isobmff_');
  });
  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  File write(String name, List<int> bytes) =>
      File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

  group('findBox over a file', () {
    test('returns the payload range of the first matching sibling', () {
      final f = write('a.mp4', [
        ...box('ftyp', 'isom'.codeUnits),
        ...box('moov', [1, 2, 3]),
      ]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      final moov = findBox(raf, 0, raf.lengthSync(), 'moov');
      expect(moov, isNotNull);
      expect(moov!.start, 12 + 8);
      expect(moov.end, 12 + 8 + 3);
      expect(moov.length, 3);
    });

    test('handles the 64-bit size form', () {
      final f = write('b.mp4', [
        ...box('mdat', [0, 0], largeSize: true),
        ...box('moov', [9]),
      ]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      final moov = findBox(raf, 0, raf.lengthSync(), 'moov');
      expect(moov, isNotNull);
      expect(readByteAt(raf, moov!.start), 9);
    });

    test('returns null for a missing type or a corrupt size', () {
      final f = write('c.mp4', [...u32(3), ...'moov'.codeUnits]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      expect(findBox(raf, 0, raf.lengthSync(), 'moov'), isNull);
      expect(findBox(raf, 0, raf.lengthSync(), 'trak'), isNull);
    });

    test('findBoxes returns every sibling of the type in order', () {
      final f = write('d.mp4', [
        ...box('trak', [1]),
        ...box('udta', [0]),
        ...box('trak', [2]),
      ]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      final traks = findBoxes(raf, 0, raf.lengthSync(), 'trak');
      expect(traks.map((r) => readByteAt(raf, r.start)), [1, 2]);
    });
  });

  group('byte-buffer twins', () {
    test('findBoxInBytes and findBoxesInBytes mirror the file walkers', () {
      final bytes = Uint8List.fromList([
        ...box('keys', [1]),
        ...box('ilst', [2]),
        ...box('ilst', [3]),
      ]);
      final one = findBoxInBytes(bytes, 0, bytes.length, 'ilst');
      expect(one, isNotNull);
      expect(bytes[one!.start], 2);
      final all = findBoxesInBytes(bytes, 0, bytes.length, 'ilst');
      expect(all.map((r) => bytes[r.start]), [2, 3]);
    });

    test('big-endian readers', () {
      final b = Uint8List.fromList([
        0xff, 0xfe, // beU16 = 65534, beS16 = -2
        0xff, 0xff, 0xff, 0xfe, // beU32 = 4294967294, beS32 = -2
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, // beU64 = 1 << 32
        0x67, 0x70, 0x6d, 0x64, // 'gpmd'
      ]);
      expect(beU16(b, 0), 65534);
      expect(beS16(b, 0), -2);
      expect(beU32(b, 2), 4294967294);
      expect(beS32(b, 2), -2);
      expect(beU64(b, 6), 1 << 32);
      expect(fourCC(b, 14), 'gpmd');
    });

    test('readBytesAt reads exactly the requested window', () {
      final f = write('e.bin', [10, 11, 12, 13, 14]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      expect(readBytesAt(raf, 1, 3), [11, 12, 13]);
      expect(readU32At(raf, 1), (11 << 24) | (12 << 16) | (13 << 8) | 14);
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/features/media/data/services/isobmff_boxes_test.dart`
Expected: FAIL, "Target of URI doesn't exist" for `isobmff_boxes.dart`.

- [ ] **Step 4: Create `isobmff_boxes.dart`**

Move the box helpers out of `capture_time_reader.dart` and make them public:

```dart
import 'dart:io';
import 'dart:typed_data';

/// ISO-BMFF / QuickTime box walking shared by the capture-time, EXIF, and
/// GPS readers. A box is [size:uint32][type:4 ascii][payload]; size == 1
/// means a 64-bit size follows the type; size == 0 means "to end of range".
///
/// The file walkers seek, so a multi-GB clip whose `moov` sits after `mdat`
/// is walked without ever reading the media payload.

/// Half-open byte range [start, end) of a box's content (payload).
class BoxRange {
  const BoxRange(this.start, this.end);
  final int start;
  final int end;
  int get length => end - start;
}

/// Returns the content range of the first sibling box of [type] within
/// [start, end), or null.
BoxRange? findBox(RandomAccessFile raf, int start, int end, String type) {
  for (final r in _walk(raf, start, end)) {
    if (r.type == type) return r.range;
  }
  return null;
}

/// Every sibling box of [type] within [start, end), in file order.
List<BoxRange> findBoxes(
  RandomAccessFile raf,
  int start,
  int end,
  String type,
) => [
  for (final r in _walk(raf, start, end))
    if (r.type == type) r.range,
];

/// Byte-buffer twin of [findBox], for sub-boxes already read into memory.
BoxRange? findBoxInBytes(Uint8List b, int start, int end, String type) {
  for (final r in _walkBytes(b, start, end)) {
    if (r.type == type) return r.range;
  }
  return null;
}

/// Byte-buffer twin of [findBoxes].
List<BoxRange> findBoxesInBytes(
  Uint8List b,
  int start,
  int end,
  String type,
) => [
  for (final r in _walkBytes(b, start, end))
    if (r.type == type) r.range,
];

typedef _Header = ({String type, BoxRange range});

/// Lazily yields sibling boxes; stops at the first corrupt header so a bad
/// size never walks past [end] or spins.
Iterable<_Header> _walk(RandomAccessFile raf, int start, int end) sync* {
  var pos = start;
  while (pos + 8 <= end) {
    raf.setPositionSync(pos);
    final header = raf.readSync(8);
    if (header.length < 8) return;
    var size = beU32(header, 0);
    var headerLen = 8;
    if (size == 1) {
      final ext = raf.readSync(8);
      if (ext.length < 8) return;
      size = beU64(ext, 0);
      headerLen = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < headerLen || pos + size > end) return;
    yield (
      type: String.fromCharCodes(header, 4, 8),
      range: BoxRange(pos + headerLen, pos + size),
    );
    pos += size;
  }
}

Iterable<_Header> _walkBytes(Uint8List b, int start, int end) sync* {
  var pos = start;
  while (pos + 8 <= end) {
    var size = beU32(b, pos);
    var headerLen = 8;
    if (size == 1) {
      if (pos + 16 > end) return;
      size = beU64(b, pos + 8);
      headerLen = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < headerLen || pos + size > end) return;
    yield (type: fourCC(b, pos + 4), range: BoxRange(pos + headerLen, pos + size));
    pos += size;
  }
}

int beU16(Uint8List b, int o) => (b[o] << 8) | b[o + 1];

int beS16(Uint8List b, int o) => beU16(b, o).toSigned(16);

int beU32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

int beS32(Uint8List b, int o) => beU32(b, o).toSigned(32);

int beU64(Uint8List b, int o) => (beU32(b, o) << 32) | beU32(b, o + 4);

String fourCC(Uint8List b, int o) => String.fromCharCodes(b, o, o + 4);

int readByteAt(RandomAccessFile raf, int position) {
  raf.setPositionSync(position);
  return raf.readSync(1).first;
}

int readU32At(RandomAccessFile raf, int position) {
  raf.setPositionSync(position);
  return beU32(raf.readSync(4), 0);
}

int readU64At(RandomAccessFile raf, int position) {
  raf.setPositionSync(position);
  return beU64(raf.readSync(8), 0);
}

Uint8List readBytesAt(RandomAccessFile raf, int position, int length) {
  raf.setPositionSync(position);
  return raf.readSync(length);
}
```

- [ ] **Step 5: Point `capture_time_reader.dart` at the shared walker**

In `capture_time_reader.dart`:
- Add `import 'package:submersion/features/media/data/services/isobmff_boxes.dart';`.
- Delete `class _BoxRange`, `_findBox`, `_findBoxInBytes`, `extension _ReadAt`, `_readU32`, `_readU64`, `_beU16`, `_beU32`, `_beU64`, `_fourCC`.
- Replace every `_BoxRange` with `BoxRange`, `_findBox(` with `findBox(`, `_findBoxInBytes(` with `findBoxInBytes(`, `_beU16(` with `beU16(`, `_beU32(` with `beU32(`, `_beU64(` with `beU64(`, `_fourCC(` with `fourCC(`.
- In `_readMp4CreationTime`: `raf.readByteAt(mvhd.start)` becomes `readByteAt(raf, mvhd.start)`; `_readU64(raf, mvhd.start + 4)` becomes `readU64At(raf, mvhd.start + 4)`; `_readU32(...)` becomes `readU32At(...)`.

- [ ] **Step 6: Run both test files**

Run: `flutter test test/features/media/data/services/isobmff_boxes_test.dart`
Expected: PASS.
Run: `flutter test test/features/media/data/services/capture_time_reader_test.dart`
Expected: PASS (behaviour unchanged).

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/features/media/data/services test/features/media/data/services test/helpers
flutter analyze lib/features/media/data/services test/features/media/data/services test/helpers
git add lib/features/media/data/services/isobmff_boxes.dart lib/features/media/data/services/capture_time_reader.dart test/features/media/data/services/isobmff_boxes_test.dart test/helpers/media_container_fixtures.dart
git commit -m "refactor(media): share the ISO-BMFF box walker between readers"
```

---

### Task 2: Shared EXIF loader (JPEG and HEIC)

**Files:**
- Create: `lib/features/media/data/services/local_exif_loader.dart`
- Modify: `lib/features/media/data/services/capture_time_reader.dart`
- Test: `test/features/media/data/services/local_exif_loader_test.dart`

**Interfaces:**
- Consumes: `findBox`, `findBoxInBytes`, `beU16`, `beU32`, `fourCC` from Task 1.
- Produces: `img.ExifData? readLocalExif(File file, String mime)` for `image/jpeg`, `image/heic`, `image/heif`; null for other mimes, unreadable files, or files without EXIF.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/local_exif_loader_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/local_exif_loader.dart';

import '../../../../helpers/media_container_fixtures.dart';

/// A real TIFF/EXIF block lifted from an encoded JPEG's APP1 segment,
/// prefixed by the 4-byte tiff-header offset a HEIC `Exif` item carries.
List<int> exifItemPayload(void Function(img.ExifData) configure) {
  final jpg = jpegWithExif(configure);
  for (var i = 0; i + 3 < jpg.length; i++) {
    if (jpg[i] == 0xFF && jpg[i + 1] == 0xE1) {
      final segLen = (jpg[i + 2] << 8) | jpg[i + 3];
      return [...u32(6), ...jpg.sublist(i + 4, i + 2 + segLen)];
    }
  }
  throw StateError('no APP1 EXIF segment in encoded JPEG');
}

/// Minimal HEIC: ftyp, mdat holding the Exif payload, then meta whose iinf
/// declares an 'Exif' item and iloc points at the payload's absolute offset.
List<int> heicFile(void Function(img.ExifData) configure) {
  final ftyp = box('ftyp', 'heic'.codeUnits);
  final payload = exifItemPayload(configure);
  final mdat = box('mdat', payload);
  final payloadOffset = ftyp.length + 8;
  final infe = box('infe', [
    2, 0, 0, 0,
    ...u16(1), // item_ID
    ...u16(0), // protection_index
    ...'Exif'.codeUnits,
    0,
  ]);
  final iinf = box('iinf', [0, 0, 0, 0, ...u16(1), ...infe]);
  final iloc = box('iloc', [
    1, 0, 0, 0, // version 1 + flags
    0x44, // offset_size=4, length_size=4
    0x00, // base_offset_size=0, index_size=0
    ...u16(1), ...u16(1), // item_count, item_ID
    ...u16(0), // construction_method
    ...u16(0), // data_reference_index
    ...u16(1), // extent_count
    ...u32(payloadOffset),
    ...u32(payload.length),
  ]);
  final meta = box('meta', [0, 0, 0, 0, ...iinf, ...iloc]);
  return [...ftyp, ...mdat, ...meta];
}

void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exif_loader_');
  });
  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });
  File write(String name, List<int> bytes) =>
      File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

  test('JPEG: returns the parsed EXIF block', () {
    final f = write(
      'a.jpg',
      jpegWithExif((e) => e.exifIfd['DateTimeOriginal'] = '2025:12:27 12:08:19'),
    );
    final exif = readLocalExif(f, 'image/jpeg');
    expect(exif?.exifIfd['DateTimeOriginal'].toString(), '2025:12:27 12:08:19');
  });

  test('HEIC: returns the EXIF block from the meta Exif item', () {
    final f = write(
      'a.heic',
      heicFile((e) {
        e.exifIfd['DateTimeOriginal'] = '2026:05:06 17:35:39';
        e.gpsIfd.gpsLatitude = 12.5;
        e.gpsIfd.gpsLatitudeRef = 'N';
      }),
    );
    final exif = readLocalExif(f, 'image/heic');
    expect(exif?.exifIfd['DateTimeOriginal'].toString(), '2026:05:06 17:35:39');
    expect(exif?.gpsIfd.gpsLatitude, closeTo(12.5, 1e-6));
  });

  test('returns null for other mimes, corrupt bytes, and missing files', () {
    final f = write('bad.jpg', [1, 2, 3]);
    expect(readLocalExif(f, 'image/jpeg'), isNull);
    expect(readLocalExif(f, 'video/mp4'), isNull);
    expect(readLocalExif(File('${tempDir.path}/none.jpg'), 'image/jpeg'), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/services/local_exif_loader_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Create `local_exif_loader.dart`**

Move the HEIC item/extent/TIFF helpers out of `capture_time_reader.dart` into this file, verbatim, and wrap them:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

/// Loads the EXIF block of a JPEG or HEIC/HEIF file with pure Dart, for the
/// platforms where `native_exif` has no implementation. One parse serves
/// every consumer (capture time, GPS); callers never decode pixels.
///
/// Returns null for unsupported mimes, unreadable or corrupt files, and files
/// that simply carry no EXIF.
img.ExifData? readLocalExif(File file, String mime) {
  try {
    switch (mime) {
      case 'image/jpeg':
        return img.decodeJpgExif(file.readAsBytesSync());
      case 'image/heic':
      case 'image/heif':
        return _readHeicExif(file);
      default:
        return null;
    }
  } on Object {
    return null;
  }
}

// Upper bounds on HEIC reads. Real `meta` boxes and `Exif` items are tens of
// KB; these caps reject a corrupt/crafted length before it allocates.
const _maxMetaBytes = 64 * 1024 * 1024;
const _maxExifItemBytes = 64 * 1024 * 1024;

img.ExifData? _readHeicExif(File file) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final end = raf.lengthSync();
    final meta = findBox(raf, 0, end, 'meta');
    if (meta == null) return null;
    final metaLen = meta.end - meta.start - 4;
    if (metaLen <= 0 || metaLen > _maxMetaBytes) return null;
    final metaBytes = readBytesAt(raf, meta.start + 4, metaLen);

    final iinf = findBoxInBytes(metaBytes, 0, metaBytes.length, 'iinf');
    final iloc = findBoxInBytes(metaBytes, 0, metaBytes.length, 'iloc');
    if (iinf == null || iloc == null) return null;

    final itemId = _heicExifItemId(metaBytes, iinf.start, iinf.end);
    if (itemId == null) return null;
    final extent = _heicExifExtent(metaBytes, iloc.start, iloc.end, itemId);
    if (extent == null) return null;
    if (extent.offset < 0 ||
        extent.length <= 0 ||
        extent.length > _maxExifItemBytes ||
        extent.offset + extent.length > end) {
      return null;
    }

    final item = readBytesAt(raf, extent.offset, extent.length);
    final tiff = _tiffHeaderOffset(item);
    if (tiff == null) return null;
    return img.ExifData.fromInputBuffer(img.InputBuffer(item.sublist(tiff)));
  } on Object {
    return null;
  } finally {
    raf?.closeSync();
  }
}

// _heicExifItemId, _heicExifExtent, _Extent, _tiffHeaderOffset, _isTiffHeader:
// moved verbatim from capture_time_reader.dart, with _beU16/_beU32/_fourCC
// renamed to the shared beU16/beU32/fourCC.
```

(Paste the five moved helpers below the comment; their bodies are unchanged apart from the renamed byte readers.)

- [ ] **Step 4: Slim `capture_time_reader.dart` to use the loader**

Replace `_readJpegExifDate` and `_readHeicExifDate` (and the helpers you moved) with:

```dart
DateTime? readLocalCaptureTime(File file, String mime) {
  switch (mime) {
    case 'image/jpeg':
    case 'image/heic':
    case 'image/heif':
      final exif = readLocalExif(file, mime);
      return exif == null ? null : _dateFromExif(exif);
    case 'video/mp4':
    case 'video/quicktime':
    case 'video/x-m4v':
      return _readMp4CreationTime(file);
    default:
      return null;
  }
}
```

Keep `_dateFromExif` and `_readMp4CreationTime`; add the `local_exif_loader.dart` import; remove the now-unused `dart:typed_data` import if nothing else needs it. The file should shrink to roughly 90 lines.

- [ ] **Step 5: Run the three affected test files**

Run: `flutter test test/features/media/data/services/local_exif_loader_test.dart`
Expected: PASS.
Run: `flutter test test/features/media/data/services/capture_time_reader_test.dart`
Expected: PASS (HEIC and JPEG date tests unchanged).
Run: `flutter test test/features/media/data/services/exif_extractor_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/media/data/services test/features/media/data/services
flutter analyze lib/features/media/data/services test/features/media/data/services
git add lib/features/media/data/services/local_exif_loader.dart lib/features/media/data/services/capture_time_reader.dart test/features/media/data/services/local_exif_loader_test.dart
git commit -m "refactor(media): load JPEG and HEIC EXIF once through a shared loader"
```

---

### Task 3: GPS fix type and EXIF GPS reader

**Files:**
- Create: `lib/features/media/data/services/gps_fix.dart`
- Create: `lib/features/media/data/services/local_gps_reader.dart`
- Test: `test/features/media/data/services/local_gps_reader_test.dart`

**Interfaces:**
- Consumes: `readLocalExif` (Task 2).
- Produces:
  - `typedef GpsFix = ({double latitude, double longitude});`
  - `bool isPlausibleFix(double latitude, double longitude)`: finite, in range, not `(0, 0)`.
  - `GpsFix? gpsFromExif(img.ExifData exif)`
  - `GpsFix? readLocalGps(File file, String mime)`: images only in this task; Task 5 adds the video branch.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/local_gps_reader_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/local_gps_reader.dart';

import '../../../../helpers/media_container_fixtures.dart';

void main() {
  group('isPlausibleFix', () {
    test('accepts in-range coordinates', () {
      expect(isPlausibleFix(12.34, -98.76), isTrue);
      expect(isPlausibleFix(-90, 180), isTrue);
    });
    test('rejects (0,0), NaN, and out-of-range values', () {
      expect(isPlausibleFix(0, 0), isFalse);
      expect(isPlausibleFix(double.nan, 10), isFalse);
      expect(isPlausibleFix(91, 10), isFalse);
      expect(isPlausibleFix(10, -181), isFalse);
      expect(isPlausibleFix(double.infinity, 0), isFalse);
    });
  });

  group('gpsFromExif', () {
    img.ExifData exifWith({
      double? lat,
      String? latRef,
      double? lon,
      String? lonRef,
    }) {
      final e = img.ExifData();
      if (lat != null) e.gpsIfd.gpsLatitude = lat;
      if (latRef != null) e.gpsIfd.gpsLatitudeRef = latRef;
      if (lon != null) e.gpsIfd.gpsLongitude = lon;
      if (lonRef != null) e.gpsIfd.gpsLongitudeRef = lonRef;
      return e;
    }

    test('north-east stays positive', () {
      final fix = gpsFromExif(
        exifWith(lat: 12.3456, latRef: 'N', lon: 98.7654, lonRef: 'E'),
      );
      expect(fix?.latitude, closeTo(12.3456, 1e-6));
      expect(fix?.longitude, closeTo(98.7654, 1e-6));
    });

    test('south and west negate', () {
      final fix = gpsFromExif(
        exifWith(lat: 33.8688, latRef: 'S', lon: 151.2093, lonRef: 'W'),
      );
      expect(fix?.latitude, closeTo(-33.8688, 1e-6));
      expect(fix?.longitude, closeTo(-151.2093, 1e-6));
    });

    test('a missing ref is treated as N / E', () {
      final fix = gpsFromExif(exifWith(lat: 1.5, lon: 2.5));
      expect(fix, (latitude: 1.5, longitude: 2.5));
    });

    test('a missing axis or an empty GPS IFD yields null', () {
      expect(gpsFromExif(exifWith(lat: 1.5, latRef: 'N')), isNull);
      expect(gpsFromExif(img.ExifData()), isNull);
    });

    test('(0,0) and out-of-range values yield null', () {
      expect(gpsFromExif(exifWith(lat: 0, lon: 0)), isNull);
      expect(gpsFromExif(exifWith(lat: 95, lon: 10)), isNull);
    });

    test('reads degree/minute/second rationals as the EXIF spec stores them', () {
      // 12 deg 20 min 44.16 sec = 12.3456; the typed setter writes exactly
      // this triple, so the reader must sum d + m/60 + s/3600.
      final e = img.ExifData();
      e.gpsIfd[0x0002] = img.IfdValueRational.list([
        img.Rational(12, 1),
        img.Rational(20, 1),
        img.Rational(4416, 100),
      ]);
      e.gpsIfd[0x0001] = img.IfdValueAscii('N');
      e.gpsIfd[0x0004] = img.IfdValueRational.list([
        img.Rational(98, 1),
        img.Rational(45, 1),
        img.Rational(5544, 100),
      ]);
      e.gpsIfd[0x0003] = img.IfdValueAscii('W');
      final fix = gpsFromExif(e);
      expect(fix?.latitude, closeTo(12.3456, 1e-6));
      expect(fix?.longitude, closeTo(-98.7654, 1e-6));
    });
  });

  group('readLocalGps for images', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('local_gps_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('JPEG with GPS', () {
      final f = File('${tempDir.path}/a.jpg')
        ..writeAsBytesSync(
          jpegWithExif((e) {
            e.gpsIfd.gpsLatitude = 20.5;
            e.gpsIfd.gpsLatitudeRef = 'N';
            e.gpsIfd.gpsLongitude = 87.25;
            e.gpsIfd.gpsLongitudeRef = 'W';
          }),
        );
      final fix = readLocalGps(f, 'image/jpeg');
      expect(fix?.latitude, closeTo(20.5, 1e-6));
      expect(fix?.longitude, closeTo(-87.25, 1e-6));
    });

    test('JPEG without GPS, PNG, and a missing file yield null', () {
      final noGps = File('${tempDir.path}/b.jpg')
        ..writeAsBytesSync(
          jpegWithExif((e) => e.exifIfd['DateTimeOriginal'] = '2025:01:01 00:00:00'),
        );
      expect(readLocalGps(noGps, 'image/jpeg'), isNull);
      expect(readLocalGps(noGps, 'image/png'), isNull);
      expect(readLocalGps(File('${tempDir.path}/none.jpg'), 'image/jpeg'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/services/local_gps_reader_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Create `gps_fix.dart`**

```dart
/// A decimal-degree position read from a media file's own metadata.
typedef GpsFix = ({double latitude, double longitude});

/// True when the pair is a usable position: finite, inside the valid
/// ranges, and not the `(0, 0)` that cameras and phones write when the
/// receiver had no fix. Matches the `!= 0` guard the media repository
/// applies when it reads coordinates back.
bool isPlausibleFix(double latitude, double longitude) {
  if (!latitude.isFinite || !longitude.isFinite) return false;
  if (latitude < -90 || latitude > 90) return false;
  if (longitude < -180 || longitude > 180) return false;
  if (latitude == 0 && longitude == 0) return false;
  return true;
}
```

- [ ] **Step 4: Create `local_gps_reader.dart`**

```dart
import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/local_exif_loader.dart';

/// Reads a position from a media file's own metadata with pure Dart, for the
/// platforms and files where `native_exif` yields nothing. Returns null when
/// the file carries no plausible fix.
GpsFix? readLocalGps(File file, String mime) {
  try {
    switch (mime) {
      case 'image/jpeg':
      case 'image/heic':
      case 'image/heif':
        final exif = readLocalExif(file, mime);
        return exif == null ? null : gpsFromExif(exif);
      default:
        return null;
    }
  } on Object {
    return null;
  }
}

/// EXIF stores each axis as three unsigned rationals (degrees, minutes,
/// seconds) in the GPS IFD, with the hemisphere in a separate ASCII tag.
/// A reader that ignores the ref tag puts every western-hemisphere dive in
/// the wrong ocean, so both are required here.
GpsFix? gpsFromExif(img.ExifData exif) {
  final gps = exif.gpsIfd;
  final lat = _degrees(gps[0x0002]);
  final lon = _degrees(gps[0x0004]);
  if (lat == null || lon == null) return null;
  final latRef = gps[0x0001]?.toString().trim().toUpperCase();
  final lonRef = gps[0x0003]?.toString().trim().toUpperCase();
  final signedLat = latRef == 'S' ? -lat : lat;
  final signedLon = lonRef == 'W' ? -lon : lon;
  if (!isPlausibleFix(signedLat, signedLon)) return null;
  return (latitude: signedLat, longitude: signedLon);
}

/// Sums a (deg, min, sec) rational triple; tolerates a single decimal-degree
/// rational, which some writers emit instead of the triple.
double? _degrees(img.IfdValue? value) {
  if (value == null) return null;
  if (value is! img.IfdValueRational) return null;
  final parts = value.value;
  if (parts.isEmpty) return null;
  double part(int i) {
    if (i >= parts.length) return 0;
    final r = parts[i];
    if (r.denominator == 0) return double.nan;
    return r.numerator / r.denominator;
  }
  final degrees = part(0) + part(1) / 60 + part(2) / 3600;
  return degrees.isFinite ? degrees : null;
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/media/data/services/local_gps_reader_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/media/data/services test/features/media/data/services
flutter analyze lib/features/media/data/services test/features/media/data/services
git add lib/features/media/data/services/gps_fix.dart lib/features/media/data/services/local_gps_reader.dart test/features/media/data/services/local_gps_reader_test.dart
git commit -m "feat(media): read EXIF GPS from JPEG and HEIC with pure Dart"
```

---

### Task 4: QuickTime location reader (ISO 6709)

**Files:**
- Create: `lib/features/media/data/services/quicktime_location_reader.dart`
- Test: `test/features/media/data/services/quicktime_location_reader_test.dart`

**Interfaces:**
- Consumes: `findBox`, `findBoxInBytes`, `beU16`, `beU32`, `readBytesAt`, `fourCC` (Task 1); `GpsFix`, `isPlausibleFix` (Task 3).
- Produces:
  - `GpsFix? parseIso6709(String value)`: decimal-degree form `+DD.DDDD+DDD.DDDD[+alt]/`.
  - `GpsFix? readQuickTimeLocation(File file)`: `moov > udta > ©xyz` first, then `moov > meta > keys/ilst` `com.apple.quicktime.location.ISO6709`.

Format notes for the implementer:
- `©xyz` (bytes `A9 78 79 7A`) in `udta` is an international-text atom: `uint16 textLength`, `uint16 languageCode`, then `textLength` bytes of text.
- QuickTime's `moov > meta` is NOT a FullBox in Apple files (its first child `hdlr` starts at offset 0) but IS a FullBox in ISO files (children start at offset 4). Detect: if `fourCC(meta, 4) == 'hdlr'` the children start at 0, otherwise at 4.
- `keys` is a FullBox: `uint32 entryCount`, then entries `{uint32 size, 'mdta', bytes name}`; the key index is 1-based.
- `ilst` children are boxes whose 4-byte "type" is the big-endian key index; each holds a `data` box: `uint32 typeIndicator` (1 = UTF-8), `uint32 locale`, then the value bytes.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/quicktime_location_reader_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/quicktime_location_reader.dart';

import '../../../../helpers/media_container_fixtures.dart';

const _iso = '+37.3323-122.0312+023.456/';

/// `©xyz` international-text atom inside udta.
List<int> _xyz(String text) => box('©xyz', [
  ...u16(text.length),
  ...u16(0x15c7), // language: English
  ...ascii.encode(text),
]);

/// Apple-style moov > meta (no version/flags) with keys + ilst.
List<int> _appleMeta(String text, {bool fullBox = false}) {
  final hdlr = fullBox
      ? fullBox_('hdlr')
      : box('hdlr', [0, 0, 0, 0, 0, 0, 0, 0, ...'mdta'.codeUnits, ...List.filled(12, 0)]);
  final keyName = ascii.encode('com.apple.quicktime.location.ISO6709');
  final keys = fullBox_('keys', [
    ...u32(1),
    ...u32(8 + keyName.length),
    ...'mdta'.codeUnits,
    ...keyName,
  ]);
  final data = box('data', [...u32(1), ...u32(0), ...ascii.encode(text)]);
  final entry = [...u32(8 + data.length), ...u32(1), ...data];
  final ilst = box('ilst', entry);
  final payload = [...hdlr, ...keys, ...ilst];
  return box('meta', fullBox ? [0, 0, 0, 0, ...payload] : payload);
}

List<int> fullBox_(String type, [List<int> payload = const []]) =>
    box(type, [0, 0, 0, 0, ...payload]);

void main() {
  group('parseIso6709', () {
    test('parses the Apple decimal-degree form with altitude', () {
      final fix = parseIso6709(_iso);
      expect(fix?.latitude, closeTo(37.3323, 1e-6));
      expect(fix?.longitude, closeTo(-122.0312, 1e-6));
    });
    test('parses without altitude or trailing slash', () {
      expect(parseIso6709('-33.8688+151.2093'), (latitude: -33.8688, longitude: 151.2093));
    });
    test('rejects garbage, (0,0), and out-of-range', () {
      expect(parseIso6709('hello'), isNull);
      expect(parseIso6709('+00.0000+000.0000/'), isNull);
      expect(parseIso6709('+95.0000+010.0000/'), isNull);
      expect(parseIso6709(''), isNull);
    });
  });

  group('readQuickTimeLocation', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qt_loc_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    File write(String name, List<int> bytes) =>
        File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

    test('reads udta > xyz with moov after mdat', () {
      final f = write('a.mov', [
        ...box('ftyp', 'qt  '.codeUnits),
        ...box('mdat', List.filled(64, 0)),
        ...box('moov', [...box('mvhd', List.filled(100, 0)), ...box('udta', _xyz(_iso))]),
      ]);
      final fix = readQuickTimeLocation(f);
      expect(fix?.latitude, closeTo(37.3323, 1e-6));
      expect(fix?.longitude, closeTo(-122.0312, 1e-6));
    });

    test('reads meta > keys/ilst in the Apple (non-FullBox) layout', () {
      final f = write('b.mov', [
        ...box('ftyp', 'qt  '.codeUnits),
        ...box('moov', _appleMeta(_iso)),
      ]);
      expect(readQuickTimeLocation(f)?.longitude, closeTo(-122.0312, 1e-6));
    });

    test('reads meta > keys/ilst in the ISO (FullBox) layout', () {
      final f = write('c.mp4', [
        ...box('ftyp', 'isom'.codeUnits),
        ...box('moov', _appleMeta(_iso, fullBox: true)),
      ]);
      expect(readQuickTimeLocation(f)?.latitude, closeTo(37.3323, 1e-6));
    });

    test('returns null when neither atom is present or the text is bad', () {
      final none = write('d.mp4', [...box('ftyp', 'isom'.codeUnits), ...box('moov', box('mvhd', []))]);
      expect(readQuickTimeLocation(none), isNull);
      final bad = write('e.mov', [...box('moov', box('udta', _xyz('not a location')))]);
      expect(readQuickTimeLocation(bad), isNull);
      expect(readQuickTimeLocation(File('${tempDir.path}/none.mov')), isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/services/quicktime_location_reader_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Create `quicktime_location_reader.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

/// Reads the recording location iPhones and most cameras write into a
/// QuickTime/MP4 container: the classic `moov > udta > ©xyz` atom, then the
/// newer `moov > meta > keys/ilst` entry
/// `com.apple.quicktime.location.ISO6709`. Both hold an ISO 6709 string.
GpsFix? readQuickTimeLocation(File file) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final end = raf.lengthSync();
    final moov = findBox(raf, 0, end, 'moov');
    if (moov == null) return null;
    return _fromUdta(raf, moov) ?? _fromMeta(raf, moov);
  } on Object {
    return null;
  } finally {
    raf?.closeSync();
  }
}

const _maxTextBytes = 4096;
const _maxMetaBytes = 1024 * 1024;
const _locationKey = 'com.apple.quicktime.location.ISO6709';

GpsFix? _fromUdta(RandomAccessFile raf, BoxRange moov) {
  final udta = findBox(raf, moov.start, moov.end, 'udta');
  if (udta == null) return null;
  final xyz = findBox(raf, udta.start, udta.end, '©xyz');
  if (xyz == null || xyz.length < 4) return null;
  final header = readBytesAt(raf, xyz.start, 4);
  final textLen = beU16(header, 0);
  if (textLen <= 0 || textLen > _maxTextBytes || 4 + textLen > xyz.length) {
    return null;
  }
  final text = readBytesAt(raf, xyz.start + 4, textLen);
  return parseIso6709(latin1.decode(text, allowInvalid: true));
}

GpsFix? _fromMeta(RandomAccessFile raf, BoxRange moov) {
  final meta = findBox(raf, moov.start, moov.end, 'meta');
  if (meta == null || meta.length > _maxMetaBytes || meta.length < 8) {
    return null;
  }
  final b = readBytesAt(raf, meta.start, meta.length);
  // Apple writes meta as a plain box (hdlr at offset 0); ISO files make it a
  // FullBox (4 bytes of version/flags first). Detect rather than assume.
  final childStart = fourCC(b, 4) == 'hdlr' ? 0 : 4;
  final keys = findBoxInBytes(b, childStart, b.length, 'keys');
  final ilst = findBoxInBytes(b, childStart, b.length, 'ilst');
  if (keys == null || ilst == null) return null;

  final index = _keyIndex(b, keys, _locationKey);
  if (index == null) return null;

  for (final entry in _walkEntries(b, ilst)) {
    if (entry.index != index) continue;
    final data = findBoxInBytes(b, entry.range.start, entry.range.end, 'data');
    if (data == null || data.length <= 8) continue;
    final text = b.sublist(data.start + 8, data.end);
    return parseIso6709(utf8.decode(text, allowMalformed: true));
  }
  return null;
}

/// 1-based index of [name] in a `keys` FullBox, or null.
int? _keyIndex(Uint8List b, BoxRange keys, String name) {
  var p = keys.start + 4; // version + flags
  if (p + 4 > keys.end) return null;
  final count = beU32(b, p);
  p += 4;
  for (var i = 1; i <= count && p + 8 <= keys.end; i++) {
    final size = beU32(b, p);
    if (size < 8 || p + size > keys.end) return null;
    final key = utf8.decode(b.sublist(p + 8, p + size), allowMalformed: true);
    if (key == name) return i;
    p += size;
  }
  return null;
}

typedef _IlstEntry = ({int index, BoxRange range});

/// `ilst` children are boxes whose type field is the key index.
Iterable<_IlstEntry> _walkEntries(Uint8List b, BoxRange ilst) sync* {
  var pos = ilst.start;
  while (pos + 8 <= ilst.end) {
    final size = beU32(b, pos);
    if (size < 8 || pos + size > ilst.end) return;
    yield (index: beU32(b, pos + 4), range: BoxRange(pos + 8, pos + size));
    pos += size;
  }
}

final _iso6709 = RegExp(r'^([+-]\d{1,2}(?:\.\d+)?)([+-]\d{1,3}(?:\.\d+)?)');

/// Parses the decimal-degree ISO 6709 form (`+DD.DDDD+DDD.DDDD[+ALT]/`)
/// that Apple and camera firmware write. Returns null for anything else.
GpsFix? parseIso6709(String value) {
  final m = _iso6709.firstMatch(value.trim());
  if (m == null) return null;
  final lat = double.tryParse(m.group(1)!);
  final lon = double.tryParse(m.group(2)!);
  if (lat == null || lon == null || !isPlausibleFix(lat, lon)) return null;
  return (latitude: lat, longitude: lon);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/data/services/quicktime_location_reader_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/media/data/services test/features/media/data/services
flutter analyze lib/features/media/data/services test/features/media/data/services
git add lib/features/media/data/services/quicktime_location_reader.dart test/features/media/data/services/quicktime_location_reader_test.dart
git commit -m "feat(media): read QuickTime ISO 6709 recording location"
```

---

### Task 5: GoPro GPMF GPS reader

**Files:**
- Create: `lib/features/media/data/services/gpmf_gps_reader.dart`
- Test: `test/features/media/data/services/gpmf_gps_reader_test.dart`

**Interfaces:**
- Consumes: Task 1 walker and readers; `GpsFix`, `isPlausibleFix`.
- Produces:
  - `GpsFix? gpsFromGpmfSample(Uint8List sample)`: parses one `gpmd` sample (a KLV stream); prefers `GPS9`, falls back to `GPS5` with `GPSF >= 2`.
  - `GpsFix? readGpmfGps(File file, {int maxSamples = 30})`: locates the `gpmd` track, walks up to [maxSamples] samples, returns the first plausible fix.

GPMF format notes for the implementer:
- Item: `key` (4 ASCII), `type` (1 byte), `structSize` (1 byte), `repeat` (uint16 BE). Payload is `structSize * repeat` bytes, padded to a multiple of 4. Type `0` means the payload is a nested KLV stream (`DEVC`, `STRM`).
- Type chars used here: `b` int8, `B` uint8, `s` int16, `S` uint16, `l` int32, `L` uint32, `f` float32, `?` complex (layout given by a sibling `TYPE` item, e.g. `lllllllSS` for `GPS9`).
- `GPS5`: type `l`, structSize 20 (lat, lon, alt, speed2d, speed3d), scaled by sibling `SCAL` (five values). Sibling `GPSF` (uint32) is the fix: 0 none, 2 = 2D, 3 = 3D.
- `GPS9`: type `?`, `TYPE` = `lllllllSS`, structSize 32 (lat, lon, alt, speed2d, speed3d, daysSince2000, secsSinceMidnight, dop, fix); `SCAL` has nine values; `fix` is the last field of each sample.
- Track locating: `moov > trak*`; pick the one whose `mdia > hdlr` handler type (bytes 8..12 of the hdlr payload) is `meta` and whose `mdia > minf > stbl > stsd` first entry type (bytes 12..16 of the stsd payload) is `gpmd`. Sample sizes from `stsz` (payload: version/flags, `sampleSize`, `sampleCount`, then per-sample sizes when `sampleSize == 0`), chunk offsets from `stco` (uint32) or `co64` (uint64), samples-per-chunk from `stsc` entries `{firstChunk, samplesPerChunk, sampleDescriptionIndex}`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/gpmf_gps_reader_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/gpmf_gps_reader.dart';

import '../../../../helpers/media_container_fixtures.dart';

List<int> _s32(int v) => u32(v.toUnsigned(32));

/// One GPMF KLV item: key, type char, struct size, repeat, payload padded
/// to 4 bytes. [type] 0 nests a KLV stream.
List<int> klv(String key, int type, int structSize, int repeat, List<int> data) {
  final padded = [...data, ...List.filled((4 - data.length % 4) % 4, 0)];
  return [...key.codeUnits, type, structSize, ...u16(repeat), ...padded];
}

int t(String c) => c.codeUnitAt(0);

List<int> _gps5Stream({required int fix, required List<List<int>> samples}) {
  final scal = klv('SCAL', t('l'), 4, 5, [
    ..._s32(10000000), ..._s32(10000000), ..._s32(1000), ..._s32(1000), ..._s32(100),
  ]);
  final gpsf = klv('GPSF', t('L'), 4, 1, u32(fix));
  final gps5 = klv('GPS5', t('l'), 20, samples.length, [
    for (final s in samples) ...[for (final v in s) ..._s32(v)],
  ]);
  final strm = [...klv('STNM', t('c'), 1, 4, 'GPS '.codeUnits), ...scal, ...gpsf, ...gps5];
  return klv('DEVC', 0, 1, strm.length, klv('STRM', 0, 1, strm.length, strm));
}

List<int> _gps9Stream(List<({int lat, int lon, int fix})> samples) {
  final type = klv('TYPE', t('c'), 1, 9, 'lllllllSS'.codeUnits);
  final scal = klv('SCAL', t('l'), 4, 9, [
    ..._s32(10000000), ..._s32(10000000), ..._s32(1000), ..._s32(1000),
    ..._s32(100), ..._s32(1), ..._s32(1000), ..._s32(100), ..._s32(1),
  ]);
  final gps9 = klv('GPS9', t('?'), 32, samples.length, [
    for (final s in samples) ...[
      ..._s32(s.lat), ..._s32(s.lon), ..._s32(0), ..._s32(0), ..._s32(0),
      ..._s32(9000), ..._s32(0), ...u16(150), ...u16(s.fix),
    ],
  ]);
  final strm = [...type, ...scal, ...gps9];
  return klv('DEVC', 0, 1, strm.length, klv('STRM', 0, 1, strm.length, strm));
}

/// GoPro-shaped MP4: ftyp, mdat holding [samples] back to back, moov last
/// with a single meta/gpmd track whose sample tables point into mdat.
List<int> gpmfMp4(List<List<int>> samples) {
  final ftyp = box('ftyp', 'mp41'.codeUnits);
  final mdatPayload = [for (final s in samples) ...s];
  final mdat = box('mdat', mdatPayload);
  var offset = ftyp.length + 8;
  final offsets = <int>[];
  for (final s in samples) {
    offsets.add(offset);
    offset += s.length;
  }
  final hdlr = fullBox('hdlr', [0, 0, 0, 0, ...'meta'.codeUnits, ...List.filled(12, 0), 0]);
  final stsd = fullBox('stsd', [...u32(1), ...u32(16), ...'gpmd'.codeUnits, ...List.filled(8, 0)]);
  final stsz = fullBox('stsz', [...u32(0), ...u32(samples.length), for (final s in samples) ...u32(s.length)]);
  final stsc = fullBox('stsc', [...u32(1), ...u32(1), ...u32(1), ...u32(1)]);
  final stco = fullBox('stco', [...u32(offsets.length), for (final o in offsets) ...u32(o)]);
  final stbl = box('stbl', [...stsd, ...stsz, ...stsc, ...stco]);
  final minf = box('minf', stbl);
  final mdia = box('mdia', [...hdlr, ...minf]);
  final videoTrak = box('trak', box('mdia', fullBox('hdlr', [0, 0, 0, 0, ...'vide'.codeUnits, ...List.filled(13, 0)])));
  final moov = box('moov', [...box('mvhd', List.filled(100, 0)), ...videoTrak, ...box('trak', mdia)]);
  return [...ftyp, ...mdat, ...moov];
}

void main() {
  group('gpsFromGpmfSample', () {
    test('GPS5 with a 3D fix scales lat/lon by SCAL', () {
      final sample = Uint8List.fromList(
        _gps5Stream(fix: 3, samples: [[123456789, -987654321, 5000, 100, 100]]),
      );
      final fix = gpsFromGpmfSample(sample);
      expect(fix?.latitude, closeTo(12.3456789, 1e-7));
      expect(fix?.longitude, closeTo(-98.7654321, 1e-7));
    });

    test('GPS5 without a fix yields null', () {
      final sample = Uint8List.fromList(
        _gps5Stream(fix: 0, samples: [[123456789, -987654321, 0, 0, 0]]),
      );
      expect(gpsFromGpmfSample(sample), isNull);
    });

    test('GPS9 takes the first sample whose own fix field is 2D or better', () {
      final sample = Uint8List.fromList(_gps9Stream([
        (lat: 0, lon: 0, fix: 0),
        (lat: 205000000, lon: -872500000, fix: 2),
      ]));
      final fix = gpsFromGpmfSample(sample);
      expect(fix?.latitude, closeTo(20.5, 1e-7));
      expect(fix?.longitude, closeTo(-87.25, 1e-7));
    });

    test('a truncated or garbage stream yields null', () {
      expect(gpsFromGpmfSample(Uint8List.fromList([1, 2, 3])), isNull);
      final full = _gps5Stream(fix: 3, samples: [[1, 2, 3, 4, 5]]);
      expect(gpsFromGpmfSample(Uint8List.fromList(full.sublist(0, full.length ~/ 2))), isNull);
    });
  });

  group('readGpmfGps', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gpmf_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    File write(String name, List<int> bytes) =>
        File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

    test('finds the gpmd track behind a video track and reads the first fix', () {
      final f = write('a.mp4', gpmfMp4([
        _gps5Stream(fix: 3, samples: [[123456789, -987654321, 0, 0, 0]]),
      ]));
      final fix = readGpmfGps(f);
      expect(fix?.latitude, closeTo(12.3456789, 1e-7));
    });

    test('walks forward past cold-start samples without a fix', () {
      final cold = _gps5Stream(fix: 0, samples: [[0, 0, 0, 0, 0]]);
      final warm = _gps5Stream(fix: 2, samples: [[100000000, 200000000, 0, 0, 0]]);
      final f = write('b.mp4', gpmfMp4([cold, cold, cold, warm]));
      expect(readGpmfGps(f)?.latitude, closeTo(10.0, 1e-7));
    });

    test('gives up after maxSamples', () {
      final cold = _gps5Stream(fix: 0, samples: [[0, 0, 0, 0, 0]]);
      final warm = _gps5Stream(fix: 3, samples: [[100000000, 200000000, 0, 0, 0]]);
      final f = write('c.mp4', gpmfMp4([...List.filled(30, cold), warm]));
      expect(readGpmfGps(f, maxSamples: 30), isNull);
      expect(readGpmfGps(f, maxSamples: 31), isNotNull);
    });

    test('returns null without a gpmd track or for a missing file', () {
      final f = write('d.mp4', [...box('ftyp', 'isom'.codeUnits), ...box('moov', box('mvhd', []))]);
      expect(readGpmfGps(f), isNull);
      expect(readGpmfGps(File('${tempDir.path}/none.mp4')), isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/services/gpmf_gps_reader_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Create `gpmf_gps_reader.dart`**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

/// Reads the first GPS fix from a GoPro clip's GPMF telemetry.
///
/// GoPro writes telemetry as samples of a `gpmd` metadata track (one sample
/// per second). Each sample is a KLV stream; the GPS lives in a `STRM`
/// holding `GPS9` (HERO11 and later, per-sample fix) or `GPS5` (older, with a
/// sibling `GPSF` fix flag). The reader walks the sample tables and reads one
/// sample at a time, so the multi-GB `mdat` is never loaded. Cold-start clips
/// have no fix for the first seconds, so up to [maxSamples] samples are
/// tried before giving up.
GpsFix? readGpmfGps(File file, {int maxSamples = 30}) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final end = raf.lengthSync();
    final moov = findBox(raf, 0, end, 'moov');
    if (moov == null) return null;
    final stbl = _findGpmdSampleTable(raf, moov);
    if (stbl == null) return null;
    for (final s in _sampleLocations(raf, stbl, maxSamples)) {
      if (s.size <= 0 || s.size > _maxSampleBytes || s.offset + s.size > end) {
        return null;
      }
      final fix = gpsFromGpmfSample(readBytesAt(raf, s.offset, s.size));
      if (fix != null) return fix;
    }
    return null;
  } on Object {
    return null;
  } finally {
    raf?.closeSync();
  }
}

const _maxSampleBytes = 1024 * 1024;
const _maxTableBytes = 4 * 1024 * 1024;

/// The `stbl` of the track whose handler is `meta` and whose sample entry is
/// `gpmd`, or null when the file has no GoPro telemetry track.
BoxRange? _findGpmdSampleTable(RandomAccessFile raf, BoxRange moov) {
  for (final trak in findBoxes(raf, moov.start, moov.end, 'trak')) {
    final mdia = findBox(raf, trak.start, trak.end, 'mdia');
    if (mdia == null) continue;
    final hdlr = findBox(raf, mdia.start, mdia.end, 'hdlr');
    if (hdlr == null || hdlr.length < 12) continue;
    if (fourCC(readBytesAt(raf, hdlr.start + 8, 4), 0) != 'meta') continue;
    final minf = findBox(raf, mdia.start, mdia.end, 'minf');
    if (minf == null) continue;
    final stbl = findBox(raf, minf.start, minf.end, 'stbl');
    if (stbl == null) continue;
    final stsd = findBox(raf, stbl.start, stbl.end, 'stsd');
    if (stsd == null || stsd.length < 16) continue;
    if (fourCC(readBytesAt(raf, stsd.start + 12, 4), 0) == 'gpmd') return stbl;
  }
  return null;
}

typedef _SampleLocation = ({int offset, int size});

/// Absolute (offset, size) of the first [limit] samples, derived from
/// `stsz` (sizes), `stsc` (samples per chunk) and `stco`/`co64` (chunk
/// offsets). Samples within a chunk are contiguous.
Iterable<_SampleLocation> _sampleLocations(
  RandomAccessFile raf,
  BoxRange stbl,
  int limit,
) sync* {
  final stsz = _payload(raf, stbl, 'stsz');
  final stsc = _payload(raf, stbl, 'stsc');
  final stco = _payload(raf, stbl, 'stco');
  final co64 = stco == null ? _payload(raf, stbl, 'co64') : null;
  if (stsz == null || stsc == null || (stco == null && co64 == null)) return;

  final constantSize = beU32(stsz, 4);
  final sampleCount = beU32(stsz, 8);
  int sizeOf(int i) {
    if (constantSize != 0) return constantSize;
    final p = 12 + i * 4;
    return p + 4 <= stsz.length ? beU32(stsz, p) : -1;
  }

  final chunkCount = beU32(stco ?? co64!, 4);
  int chunkOffset(int c) => stco != null
      ? beU32(stco, 8 + c * 4)
      : beU64(co64!, 8 + c * 8);

  final stscCount = beU32(stsc, 4);
  int samplesPerChunk(int chunkIndex1) {
    var result = 1;
    for (var e = 0; e < stscCount; e++) {
      final p = 8 + e * 12;
      if (p + 12 > stsc.length) break;
      if (beU32(stsc, p) <= chunkIndex1) result = beU32(stsc, p + 4);
    }
    return result;
  }

  var sample = 0;
  for (var c = 0; c < chunkCount && sample < sampleCount && sample < limit; c++) {
    final entryLen = stco != null ? 4 : 8;
    if (8 + (c + 1) * entryLen > (stco ?? co64!).length) return;
    var offset = chunkOffset(c);
    final perChunk = samplesPerChunk(c + 1);
    for (var k = 0; k < perChunk && sample < sampleCount && sample < limit; k++) {
      final size = sizeOf(sample);
      if (size < 0) return;
      yield (offset: offset, size: size);
      offset += size;
      sample++;
    }
  }
}

/// Payload bytes of the first [type] box inside [parent], bounded.
Uint8List? _payload(RandomAccessFile raf, BoxRange parent, String type) {
  final r = findBox(raf, parent.start, parent.end, type);
  if (r == null || r.length < 8 || r.length > _maxTableBytes) return null;
  return readBytesAt(raf, r.start, r.length);
}

/// Parses one `gpmd` sample. Public for unit tests and the real-sample gate.
GpsFix? gpsFromGpmfSample(Uint8List sample) {
  try {
    return _searchStreams(sample, 0, sample.length);
  } on Object {
    return null;
  }
}

typedef _Item = ({String key, int type, int structSize, int repeat, int dataStart, int dataEnd});

/// Yields the items of one KLV stream; stops at the first malformed header.
Iterable<_Item> _items(Uint8List b, int start, int end) sync* {
  var p = start;
  while (p + 8 <= end) {
    final key = fourCC(b, p);
    final type = b[p + 4];
    final structSize = b[p + 5];
    final repeat = beU16(b, p + 6);
    final len = structSize * repeat;
    final padded = (len + 3) & ~3;
    if (p + 8 + padded > end) return;
    yield (
      key: key,
      type: type,
      structSize: structSize,
      repeat: repeat,
      dataStart: p + 8,
      dataEnd: p + 8 + len,
    );
    p += 8 + padded;
  }
}

/// Depth-first search for a `STRM` carrying GPS9 or GPS5.
GpsFix? _searchStreams(Uint8List b, int start, int end) {
  for (final item in _items(b, start, end)) {
    if (item.key == 'STRM') {
      final fix = _gpsFromStream(b, item.dataStart, item.dataEnd);
      if (fix != null) return fix;
    } else if (item.type == 0) {
      final fix = _searchStreams(b, item.dataStart, item.dataEnd);
      if (fix != null) return fix;
    }
  }
  return null;
}

GpsFix? _gpsFromStream(Uint8List b, int start, int end) {
  _Item? gps9, gps5, scal, gpsf, type;
  for (final item in _items(b, start, end)) {
    switch (item.key) {
      case 'GPS9':
        gps9 = item;
      case 'GPS5':
        gps5 = item;
      case 'SCAL':
        scal = item;
      case 'GPSF':
        gpsf = item;
      case 'TYPE':
        type = item;
    }
  }
  if (scal == null) return null;
  final scale = _numbers(b, scal);
  if (scale.length < 2 || scale[0] == 0 || scale[1] == 0) return null;

  if (gps9 != null && type != null) {
    final layout = String.fromCharCodes(b, type.dataStart, type.dataEnd);
    final fieldSizes = layout.split('').map(_sizeOfType).toList();
    if (fieldSizes.contains(0)) return null;
    final structSize = fieldSizes.fold(0, (a, s) => a + s);
    if (structSize != gps9.structSize || layout.length < 9) return null;
    final fixIndex = layout.length - 1;
    for (var i = 0; i < gps9.repeat; i++) {
      final base = gps9.dataStart + i * structSize;
      final lat = _readTyped(b, base, layout[0]) / scale[0];
      final lon = _readTyped(b, base + fieldSizes[0], layout[1]) / scale[1];
      var fixOffset = base;
      for (var f = 0; f < fixIndex; f++) {
        fixOffset += fieldSizes[f];
      }
      final fix = _readTyped(b, fixOffset, layout[fixIndex]);
      if (fix >= 2 && isPlausibleFix(lat, lon)) {
        return (latitude: lat, longitude: lon);
      }
    }
    return null;
  }

  if (gps5 != null) {
    if (gpsf == null) return null;
    final fixFlag = _numbers(b, gpsf);
    if (fixFlag.isEmpty || fixFlag.first < 2) return null;
    if (gps5.structSize < 8 || gps5.repeat < 1) return null;
    for (var i = 0; i < gps5.repeat; i++) {
      final base = gps5.dataStart + i * gps5.structSize;
      final lat = beS32(b, base) / scale[0];
      final lon = beS32(b, base + 4) / scale[1];
      if (isPlausibleFix(lat, lon)) return (latitude: lat, longitude: lon);
    }
  }
  return null;
}

/// Decodes a numeric item (SCAL, GPSF) of any integer type into doubles.
List<double> _numbers(Uint8List b, _Item item) {
  final c = String.fromCharCode(item.type);
  final size = _sizeOfType(c);
  if (size == 0) return const [];
  final out = <double>[];
  for (var p = item.dataStart; p + size <= item.dataEnd; p += size) {
    out.add(_readTyped(b, p, c));
  }
  return out;
}

int _sizeOfType(String c) => switch (c) {
  'b' || 'B' || 'c' => 1,
  's' || 'S' => 2,
  'l' || 'L' || 'f' => 4,
  'j' || 'J' || 'd' => 8,
  _ => 0,
};

double _readTyped(Uint8List b, int p, String c) => switch (c) {
  'b' => b[p].toSigned(8).toDouble(),
  'B' || 'c' => b[p].toDouble(),
  's' => beS16(b, p).toDouble(),
  'S' => beU16(b, p).toDouble(),
  'l' => beS32(b, p).toDouble(),
  'L' => beU32(b, p).toDouble(),
  'f' => ByteData.sublistView(b, p, p + 4).getFloat32(0),
  'd' => ByteData.sublistView(b, p, p + 8).getFloat64(0),
  'j' => ByteData.sublistView(b, p, p + 8).getInt64(0).toDouble(),
  'J' => ByteData.sublistView(b, p, p + 8).getUint64(0).toDouble(),
  _ => double.nan,
};
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/data/services/gpmf_gps_reader_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/media/data/services test/features/media/data/services
flutter analyze lib/features/media/data/services test/features/media/data/services
git add lib/features/media/data/services/gpmf_gps_reader.dart test/features/media/data/services/gpmf_gps_reader_test.dart
git commit -m "feat(media): read the first GPS fix from GoPro GPMF telemetry"
```

---

### Task 6: Video dispatch and wiring into the extractor and desktop picker

**Files:**
- Modify: `lib/features/media/data/services/local_gps_reader.dart`
- Modify: `lib/features/media/data/services/exif_extractor.dart:97-112`
- Modify: `lib/features/media/data/services/photo_picker_service_desktop.dart:180-195`
- Test: `test/features/media/data/services/local_gps_reader_test.dart` (video group), `test/features/media/data/services/exif_extractor_test.dart` (pure-Dart fallback group), `test/features/media/data/services/photo_picker_service_desktop_test.dart`

**Interfaces:**
- Consumes: `readQuickTimeLocation` (Task 4), `readGpmfGps` (Task 5).
- Produces: `readLocalGps` now handles `video/mp4`, `video/quicktime`, `video/x-m4v`: QuickTime location first, then GPMF.

- [ ] **Step 1: Add the failing video tests to `local_gps_reader_test.dart`**

Append inside `main()`:

```dart
  group('readLocalGps for video', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('local_gps_video_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    List<int> xyz(String text) => box('©xyz', [
      ...u16(text.length),
      ...u16(0),
      ...text.codeUnits,
    ]);

    test('QuickTime location wins for a MOV', () {
      final f = File('${tempDir.path}/a.mov')
        ..writeAsBytesSync([
          ...box('ftyp', 'qt  '.codeUnits),
          ...box('moov', box('udta', xyz('+37.3323-122.0312/'))),
        ]);
      expect(readLocalGps(f, 'video/quicktime')?.latitude, closeTo(37.3323, 1e-6));
    });

    test('a video with neither location atom nor telemetry yields null', () {
      final f = File('${tempDir.path}/b.mp4')
        ..writeAsBytesSync([...box('ftyp', 'isom'.codeUnits), ...box('moov', box('mvhd', []))]);
      expect(readLocalGps(f, 'video/mp4'), isNull);
    });
  });
```

(The GPMF path through `readLocalGps` is exercised by the gated real-sample test in Task 7 and by `gpmf_gps_reader_test`; a synthetic GoPro file here would duplicate that fixture builder.)

- [ ] **Step 2: Add the failing extractor test**

In `exif_extractor_test.dart`, inside the `pure-Dart image fallback (native_exif unavailable)` group, add:

```dart
    test('reads GPS from JPEG bytes when native_exif is absent', () async {
      final image = img.Image(width: 4, height: 4);
      image.exif.gpsIfd.gpsLatitude = 20.5;
      image.exif.gpsIfd.gpsLatitudeRef = 'N';
      image.exif.gpsIfd.gpsLongitude = 87.25;
      image.exif.gpsIfd.gpsLongitudeRef = 'W';
      final f = File('${tempDir.path}/gps.jpg')
        ..writeAsBytesSync(img.encodeJpg(image));
      final meta = await ExifExtractor().extract(f);
      expect(meta?.latitude, closeTo(20.5, 1e-6));
      expect(meta?.longitude, closeTo(-87.25, 1e-6));
    });

    test('leaves GPS null for a JPEG without a GPS IFD', () async {
      final f = File('${tempDir.path}/nogps.jpg')
        ..writeAsBytesSync(jpegWithDateTimeOriginal('2025:12:27 12:08:19'));
      final meta = await ExifExtractor().extract(f);
      expect(meta?.latitude, isNull);
      expect(meta?.longitude, isNull);
    });
```

- [ ] **Step 3: Add the failing desktop picker test**

In `photo_picker_service_desktop_test.dart`, inside the `assetInfoForFile` group:

```dart
    test('carries EXIF GPS onto the asset', () {
      final image = img.Image(width: 4, height: 4);
      image.exif.gpsIfd.gpsLatitude = 20.5;
      image.exif.gpsIfd.gpsLatitudeRef = 'N';
      image.exif.gpsIfd.gpsLongitude = 87.25;
      image.exif.gpsIfd.gpsLongitudeRef = 'W';
      final file = File('${tempDir.path}/gps.jpg')
        ..writeAsBytesSync(img.encodeJpg(image));

      final asset = service.assetInfoForFile(file);

      expect(asset?.latitude, closeTo(20.5, 1e-6));
      expect(asset?.longitude, closeTo(-87.25, 1e-6));
    });

    test('leaves GPS null when the file has none', () {
      final file = _jpegWithExifDate(tempDir, 'nogps.jpg', '2025:07:14 17:22:31');
      final asset = service.assetInfoForFile(file);
      expect(asset?.latitude, isNull);
      expect(asset?.longitude, isNull);
    });
```

- [ ] **Step 4: Run the three test files to verify the new cases fail**

Run: `flutter test test/features/media/data/services/local_gps_reader_test.dart`
Expected: the two video tests FAIL (null for the MOV).
Run: `flutter test test/features/media/data/services/exif_extractor_test.dart`
Expected: "reads GPS from JPEG bytes" FAILS (latitude null).
Run: `flutter test test/features/media/data/services/photo_picker_service_desktop_test.dart`
Expected: "carries EXIF GPS" FAILS.

- [ ] **Step 5: Add the video branch to `readLocalGps`**

In `local_gps_reader.dart`, add the imports and the case:

```dart
import 'package:submersion/features/media/data/services/gpmf_gps_reader.dart';
import 'package:submersion/features/media/data/services/quicktime_location_reader.dart';
```

```dart
      case 'video/mp4':
      case 'video/quicktime':
      case 'video/x-m4v':
        // Phones and most cameras write a location atom; GoPro writes
        // telemetry instead. Try the cheap atom first.
        return readQuickTimeLocation(file) ?? readGpmfGps(file);
```

- [ ] **Step 6: Wire the extractor**

In `exif_extractor.dart`, add `import 'package:submersion/features/media/data/services/local_gps_reader.dart';` and, directly after `takenAt ??= readLocalCaptureTime(file, mime);`, add:

```dart
  // Same fallback for position: native_exif filled lat/lon on mobile stills;
  // everything else (desktop stills, video on every platform) reads the
  // file's own GPS IFD, QuickTime location atom, or GoPro telemetry.
  if (lat == null || lon == null) {
    final fix = readLocalGps(file, mime);
    if (fix != null) {
      lat = fix.latitude;
      lon = fix.longitude;
    }
  }
```

Also update the class doc comment's second paragraph to mention position: "the extractor then reads the capture time and position straight from the file's own container metadata with pure-Dart parsers ([readLocalCaptureTime], [readLocalGps])".

- [ ] **Step 7: Wire the desktop picker**

In `photo_picker_service_desktop.dart`, add `import 'package:submersion/features/media/data/services/local_gps_reader.dart';`. In `_assetInfoForPath`, after `final size = _dimensionsOf(ioFile, mime);` add `final fix = readLocalGps(ioFile, mime);` and replace the two hardcoded lines with:

```dart
    latitude: fix?.latitude,
    longitude: fix?.longitude,
```

Update the `assetInfoForFile` doc comment: after the capture-time paragraph add "Position comes from the same container metadata via [readLocalGps] (EXIF GPS IFD for stills, the QuickTime location atom or GoPro telemetry for video)."

- [ ] **Step 8: Run the three test files to verify they pass**

Run: `flutter test test/features/media/data/services/local_gps_reader_test.dart`
Expected: PASS.
Run: `flutter test test/features/media/data/services/exif_extractor_test.dart`
Expected: PASS.
Run: `flutter test test/features/media/data/services/photo_picker_service_desktop_test.dart`
Expected: PASS.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format lib/features/media test/features/media
flutter analyze lib/features/media test/features/media
git add lib/features/media/data/services/local_gps_reader.dart lib/features/media/data/services/exif_extractor.dart lib/features/media/data/services/photo_picker_service_desktop.dart test/features/media/data/services/local_gps_reader_test.dart test/features/media/data/services/exif_extractor_test.dart test/features/media/data/services/photo_picker_service_desktop_test.dart
git commit -m "feat(media): populate GPS on desktop imports from stills and video"
```

---

### Task 7: Gated real-sample tests (GoPro and iPhone)

**Files:**
- Create: `test/features/media/data/services/video_gps_real_sample_test.dart`

**Interfaces:**
- Consumes: `readLocalGps` (Task 6), `readGpmfGps`, `readQuickTimeLocation`.
- Env vars: `GOPRO_MP4_SAMPLE`, `IPHONE_MOV_SAMPLE`, and the expected coordinates `GOPRO_EXPECTED_LAT`, `GOPRO_EXPECTED_LON`, `IPHONE_EXPECTED_LAT`, `IPHONE_EXPECTED_LON` (decimal degrees, checked to 3 decimals, about 100 m).

- [ ] **Step 1: Write the gated test**

```dart
/// Real-sample regression for the video GPS readers.
///
/// GPMF is a binary telemetry format and the QuickTime meta layout differs
/// between writers, so synthetic fixtures alone do not prove the readers.
/// Point these env vars at real clips (kept OUTSIDE the repo, e.g. in the
/// "submersion data" samples folder) and pass their expected positions:
///
///   flutter test \
///     --dart-define=GOPRO_MP4_SAMPLE=/path/GX010001.MP4 \
///     --dart-define=GOPRO_EXPECTED_LAT=20.5123 \
///     --dart-define=GOPRO_EXPECTED_LON=-87.2512 \
///     --dart-define=IPHONE_MOV_SAMPLE=/path/IMG_0001.MOV \
///     --dart-define=IPHONE_EXPECTED_LAT=20.5123 \
///     --dart-define=IPHONE_EXPECTED_LON=-87.2512 \
///     --run-skipped --tags=real-data \
///     test/features/media/data/services/video_gps_real_sample_test.dart
///
/// Without the env vars (or when a file is missing) every test skips so CI
/// and fresh clones stay green.
@Tags(['real-data'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/gpmf_gps_reader.dart';
import 'package:submersion/features/media/data/services/local_gps_reader.dart';
import 'package:submersion/features/media/data/services/quicktime_location_reader.dart';

const _goPro = String.fromEnvironment('GOPRO_MP4_SAMPLE');
const _goProLat = String.fromEnvironment('GOPRO_EXPECTED_LAT');
const _goProLon = String.fromEnvironment('GOPRO_EXPECTED_LON');
const _iphone = String.fromEnvironment('IPHONE_MOV_SAMPLE');
const _iphoneLat = String.fromEnvironment('IPHONE_EXPECTED_LAT');
const _iphoneLon = String.fromEnvironment('IPHONE_EXPECTED_LON');

bool _skipUnless(String path, String lat, String lon, String name) {
  if (path.isNotEmpty && File(path).existsSync() && lat.isNotEmpty && lon.isNotEmpty) {
    return false;
  }
  markTestSkipped(
    '$name sample not available. Set the *_SAMPLE and *_EXPECTED_* '
    'dart-defines and pass --run-skipped --tags=real-data to run.',
  );
  return true;
}

void main() {
  group('GoPro GPMF real sample', () {
    test('readGpmfGps and readLocalGps agree with the expected position', () {
      if (_skipUnless(_goPro, _goProLat, _goProLon, 'GoPro')) return;
      final file = File(_goPro);
      final direct = readGpmfGps(file);
      final viaDispatch = readLocalGps(file, 'video/mp4');
      expect(direct, isNotNull);
      expect(direct!.latitude, closeTo(double.parse(_goProLat), 0.001));
      expect(direct.longitude, closeTo(double.parse(_goProLon), 0.001));
      expect(viaDispatch, direct);
    });
  });

  group('iPhone MOV real sample', () {
    test('readQuickTimeLocation and readLocalGps agree with the expected position', () {
      if (_skipUnless(_iphone, _iphoneLat, _iphoneLon, 'iPhone')) return;
      final file = File(_iphone);
      final direct = readQuickTimeLocation(file);
      final viaDispatch = readLocalGps(file, 'video/quicktime');
      expect(direct, isNotNull);
      expect(direct!.latitude, closeTo(double.parse(_iphoneLat), 0.001));
      expect(direct.longitude, closeTo(double.parse(_iphoneLon), 0.001));
      expect(viaDispatch, direct);
    });
  });
}
```

- [ ] **Step 2: Run without samples to verify it skips cleanly**

Run: `flutter test test/features/media/data/services/video_gps_real_sample_test.dart`
Expected: 2 tests skipped, 0 failed.

- [ ] **Step 3: Run with real samples (BLOCKING GATE for this plan)**

Ask the user for one GoPro clip and one iPhone `.MOV` with location, plus their expected coordinates (from the phone's Photos "Info" panel or GoPro Quik). Run the command from the file's doc comment. Expected: 2 passed. If GPMF fails on the real clip, capture the first `gpmd` sample with `readBytesAt` and inspect the key list before changing the parser; the likely culprits are a `GPS9` `TYPE` layout that differs from `lllllllSS` or a `SCAL` typed `s` rather than `l`, both of which the parser already tolerates through `_sizeOfType`/`_readTyped`.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format test/features/media/data/services
flutter analyze test/features/media/data/services
git add test/features/media/data/services/video_gps_real_sample_test.dart
git commit -m "test(media): gated real-sample checks for GoPro and iPhone video GPS"
```

---

### Task 8: Whole-project verification

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```
Expected: no changes from format, "No issues found!".

- [ ] **Step 2: Run the media test tree**

Run: `flutter test test/features/media`
Expected: all pass.

- [ ] **Step 3: Full suite once**

Run: `flutter test`
Expected: all pass. If a known-flaky file fails (see the project memory list), rerun that file alone before treating it as a regression.

- [ ] **Step 4: Commit any formatting fallout**

```bash
git add -A lib test
git commit -m "chore: format after the GPS reader work"
```
(Skip if `git status` is clean.)

---

## Self-review notes

- Spec Section 2 coverage: shared plumbing (Tasks 1-2), stills (Task 3), QuickTime (Task 4), GPMF with the 30-sample cap (Task 5), dispatch and both wiring seams (Task 6), real-sample gate (Task 7).
- Type consistency: `GpsFix` is the single record type across readers; `readLocalGps(File, String)` is the only entry point the extractor and picker call.
- Out of scope (per spec): RAW formats, `getAssetMetadata` on the desktop picker (still returns null; the picker's `AssetInfo` carries the fix instead).
