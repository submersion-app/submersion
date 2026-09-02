import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

/// The streamed base exists so a large library never materialises whole
/// (#358). It pages every table at a row count, which was right when a row
/// was one sample; a packed series row is a blob, and 2,000 of them plus
/// their base64 is exactly the peak that path was built to avoid. Blob
/// tables page on bytes instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory fakeAppTemp;
  setUpAll(() async {
    fakeAppTemp = await Directory.systemTemp.createTemp('blob_paging_temp_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              call.method == 'getTemporaryDirectory' ? fakeAppTemp.path : null,
        );
  });

  tearDownAll(() async {
    if (fakeAppTemp.existsSync()) await fakeAppTemp.delete(recursive: true);
  });

  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Six dives, each with a packed series big enough that a byte budget has
  /// to split them into several pages.
  Future<void> seedSeries() async {
    final dives = DiveRepository();
    final series = ProfileSeriesRepository();
    for (var d = 0; d < 6; d++) {
      await dives.createDive(
        domain.Dive(id: 'dive-$d', dateTime: DateTime(2026, 1, 1 + d)),
      );
      await series.insertSeries(
        diveId: 'dive-$d',
        samples: [
          for (var t = 0; t < 400; t++)
            ProfileSample(timestamp: t * 10, depth: (t % 40) + d.toDouble()),
        ],
        now: 1700000000000,
      );
    }
  }

  Future<Map<String, dynamic>> exportData({int? blobPageBytes}) async {
    final base = await SyncDataSerializer().exportBaseToTempFile(
      deviceId: 'me',
      deletions: const [],
      blobPageBytes: blobPageBytes ?? kBaseBlobPageBytes,
    );
    final json =
        jsonDecode(await File(base.path).readAsString())
            as Map<String, dynamic>;
    await File(base.path).delete();
    return json;
  }

  test(
    'a byte budget that splits the blob table exports every row once',
    () async {
      await seedSeries();

      final whole = await exportData();
      // Small enough that most pages hold a single series row.
      final paged = await exportData(blobPageBytes: 64);

      expect(
        (whole['data'] as Map<String, dynamic>)['diveProfileSeries'],
        hasLength(6),
      );
      expect(
        paged['data'],
        whole['data'],
        reason: 'the page boundary must not drop, duplicate or reorder a row',
      );
      expect(paged['checksum'], whole['checksum']);
    },
  );

  test('an empty blob table still terminates', () async {
    final paged = await exportData(blobPageBytes: 64);
    expect(
      (paged['data'] as Map<String, dynamic>)['diveProfileSeries'],
      isEmpty,
    );
  });

  group('the page budget itself', () {
    test('stops before the budget but always takes one row', () {
      final rows = [
        (id: 'a', bytes: 100),
        (id: 'b', bytes: 100),
        (id: 'c', bytes: 100),
      ];
      expect(idsWithinBlobBudget(rows, 250).map((r) => r.id), ['a', 'b']);
      // A single row over the budget still has to move, or the export stalls.
      expect(idsWithinBlobBudget(rows, 1).map((r) => r.id), ['a']);
      expect(idsWithinBlobBudget(rows, 100000).map((r) => r.id), [
        'a',
        'b',
        'c',
      ]);
      expect(idsWithinBlobBudget(const [], 100), isEmpty);
    });
  });
}
