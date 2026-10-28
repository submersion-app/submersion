import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_export_planner.dart';
import 'package:submersion/core/services/nearby/nearby_watermarks.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

String hlc(int ms, String node) =>
    '${ms.toString().padLeft(15, '0')}:000000:$node';

NearbyWatermarks marks(Map<String, String> m) => NearbyWatermarks(m);

SyncPayload payload({
  required List<Map<String, dynamic>> tags,
  List<Map<String, dynamic>> media = const [],
  List<SyncDeletion> tagDeletions = const [],
}) {
  final data = SyncData.fromJson({'tags': tags, 'media': media});
  return SyncPayload(
    version: syncFormatVersion,
    exportedAt: 0,
    deviceId: 'me',
    checksum: SyncDataSerializer.checksumOf(data),
    data: data,
    deletions: {'tags': tagDeletions},
  );
}

void main() {
  group('NearbyWatermarks', () {
    test('json round-trips and writerOf reads the node id', () {
      final m = marks({'aaa': hlc(5, 'aaa')});
      expect(NearbyWatermarks.fromJson(m.toJson()).highByWriter, {
        'aaa': hlc(5, 'aaa'),
      });
      expect(NearbyWatermarks.writerOf(hlc(5, 'a-b-c')), 'a-b-c');
      expect(NearbyWatermarks.writerOf('garbage'), isNull);
    });
  });

  group('decide', () {
    test('full when the peer lacks a writer I hold', () {
      expect(
        NearbyExportPlanner.decide(
          mine: marks({'aaa': hlc(5, 'aaa'), 'bbb': hlc(5, 'bbb')}),
          peers: marks({'aaa': hlc(1, 'aaa')}),
        ),
        NearbyExportKind.full,
      );
    });

    test('full when the peer map is empty', () {
      expect(
        NearbyExportPlanner.decide(
          mine: marks({'aaa': hlc(5, 'aaa')}),
          peers: marks({}),
        ),
        NearbyExportKind.full,
      );
    });

    test('delta when the peer knows every writer I hold', () {
      expect(
        NearbyExportPlanner.decide(
          mine: marks({'aaa': hlc(5, 'aaa')}),
          peers: marks({'aaa': hlc(1, 'aaa'), 'zzz': hlc(9, 'zzz')}),
        ),
        NearbyExportKind.delta,
      );
    });

    test('nothing when I hold nothing at all', () {
      expect(
        NearbyExportPlanner.decide(mine: marks({}), peers: marks({})),
        NearbyExportKind.nothing,
      );
    });
  });

  group('deltaWatermark', () {
    test('is the lowest peer mark among writers I am ahead on', () {
      expect(
        NearbyExportPlanner.deltaWatermark(
          mine: marks({
            'aaa': hlc(50, 'aaa'),
            'bbb': hlc(20, 'bbb'),
            'ccc': hlc(5, 'ccc'),
          }),
          peers: marks({
            'aaa': hlc(40, 'aaa'),
            'bbb': hlc(10, 'bbb'),
            // Equal: nothing new from ccc, so its very old mark must not
            // drag the export window back.
            'ccc': hlc(5, 'ccc'),
          }),
        ),
        hlc(10, 'bbb'),
      );
    });

    test('is null when the peer has everything', () {
      expect(
        NearbyExportPlanner.deltaWatermark(
          mine: marks({'aaa': hlc(5, 'aaa')}),
          peers: marks({'aaa': hlc(5, 'aaa')}),
        ),
        isNull,
      );
    });
  });

  group('filterByWriter', () {
    test('keeps only rows above the peer mark for their writer', () {
      final p = payload(
        tags: [
          {'id': 'old', 'hlc': hlc(5, 'aaa')},
          {'id': 'new', 'hlc': hlc(15, 'aaa')},
          {'id': 'other', 'hlc': hlc(1, 'bbb')},
          {'id': 'unknownWriter', 'hlc': hlc(1, 'zzz')},
          {'id': 'noClock'},
        ],
        tagDeletions: [
          SyncDeletion(id: 'gone-old', deletedAt: 1, hlc: hlc(5, 'aaa')),
          SyncDeletion(id: 'gone-new', deletedAt: 1, hlc: hlc(15, 'aaa')),
          const SyncDeletion(id: 'gone-legacy', deletedAt: 1),
        ],
      );
      final peers = marks({'aaa': hlc(10, 'aaa'), 'bbb': hlc(1, 'bbb')});

      final out = NearbyExportPlanner.filterByWriter(p, peers);

      expect(out.data.tags.map((r) => r['id']), [
        'new',
        'unknownWriter',
        'noClock',
      ]);
      expect(out.deletions['tags']!.map((d) => d.id), [
        'gone-new',
        'gone-legacy',
      ]);
      expect(SyncDataSerializer.checksumOf(out.data), out.checksum);
    });

    test('a media row stays when only a fact clock is newer', () {
      final p = payload(
        tags: const [],
        media: [
          {'id': 'm1', 'hlc': hlc(5, 'aaa'), 'uploadFactsHlc': hlc(30, 'bbb')},
          {'id': 'm2', 'hlc': hlc(5, 'aaa'), 'verifyFactsHlc': hlc(2, 'bbb')},
        ],
      );
      final out = NearbyExportPlanner.filterByWriter(
        p,
        marks({'aaa': hlc(10, 'aaa'), 'bbb': hlc(20, 'bbb')}),
      );
      expect(out.data.media.map((r) => r['id']), ['m1']);
    });
  });
}
