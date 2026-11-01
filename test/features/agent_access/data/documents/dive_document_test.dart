import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/agent_access/data/documents/dive_document.dart';
import 'package:submersion/features/agent_access/data/documents/media_document.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

void main() {
  final taken = DateTime.utc(2024, 5, 1, 10);

  Dive dive() => Dive(
    id: 'd1',
    diverId: 'A',
    dateTime: taken,
    maxDepth: 30.5,
    bottomTime: const Duration(minutes: 45),
    waterTemp: 24,
    tanks: const [
      DiveTank(
        id: 't1',
        volume: 12,
        workingPressure: 232,
        startPressure: 200,
        endPressure: 50,
        gasMix: GasMix(o2: 32),
        role: TankRole.backGas,
      ),
      DiveTank(id: 't2', gasMix: GasMix(o2: 50), role: TankRole.deco),
    ],
    profile: [
      for (var i = 0; i < 1200; i++)
        DiveProfilePoint(timestamp: i * 2, depth: i.toDouble() / 100),
    ],
  );

  MediaItem signature() => MediaItem(
    id: 'm1',
    diveId: 'd1',
    mediaType: MediaType.instructorSignature,
    takenAt: taken,
    createdAt: taken,
    updatedAt: taken,
    sourceType: MediaSourceType.localFile,
    localPath: '/photos/sig.png',
    imageData: Uint8List.fromList([9, 8, 7, 6, 5]),
  );

  group('diveDocument', () {
    test(
      'always emits metric unit-named keys and ISO dates without toLocal',
      () {
        final doc = diveDocument(dive());
        expect(doc['id'], 'd1');
        expect(doc['diver_id'], 'A');
        expect(doc['date_time'], '2024-05-01T10:00:00.000Z');
        expect(doc['max_depth_m'], 30.5);
        expect(doc['bottom_time_s'], 2700);
        expect(doc['water_temp_c'], 24.0);
        expect(doc.keys, isNot(contains('maxDepth')));
        expect(doc.keys, isNot(contains('waterTemp')));
        expect(doc['site'], isNull);
        expect(doc['trip'], isNull);
      },
    );

    test('profile is paged by offset and limit', () {
      final doc = diveDocument(dive(), include: const {'profile'});
      final p = doc['profile'] as Map;
      expect(p['total'], 1200);
      expect(p['offset'], 0);
      expect(p['limit'], 500);
      final samples = p['samples'] as List;
      expect(samples, hasLength(500));
      expect((samples.first as Map)['t_s'], 0);
      expect((samples.first as Map)['depth_m'], 0.0);
      final tail = diveDocument(
        dive(),
        include: const {'profile'},
        profileOffset: 1000,
        profileLimit: 500,
      );
      expect(((tail['profile'] as Map)['samples'] as List), hasLength(200));
    });

    test('blocks appear only when included', () {
      final bare = diveDocument(dive());
      for (final block in [
        'tanks',
        'buddies',
        'tags',
        'types',
        'weights',
        'sightings',
        'media',
        'profile',
      ]) {
        expect(bare.containsKey(block), isFalse, reason: block);
      }
      final withTanks = diveDocument(dive(), include: const {'tanks'});
      final tanks = (withTanks['tanks'] as List).cast<Map>();
      expect(tanks, hasLength(2));
      expect(tanks.first['start_pressure_bar'], 200.0);
      expect(tanks.first['volume_l'], 12.0);
      expect(tanks.first['o2_fraction'], closeTo(0.32, 1e-9));
      expect(tanks.first['he_fraction'], 0.0);
      expect(tanks.first['role'], 'backGas');
      expect(tanks.last['role'], 'deco');
      expect(withTanks.containsKey('profile'), isFalse);
    });

    test('media documents never carry imageData', () {
      final doc = diveDocument(
        dive(),
        include: const {'media'},
        media: [signature()],
      );
      final media = (doc['media'] as List).cast<Map>();
      expect(media, hasLength(1));
      final m = media.single;
      expect(m.keys, isNot(contains('imageData')));
      expect(m.keys, isNot(contains('image_data')));
      expect(m['local_path'], '/photos/sig.png');
      expect(m['source_type'], 'localFile');
      expect(m['captured_at'], '2024-05-01T10:00:00.000Z');
      expect(m.toString(), isNot(contains('[9, 8, 7, 6, 5]')));
      expect(
        mediaDocument(signature()).keys,
        unorderedEquals([
          'id',
          'source_type',
          'file_path',
          'local_path',
          'url',
          'thumbnail_path',
          'captured_at',
        ]),
      );
    });
  });
}
