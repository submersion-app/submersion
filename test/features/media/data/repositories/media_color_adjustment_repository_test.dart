import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide MediaEnrichment;
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3520: hand colour adjustments are narrow, synced writes.
void main() {
  late AppDatabase db;
  late MediaRepository media;
  late MediaColorAdjustmentRepository repository;
  final epoch = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    media = MediaRepository();
    repository = MediaColorAdjustmentRepository();
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diveDateTime: Value(epoch),
              createdAt: Value(epoch),
              updatedAt: Value(epoch),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<String> add(
    String id, {
    String? diveId = 'd1',
    MediaType type = MediaType.photo,
    ColorAdjustment? adjustment,
  }) async {
    final created = await media.createMedia(
      MediaItem(
        id: id,
        diveId: diveId,
        mediaType: type,
        sourceType: MediaSourceType.localFile,
        filePath: '/photos/$id',
        takenAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        colorAdjustment: adjustment,
      ),
    );
    return created.id;
  }

  Future<ColorAdjustment?> read(String id) async =>
      (await media.getMediaById(id))!.colorAdjustment;

  Future<String?> rawColumn(String id) async => (await (db.select(
    db.media,
  )..where((t) => t.id.equals(id))).getSingle()).colorAdjustment;

  Future<void> clearPending() => db.delete(db.syncRecords).go();

  Future<bool> isPending(String id) async => (await (db.select(
    db.syncRecords,
  )..where((t) => t.recordId.equals(id))).get()).isNotEmpty;

  group('setColorAdjustment', () {
    test('saves, reads back and queues a sync', () async {
      final id = await add('m1');
      await clearPending();
      const a = ColorAdjustment(warmth: 0.4);
      await repository.setColorAdjustment(id, a);
      expect(await read(id), a);
      expect(await isPending(id), isTrue);
    });

    test(
      'a neutral adjustment reads as none but is stored as a value',
      () async {
        // Not NULL: the media sync upsert never writes a null column, so a
        // NULL could not clear a peer's copy (media_color_adjustment_sync_test).
        final id = await add(
          'm1',
          adjustment: const ColorAdjustment(tint: 0.2),
        );
        await repository.setColorAdjustment(id, const ColorAdjustment());
        expect(await read(id), isNull);
        expect(await rawColumn(id), const ColorAdjustment().toJsonString());
      },
    );

    test('a missing row throws', () async {
      expect(
        () => repository.setColorAdjustment('nope', null),
        throwsStateError,
      );
    });
  });

  group('applySlidersToDive', () {
    const source = ColorAdjustment(
      autoOverride: true,
      warmth: 0.5,
      contrast: 0.2,
      whitePoint: WhitePoint(0.1, 0.2, 0.3),
    );
    const ownWhite = WhitePoint(0.4, 0.5, 0.6);

    test('copies sliders and auto to the siblings and returns the prior '
        'values', () async {
      final src = await add('src', adjustment: source);
      final plain = await add('plain');
      final tuned = await add(
        'tuned',
        adjustment: const ColorAdjustment(warmth: -0.3, whitePoint: ownWhite),
      );
      final video = await add('vid', type: MediaType.video);
      final doc = await add('doc', type: MediaType.document);
      final sig = await add('sig', type: MediaType.instructorSignature);
      final other = await add('other', diveId: 'd2');
      await clearPending();

      final prior = await repository.applySlidersToDive(
        diveId: 'd1',
        sourceMediaId: src,
        source: source,
      );

      expect(prior, {
        plain: null,
        tuned: const ColorAdjustment(warmth: -0.3, whitePoint: ownWhite),
        video: null,
      });
      const copied = ColorAdjustment(
        autoOverride: true,
        warmth: 0.5,
        contrast: 0.2,
      );
      expect(await read(plain), copied);
      expect(await read(video), copied);
      // Its own white point is kept; the source's is never copied.
      expect(await read(tuned), copied.copyWith(whitePoint: ownWhite));
      expect(await read(doc), isNull);
      expect(await read(other), isNull);
      expect(await read(src), source);
      for (final id in [plain, tuned, video]) {
        expect(await isPending(id), isTrue, reason: id);
      }
      expect(await read(sig), isNull);
      for (final id in [src, doc, sig, other]) {
        expect(await isPending(id), isFalse, reason: id);
      }
    });

    test('restore puts every prior value back exactly', () async {
      final src = await add('src', adjustment: source);
      final plain = await add('plain');
      final tuned = await add(
        'tuned',
        adjustment: const ColorAdjustment(tint: 0.1, whitePoint: ownWhite),
      );
      final prior = await repository.applySlidersToDive(
        diveId: 'd1',
        sourceMediaId: src,
        source: source,
      );
      await clearPending();

      await repository.restoreColorAdjustments(prior);

      expect(await read(plain), isNull);
      expect(
        await read(tuned),
        const ColorAdjustment(tint: 0.1, whitePoint: ownWhite),
      );
      expect(await isPending(plain), isTrue);
      expect(await isPending(tuned), isTrue);
    });

    test(
      'a sibling that already matches is not rewritten or counted',
      () async {
        final src = await add('src', adjustment: source);
        const copied = ColorAdjustment(
          autoOverride: true,
          warmth: 0.5,
          contrast: 0.2,
        );
        final same = await add('same', adjustment: copied);
        final plain = await add('plain');
        await clearPending();

        final prior = await repository.applySlidersToDive(
          diveId: 'd1',
          sourceMediaId: src,
          source: source,
        );

        expect(prior.keys, [plain]);
        expect(await isPending(same), isFalse);
        expect(await read(same), copied);
      },
    );

    test('restore skips rows deleted since', () async {
      final src = await add('src', adjustment: source);
      final plain = await add('plain');
      final prior = await repository.applySlidersToDive(
        diveId: 'd1',
        sourceMediaId: src,
        source: source,
      );
      await (db.delete(db.media)..where((t) => t.id.equals(plain))).go();
      await repository.restoreColorAdjustments(prior);
    });
  });

  test('enrichmentFor reads the stored match, or null', () async {
    final id = await add('m1');
    expect(await repository.enrichmentFor(id), isNull);
    await media.saveEnrichment(
      MediaEnrichment(
        id: 'e1',
        mediaId: id,
        diveId: 'd1',
        depthMeters: 14,
        elapsedSeconds: 600,
        matchConfidence: MatchConfidence.interpolated,
        createdAt: DateTime(2026, 6, 1),
      ),
    );
    final stored = await repository.enrichmentFor(id);
    expect(stored!.depthMeters, 14);
    expect(stored.matchConfidence, MatchConfidence.interpolated);
  });

  test('enrichmentFor survives two stored matches for one photo', () async {
    // Two devices each enriched the photo before seeing the other's row;
    // sync keeps both (they differ by id).
    final id = await add('m1');
    for (final (rowId, depth, at) in [('e1', 10.0, 1), ('e2', 14.0, 2)]) {
      await db
          .into(db.mediaEnrichment)
          .insert(
            MediaEnrichmentCompanion.insert(
              id: rowId,
              mediaId: id,
              diveId: 'd1',
              depthMeters: Value(depth),
              createdAt: at,
            ),
          );
    }
    expect((await repository.enrichmentFor(id))!.depthMeters, 14);
  });

  test('countOtherMediaOnDive skips the source and documents', () async {
    final src = await add('src');
    await add('a');
    await add('b', type: MediaType.video);
    await add('doc', type: MediaType.document);
    await add('other', diveId: 'd2');
    expect(await repository.countOtherMediaOnDive('d1', src), 2);
  });
}
