@Tags(['real-data'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

const _realSamplePathEnvVar = 'MACDIVE_SQLITE_REAL_SAMPLE_PATH';

void main() {
  final realSamplePath = Platform.environment[_realSamplePathEnvVar];
  final skipReason = _resolveSkipReason(realSamplePath);

  group('MacDive SQLite real-sample regression', skip: skipReason, () {
    late Uint8List bytes;

    setUpAll(() async {
      if (skipReason != null) {
        // Surfaces a clear reason if someone forces --run-skipped without the
        // env var, instead of a cryptic null-check error.
        throw StateError(skipReason);
      }
      bytes = Uint8List.fromList(await File(realSamplePath!).readAsBytes());
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

    test('at least one dive has equipmentRefs linking to imported gear', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withGear = dives.where(
        (d) => (d['equipmentRefs'] as List?)?.isNotEmpty ?? false,
      );
      expect(
        withGear,
        isNotEmpty,
        reason:
            'MacDive SQLite has dive↔gear junctions (Z_5RELATIONSHIPGEARITEMS); '
            'at least one dive in the 540-dive sample should carry equipmentRefs',
      );

      final equipment = payload.entitiesOf(ImportEntityType.equipment);
      final uddfIds = equipment
          .map((g) => g['uddfId'] as String?)
          .whereType<String>()
          .toSet();
      for (final dive in withGear) {
        for (final ref in (dive['equipmentRefs'] as List).cast<String>()) {
          expect(
            uddfIds,
            contains(ref),
            reason:
                'every equipmentRef must resolve to an emitted gear uddfId so '
                'UddfEntityImporter.equipmentIdMapping picks it up',
          );
        }
      }
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
  });
}

String? _resolveSkipReason(String? path) {
  if (path == null || path.isEmpty) {
    return 'Set $_realSamplePathEnvVar to a MacDive SQLite path to run this test';
  }
  if (!File(path).existsSync()) {
    return 'Real sample not found at $path (from $_realSamplePathEnvVar)';
  }
  return null;
}
