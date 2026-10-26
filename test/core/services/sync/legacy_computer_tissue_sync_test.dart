import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Issue #2555. A peer still below v318 publishes dives whose computer
/// tissue snapshot holds the CNS, OTU and deco model, with the dive's own
/// columns empty (Suunto, Shearwater Cloud). The v318 rung has already run
/// here, so applying such a row has to move those values into their columns
/// itself, or the slimmer snapshot reader drops them.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    SyncClock.instance.reset();
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  SyncService buildService() =>
      SyncService(syncRepository: SyncRepository(), serializer: serializer);

  final legacySnapshot = jsonEncode({
    'algorithm': 'Suunto Fused2 RGBM',
    'start': {'cns_percent': 3.0, 'otu': 0.0},
    'end': {
      'n2_bar': [1.4, 1.2],
      'cns_percent': 13.2,
      'otu': 35.57,
    },
  });

  /// A dive as a pre-v318 peer publishes it: snapshot filled, columns empty.
  Future<SyncPayload> legacyPeerPayload() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'template', diveNumber: 1),
    );
    final template = (await serializer.fetchRecord('dives', 'template'))!;
    final data = SyncData(
      dives: [
        {
          ...template,
          'id': 'peer-dive',
          'cnsStart': 0.0,
          'cnsEnd': null,
          'otu': null,
          'decoAlgorithm': null,
          'computerTissueJson': legacySnapshot,
          'updatedAt': DateTime.now().millisecondsSinceEpoch + 60000,
          'hlc': Hlc(
            DateTime.now().millisecondsSinceEpoch + 60000,
            0,
            'peer-dev',
          ).toString(),
        },
      ],
    );
    return SyncPayload(
      version: syncFormatVersion,
      exportedAt: 9000,
      deviceId: 'peer-dev',
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: const {},
    );
  }

  Future<void> expectMoved() async {
    final row = (await serializer.fetchRecord('dives', 'peer-dive'))!;
    expect(row['cnsStart'], 3.0);
    expect(row['cnsEnd'], 13.2);
    expect(row['otu'], 35.57);
    expect(row['decoAlgorithm'], 'Suunto Fused2 RGBM');
    expect(jsonDecode(row['computerTissueJson'] as String), {
      'end': {
        'n2_bar': [1.4, 1.2],
      },
    });
  }

  test('a payload applied from an older peer gets its values moved', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugApplyPayload(payload);

    await expectMoved();
  });

  test('a move that fails does not fail the sync', () async {
    final payload = await legacyPeerPayload();
    // A local row the move cannot read: SQLite keeps text a REAL column
    // cannot convert, so reading cns_start as a number throws.
    await DatabaseService.instance.database.customStatement(
      "UPDATE dives SET cns_start = 'junk', computer_tissue_json = "
      '\'{"end":{"otu":1.0}}\' WHERE id = \'template\'',
    );

    final result = await buildService().debugApplyPayload(payload);

    expect(result.recordsFailed, 0);
    expect(await serializer.fetchRecord('dives', 'peer-dive'), isNotNull);
  });

  test(
    'a base file applied from an older peer gets its values moved',
    () async {
      final payload = await legacyPeerPayload();
      final dir = await Directory.systemTemp.createTemp('legacy_tissue');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'base.json'));
      await file.writeAsBytes(
        utf8.encode(serializer.serializePayload(payload)),
      );

      await buildService().debugApplyBaseFile(file.path);

      await expectMoved();
    },
  );
}
