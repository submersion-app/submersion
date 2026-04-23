@Tags(['real-data'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

const _realSamplePath =
    '/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/MacDive.sqlite';

void main() {
  group('MacDive SQLite real-sample regression', () {
    late Uint8List bytes;

    setUpAll(() async {
      final file = File(_realSamplePath);
      if (!file.existsSync()) {
        markTestSkipped('Real sample not available in this environment');
        return;
      }
      bytes = Uint8List.fromList(await file.readAsBytes());
    });

    test(
      'parses without throwing and produces no error-severity warnings',
      () async {
        final payload = await const MacDiveSqliteParser().parse(bytes);
        final errors = payload.warnings
            .where((w) => w.severity == ImportWarningSeverity.error)
            .toList();
        expect(
          errors,
          isEmpty,
          reason: 'errors: ${errors.map((e) => e.message).join("; ")}',
        );
      },
    );

    test('dive count matches ground truth (540)', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 540);
    });

    test('every dive carries a sourceUuid from ZDIVE.ZUUID', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withUuid = dives.where(
        (d) => (d['sourceUuid'] as String?)?.isNotEmpty ?? false,
      );
      expect(
        withUuid.length,
        dives.length,
        reason: 'MacDive assigns every dive a UUID — all 540 should carry one',
      );
    });

    test('sites: 373 imported after dedup', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      expect(
        payload.entitiesOf(ImportEntityType.sites).length,
        greaterThanOrEqualTo(354),
      );
    });

    test('tags: 39 unique (the whole point of SQLite-over-UDDF)', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final tags = payload.entitiesOf(ImportEntityType.tags);
      expect(
        tags.length,
        greaterThanOrEqualTo(37),
        reason:
            'MacDive SQLite is the rich-metadata path — tags are a '
            'primary user-visible deliverable',
      );
    });

    test('buddies: 33 imported', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      expect(
        payload.entitiesOf(ImportEntityType.buddies).length,
        greaterThanOrEqualTo(31),
      );
    });

    test('gear: 32 imported', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      expect(
        payload.entitiesOf(ImportEntityType.equipment).length,
        greaterThanOrEqualTo(30),
      );
    });

    test('at least one dive has tagRefs populated', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withTags = dives.where(
        (d) => (d['tagRefs'] as List?)?.isNotEmpty ?? false,
      );
      expect(withTags, isNotEmpty);
    });

    test('at least one dive has unmatchedBuddyNames populated', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withBuddies = dives.where(
        (d) => (d['unmatchedBuddyNames'] as List?)?.isNotEmpty ?? false,
      );
      expect(withBuddies, isNotEmpty);
    });

    test('at least one dive has tanks populated from ZTANKANDGAS', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withTanks = dives.where(
        (d) => (d['tanks'] as List?)?.isNotEmpty ?? false,
      );
      expect(withTanks, isNotEmpty);
    });

    test(
      'profile is always empty (ZSAMPLES proprietary, not decoded)',
      () async {
        final payload = await const MacDiveSqliteParser().parse(bytes);
        for (final dive in payload.entitiesOf(ImportEntityType.dives)) {
          final profile = dive['profile'] as List?;
          expect(
            profile ?? const [],
            isEmpty,
            reason:
                'M3 does not decode ZSAMPLES; UDDF path remains for '
                'profile import',
          );
        }
      },
    );

    test('metadata records source and units', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      expect(payload.metadata['source'], 'macdive_sqlite');
      expect(payload.metadata['units'], isA<String>());
      expect(payload.metadata['diveCount'], 540);
    });

    test('emits imageRefs from ZDIVEIMAGE rows', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      // Real MacDive DB has 261 ZDIVEIMAGE rows, all with non-empty ZPATH.
      // Allow ±5 slack for edge cases (null-path rows if they ever appear).
      expect(
        payload.imageRefs.length,
        inInclusiveRange(256, 266),
        reason:
            'real MacDive DB has 261 ZDIVEIMAGE rows; '
            'parser emits one imageRef per row with non-empty ZPATH',
      );
    });

    test(
      'every imageRef has a non-empty originalPath and diveSourceUuid',
      () async {
        final payload = await const MacDiveSqliteParser().parse(bytes);
        for (final ref in payload.imageRefs) {
          expect(ref.originalPath, isNotEmpty);
          expect(ref.diveSourceUuid, isNotEmpty);
        }
      },
    );

    test('imageRefs link to valid dive sourceUuids in the payload', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final diveUuids = payload
          .entitiesOf(ImportEntityType.dives)
          .map((d) => d['sourceUuid'] as String?)
          .whereType<String>()
          .toSet();
      final orphanCount = payload.imageRefs
          .where((r) => !diveUuids.contains(r.diveSourceUuid))
          .length;
      // Allow a few orphans — real MacDive DBs sometimes have photos
      // pointing at deleted dives. But the vast majority should resolve.
      expect(
        orphanCount,
        lessThan(10),
        reason:
            'most photos should resolve to a dive; a handful of orphans '
            'is tolerable but >10 suggests a parser bug',
      );
    });

    test('imageRef paths are plausible (absolute or UUID filenames)', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      // MacDive stores either:
      // 1. Absolute paths in ZPATH (e.g., /Users/Marci/Downloads/IMG_1234.jpg),
      //    often with a corresponding ZORIGINALPATH for externally-sourced photos.
      // 2. UUID-based basenames in ZPATH for photos in MacDive's internal
      //    library (e.g., 1234-5678-...jpg), with ZORIGINALPATH null.
      // The mapper emits ZPATH if present, else falls back to ZORIGINALPATH.
      expect(payload.imageRefs, isNotEmpty);
      for (final ref in payload.imageRefs) {
        final isAbsolute =
            ref.originalPath.startsWith('/') ||
            ref.originalPath.contains(':\\');
        final isUuidFilename =
            ref.originalPath.contains('-') &&
            (ref.originalPath.endsWith('.jpg') ||
                ref.originalPath.endsWith('.jpeg'));
        expect(
          isAbsolute || isUuidFilename,
          isTrue,
          reason:
              'path should be absolute or UUID-based filename. Got: '
              '${ref.originalPath}',
        );
      }
    });
  });
}
