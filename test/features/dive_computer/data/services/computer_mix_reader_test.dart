import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/computer_mix_reader.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

/// Issue #3021: the mix a dive computer recorded for a tank is read back
/// from the download's stored raw bytes, so a mix overwritten by an edit can
/// be restored.
void main() {
  late AppDatabase db;
  final parsedFor = <String, pigeon.ParsedDive>{};
  final parsedProducts = <String>[];

  Future<pigeon.ParsedDive> parseFn(
    String vendor,
    String product,
    int model,
    Uint8List rawData,
  ) async {
    parsedProducts.add(product);
    final parsed = parsedFor[product];
    if (parsed == null) throw StateError('unparseable');
    return parsed;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    parsedFor.clear();
    parsedProducts.clear();
    final now = DateTime.utc(2026, 10, 1);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(now.millisecondsSinceEpoch),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
    for (final id in ['dc1', 'dc2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              name: Value(id),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );
    }
  });

  tearDown(() => db.close());

  Future<void> insertSource(
    String id, {
    required String computerId,
    required bool isPrimary,
    bool withRawData = true,
  }) async {
    final now = DateTime.utc(2026, 10, 1);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: const Value('d1'),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            importedAt: Value(now),
            createdAt: Value(now),
            rawData: Value(
              withRawData ? Uint8List.fromList(const [1, 2, 3]) : null,
            ),
            descriptorVendor: const Value('Vendor'),
            // The product names which parse the fake returns.
            descriptorProduct: Value(id),
            descriptorModel: const Value(1),
          ),
        );
  }

  pigeon.ParsedDive parsed(
    List<pigeon.GasMix> mixes, {
    List<pigeon.TankInfo> tanks = const [],
  }) => pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 10,
    dateTimeDay: 1,
    dateTimeHour: 9,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 20,
    avgDepthMeters: 12,
    durationSeconds: 1800,
    samples: [
      pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0),
      pigeon.ProfileSample(timeSeconds: 60, depthMeters: 20),
    ],
    tanks: tanks,
    gasMixes: mixes,
    events: const [],
  );

  ComputerMixReader reader() => ComputerMixReader(db: db, parseFn: parseFn);

  test('reads the mix of the parsed tank the row came from', () async {
    await insertSource('s1', computerId: 'dc1', isPrimary: true);
    parsedFor['s1'] = parsed([
      pigeon.GasMix(index: 0, o2Percent: 32, hePercent: 0),
      pigeon.GasMix(index: 1, o2Percent: 50, hePercent: 0),
    ]);

    final mix = await reader().recordedMix(
      diveId: 'd1',
      tank: const domain.DiveTank(
        id: 't',
        computerId: 'dc1',
        sourceTankIndex: 1,
      ),
    );

    expect(mix, const domain.GasMix(o2: 50));
  });

  test('reads the source the tank names over the primary', () async {
    await insertSource('s1', computerId: 'dc1', isPrimary: true);
    await insertSource('s2', computerId: 'dc2', isPrimary: false);
    parsedFor['s1'] = parsed([
      pigeon.GasMix(index: 0, o2Percent: 21, hePercent: 0),
    ]);
    parsedFor['s2'] = parsed([
      pigeon.GasMix(index: 0, o2Percent: 36, hePercent: 0),
    ]);

    final mix = await reader().recordedMix(
      diveId: 'd1',
      tank: const domain.DiveTank(
        id: 't',
        computerId: 'dc2',
        sourceId: 's2',
        sourceTankIndex: 0,
      ),
    );

    expect(mix, const domain.GasMix(o2: 36));
    expect(parsedProducts, ['s2']);
  });

  test(
    'without a source id, reads the source of the tank\'s computer',
    () async {
      await insertSource('s1', computerId: 'dc1', isPrimary: true);
      await insertSource('s2', computerId: 'dc2', isPrimary: false);
      parsedFor['s1'] = parsed([
        pigeon.GasMix(index: 0, o2Percent: 21, hePercent: 0),
      ]);
      parsedFor['s2'] = parsed([
        pigeon.GasMix(index: 0, o2Percent: 36, hePercent: 0),
      ]);

      final mix = await reader().recordedMix(
        diveId: 'd1',
        tank: const domain.DiveTank(
          id: 't',
          computerId: 'dc2',
          sourceTankIndex: 0,
        ),
      );

      expect(mix, const domain.GasMix(o2: 36));
    },
  );

  test(
    'never reads another download when the tank\'s own kept no bytes',
    () async {
      await insertSource(
        's1',
        computerId: 'dc1',
        isPrimary: true,
        withRawData: false,
      );
      await insertSource('s2', computerId: 'dc2', isPrimary: false);
      parsedFor['s2'] = parsed([
        pigeon.GasMix(index: 0, o2Percent: 36, hePercent: 0),
      ]);

      // A row naming neither source nor computer belongs to the primary.
      final mix = await reader().recordedMix(
        diveId: 'd1',
        tank: const domain.DiveTank(id: 't', sourceTankIndex: 0),
      );

      expect(mix, isNull);
      expect(parsedProducts, isEmpty);
    },
  );

  test('a computer no source names falls back to the primary', () async {
    await insertSource('s1', computerId: 'dc1', isPrimary: true);
    parsedFor['s1'] = parsed([
      pigeon.GasMix(index: 0, o2Percent: 32, hePercent: 0),
    ]);

    final mix = await reader().recordedMix(
      diveId: 'd1',
      tank: const domain.DiveTank(
        id: 't',
        computerId: 'dc2',
        sourceTankIndex: 0,
      ),
    );

    expect(mix, const domain.GasMix(o2: 32));
  });

  test(
    'is null when the computer reported no mix, not the air default',
    () async {
      await insertSource('s1', computerId: 'dc1', isPrimary: true);
      // A transmitter tank, but no mix: the resolver defaults it to air.
      parsedFor['s1'] = parsed(
        const [],
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: -1,
            startPressureBar: 200,
            endPressureBar: 60,
          ),
        ],
      );

      final mix = await reader().recordedMix(
        diveId: 'd1',
        tank: const domain.DiveTank(
          id: 't',
          computerId: 'dc1',
          sourceTankIndex: 0,
        ),
      );

      expect(mix, isNull);
    },
  );

  test('is null for a hand-added tank, without parsing', () async {
    await insertSource('s1', computerId: 'dc1', isPrimary: true);
    parsedFor['s1'] = parsed([
      pigeon.GasMix(index: 0, o2Percent: 32, hePercent: 0),
    ]);

    final mix = await reader().recordedMix(
      diveId: 'd1',
      tank: const domain.DiveTank(id: 't'),
    );

    expect(mix, isNull);
    expect(parsedProducts, isEmpty);
  });

  test('is null when the source kept no raw data', () async {
    await insertSource(
      's1',
      computerId: 'dc1',
      isPrimary: true,
      withRawData: false,
    );

    final mix = await reader().recordedMix(
      diveId: 'd1',
      tank: const domain.DiveTank(
        id: 't',
        computerId: 'dc1',
        sourceTankIndex: 0,
      ),
    );

    expect(mix, isNull);
  });

  test('is null when the parse has no such tank', () async {
    await insertSource('s1', computerId: 'dc1', isPrimary: true);
    parsedFor['s1'] = parsed([
      pigeon.GasMix(index: 0, o2Percent: 32, hePercent: 0),
    ]);

    final mix = await reader().recordedMix(
      diveId: 'd1',
      tank: const domain.DiveTank(
        id: 't',
        computerId: 'dc1',
        sourceTankIndex: 3,
      ),
    );

    expect(mix, isNull);
  });

  test('is null, not a throw, when the bytes do not parse', () async {
    await insertSource('s1', computerId: 'dc1', isPrimary: true);

    final mix = await reader().recordedMix(
      diveId: 'd1',
      tank: const domain.DiveTank(
        id: 't',
        computerId: 'dc1',
        sourceTankIndex: 0,
      ),
    );

    expect(mix, isNull);
  });
}
