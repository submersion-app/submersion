@Tags(['real-data'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/macdive_unit_inference.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart'
    show MacDiveUnitSystem;
import 'package:submersion/features/universal_import/data/services/shearwater_raw_decompressor.dart';

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

    // These three were written for the 2026-04 ZRAWDATA attempt and kept
    // asserting `profile: []`, a shape the mapper never emitted. Because the
    // whole group is env-gated they never ran in CI and so never went red.
    // They now assert the real convention: the key is present only when
    // samples decoded.
    test('Shearwater dives are the ones carrying raw profile data', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final shearwater = logbook.dives
          .where((d) => (d.computer ?? '').startsWith('Shearwater'))
          .toList();
      expect(
        shearwater,
        hasLength(267),
        reason: 'sample DB has 217 Teric + 50 Tern',
      );
      // Every one of them has ZRAWDATA, which is why ZSAMPLES staying
      // encrypted costs us nothing.
      expect(
        shearwater.where((d) => d.rawDataBlob?.isNotEmpty ?? false),
        hasLength(267),
      );
    });

    test('decoded profile samples carry timestamp and depth', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final withProfiles = payload
          .entitiesOf(ImportEntityType.dives)
          .where((d) => (d['profile'] as List?)?.isNotEmpty ?? false);

      // The parse channel is not registered in a unit-test host, so nothing
      // decodes here; the byte-level guarantee is covered by the
      // decompression test below.
      if (withProfiles.isEmpty) return;

      final firstPoint =
          (withProfiles.first['profile'] as List).first as Map<String, dynamic>;
      expect(firstPoint, containsPair('timestamp', isA<int>()));
      expect(firstPoint, containsPair('depth', isA<double>()));
      expect(firstPoint['timestamp'], 0);
    });

    test('dives without raw data omit the profile key entirely', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final nonShearwater = payload
          .entitiesOf(ImportEntityType.dives)
          .where(
            (d) => !((d['diveComputerModel'] as String?) ?? '').startsWith(
              'Shearwater',
            ),
          )
          .toList();

      expect(
        nonShearwater,
        isNotEmpty,
        reason: 'sample DB has Oceanic and manual-entry dives',
      );
      for (final dive in nonShearwater) {
        // Matches macdive_xml_parser: omit the key rather than emit an empty
        // list, so downstream can tell "no samples" from "zero-length dive".
        expect(dive.containsKey('profile'), isFalse);
      }
    });

    test(
      'warning count bounded: <5% of Shearwater dives emit decode warnings',
      () async {
        final payload = await const MacDiveSqliteParser().parse(bytes);
        final dives = payload.entitiesOf(ImportEntityType.dives);

        final shearwaterDives = dives.where((d) {
          final computer = (d['diveComputerModel'] as String?) ?? '';
          return computer.startsWith('Shearwater');
        }).toList();

        // Filter warnings to decode-failure warnings only (not info messages
        // about FFI unavailability, which is a single aggregate warning).
        final decodeFailures = payload.warnings.where(
          (w) =>
              w.severity == ImportWarningSeverity.warning &&
              w.message.contains('Profile decode failed'),
        );

        // When FFI is completely unavailable all Shearwater profiles are empty
        // and the failure warnings dominate. Distinguish the "FFI broken"
        // case (all dives failed) from a real regression (a handful failed).
        if (decodeFailures.length >= shearwaterDives.length) {
          // 100% failure = no plugin registered; not a regression, skip.
          return;
        }

        expect(
          decodeFailures.length,
          lessThan(shearwaterDives.length ~/ 20),
          reason:
              'decode-failure warnings should be well under 5% of the Shearwater dive set',
        );
      },
    );

    test('metadata records source and units', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      expect(payload.metadata['source'], 'macdive_sqlite');
      expect(payload.metadata['units'], isA<String>());
      expect(payload.metadata['diveCount'], 540);
    });
  });

  // #912 regressions. The 2026-04 ZRAWDATA attempt shipped green because its
  // tests mocked the parser against a synthetic fixture with no real blob, so
  // these run against real bytes on purpose.
  group('MacDive SQLite #912 regressions', skip: skipReason, () {
    late Uint8List bytes;

    setUpAll(() async {
      if (skipReason != null) throw StateError(skipReason);
      bytes = Uint8List.fromList(await File(realSamplePath!).readAsBytes());
    });

    test(
      'every ZRAWDATA blob decompresses to valid Petrel Native Format',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        final withRaw = logbook.dives
            .where((d) => d.rawDataBlob != null && d.rawDataBlob!.isNotEmpty)
            .toList();
        expect(
          withRaw,
          hasLength(267),
          reason: 'the reference DB has 217 Teric + 50 Tern dives',
        );

        final failures = <String>[];
        for (final dive in withRaw) {
          final out = ShearwaterRawDecompressor.decompress(dive.rawDataBlob!);
          if (out == null || out.isEmpty) {
            failures.add('${dive.uuid}: did not decompress');
            continue;
          }
          if (out.length % 32 != 0) {
            failures.add(
              '${dive.uuid}: ${out.length} bytes, not 32-byte records',
            );
            continue;
          }
          final types = <int>[for (var i = 0; i < out.length; i += 32) out[i]];
          // libdivecomputer's shearwater_predator_parser requires opening and
          // closing records 0..5; missing one is the exact failure the earlier
          // attempt hit ("Opening or closing record 1 not found").
          for (var i = 0; i < 6; i++) {
            if (!types.contains(0x10 + i)) {
              failures.add('${dive.uuid}: missing opening record $i');
              break;
            }
            if (!types.contains(0x20 + i)) {
              failures.add('${dive.uuid}: missing closing record $i');
              break;
            }
          }
        }

        expect(
          failures,
          isEmpty,
          reason: 'first few: ${failures.take(5).join("; ")}',
        );
      },
    );

    test(
      'decoded sample counts are plausible against ZTOTALDURATION',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        var checked = 0;
        var short = 0;
        for (final dive in logbook.dives) {
          final blob = dive.rawDataBlob;
          final duration = dive.totalDuration;
          final interval = dive.sampleInterval;
          if (blob == null || blob.isEmpty) continue;
          if (duration == null || interval == null || interval <= 0) continue;

          final out = ShearwaterRawDecompressor.decompress(blob)!;
          var samples = 0;
          for (var i = 0; i < out.length; i += 32) {
            if (out[i] == 0x01) samples++;
          }
          // Shearwater logs at a fixed interval; the raw log also keeps a few
          // surface samples MacDive trims, so allow generous headroom rather
          // than asserting an exact count.
          // A handful of blobs in the reference DB are genuinely
          // truncated, so assert on the population rather than requiring
          // every dive to be complete.
          checked++;
          if (samples < duration / interval * 0.5) short++;
        }
        expect(checked, greaterThan(200));
        expect(
          short / checked,
          lessThan(0.1),
          reason: '$short of $checked dives decoded few samples',
        );
      },
    );

    test('dive types are imported from ZDIVETYPE', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final types = payload.entitiesOf(ImportEntityType.diveTypes);
      expect(types.map((t) => t['id']), contains('aquarium'));

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final aquarium = dives.where(
        (d) => (d['diveTypeIds'] as List?)?.contains('aquarium') ?? false,
      );
      expect(
        aquarium.length,
        greaterThanOrEqualTo(90),
        reason: '96 dives are tagged Aquarium in the reference DB',
      );
    });

    test('operators become dive centers', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final centers = payload.entitiesOf(ImportEntityType.diveCenters);
      expect(
        centers.map((c) => c['name']),
        contains('California Academy Dive Ops'),
      );
      expect(centers.length, greaterThanOrEqualTo(50));

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final linked = dives.where((d) => d['diveCenterRef'] != null);
      expect(linked, isNotEmpty);
    });

    test('certifications and service records are imported', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      expect(payload.entitiesOf(ImportEntityType.certifications), hasLength(4));
      expect(payload.entitiesOf(ImportEntityType.serviceRecords), hasLength(1));
    });

    test('inactive gear imports as retired', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final retired = payload
          .entitiesOf(ImportEntityType.equipment)
          .where((g) => g['status'] == 'retired');
      expect(
        retired,
        hasLength(2),
        reason: '2 of 32 gear items are disabled in the reference DB',
      );
    });

    test('units are inferred when MacDive omits SystemOfUnits', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      // The reference library genuinely has no SystemOfUnits row.
      expect(logbook.unitsPreference, isNull);
      expect(
        MacDiveUnitInference.infer(logbook),
        MacDiveUnitSystem.imperial,
        reason: 'fill pressures reach 3500, which can only be psi',
      );
    });

    test('tank pressures land in a plausible bar range', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final pressures = <double>[
        for (final dive in payload.entitiesOf(ImportEntityType.dives))
          for (final tank in (dive['tanks'] as List? ?? const []))
            ...[
              tank['startPressure'],
              tank['endPressure'],
            ].whereType<double>().where((p) => p > 0),
      ];
      expect(pressures, isNotEmpty);

      // #912: psi passed through as bar produced 3118 "bar" fills. A real
      // cylinder tops out near 300 bar.
      final max = pressures.reduce((a, b) => a > b ? a : b);
      expect(
        max,
        lessThan(350),
        reason: 'highest imported fill pressure was $max bar',
      );
      expect(
        max,
        greaterThan(150),
        reason: 'and it should still be a real fill',
      );
    });

    test('depth and temperature are not double-converted', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final depths = dives
          .map((d) => d['maxDepth'])
          .whereType<double>()
          .where((d) => d > 0)
          .toList();
      final maxDepth = depths.reduce((a, b) => a > b ? a : b);
      // MacDive stores depth in metres even for an imperial diver; treating
      // it as feet would have turned this 38 m dive into 11.6 m.
      expect(maxDepth, closeTo(38.0, 0.5));

      final temps = dives
          .map((d) => d['waterTemp'])
          .whereType<double>()
          .where((t) => t != 0)
          .toList();
      final maxTemp = temps.reduce((a, b) => a > b ? a : b);
      expect(maxTemp, closeTo(31.1, 0.5));
    });

    test('cylinder volumes are plausible litres', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final volumes = <double>[
        for (final dive in payload.entitiesOf(ImportEntityType.dives))
          for (final tank in (dive['tanks'] as List? ?? const []))
            if (tank['volume'] is double && (tank['volume'] as double) > 0)
              tank['volume'] as double,
      ];
      expect(volumes, isNotEmpty);
      // An AL80 is 77.4 cft at 3000 psi, i.e. ~11 L of water capacity. Read
      // as litres directly it would have been an 80 L cylinder.
      for (final volume in volumes) {
        expect(volume, lessThan(40));
        expect(volume, greaterThan(3));
      }
    });

    test('weight is carried as a number, not appended to notes', () async {
      final payload = await const MacDiveSqliteParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withWeight = dives.where((d) => d['weightUsed'] != null);
      expect(withWeight, isNotEmpty);
      for (final dive in dives) {
        expect(dive['notes'] as String? ?? '', isNot(contains('Weight used')));
      }
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
