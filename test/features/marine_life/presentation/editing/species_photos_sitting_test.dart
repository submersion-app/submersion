import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_photos_sitting.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../media/presentation/support/media_widget_harness.dart';

/// Records each photo tagged instead of touching a database.
class _RecordingTagging extends SpeciesTaggingService {
  _RecordingTagging()
    : super(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      );

  final tagged = <({String mediaId, String speciesId})>[];
  Object? failWith;

  @override
  Future<MediaSpeciesTag> tagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    if (failWith case final error?) throw error;
    tagged.add((mediaId: mediaId, speciesId: speciesId));
    return MediaSpeciesTag(
      id: 't-$mediaId',
      mediaId: mediaId,
      speciesId: speciesId,
      createdAt: DateTime(2024),
    );
  }
}

/// Photos tagged on a species page are held in its sitting until Save
/// (issue #4527, phase 3).
void main() {
  late EditSession<Species> session;
  late _RecordingTagging tagging;

  setUp(() {
    session = EditSession(
      const Species(
        id: 'manta',
        commonName: 'Manta',
        category: SpeciesCategory.ray,
      ),
    );
    tagging = _RecordingTagging();
  });
  tearDown(() => session.dispose());

  test('holding tags is a change of Photos', () {
    holdSpeciesTags(session, [testMediaItem(id: 'p1')], tagging);

    expect(session.changedCardIds, {'photos'});
    expect(heldSpeciesTags(session).map((m) => m.id), ['p1']);
  });

  test('the same photo held twice is held once', () {
    holdSpeciesTags(session, [testMediaItem(id: 'p1')], tagging);
    holdSpeciesTags(session, [testMediaItem(id: 'p1')], tagging);

    expect(heldSpeciesTags(session), hasLength(1));
  });

  test('releasing the last one is no change', () {
    holdSpeciesTags(session, [testMediaItem(id: 'p1')], tagging);

    releaseSpeciesTag(session, 'p1');

    expect(session.isDirty, isFalse);
    expect(heldSpeciesTags(session), isEmpty);
  });

  test('the held write tags every held photo for the species', () async {
    holdSpeciesTags(session, [
      testMediaItem(id: 'p1'),
      testMediaItem(id: 'p2'),
    ], tagging);

    await session.runHeldWrites();

    expect(tagging.tagged, [
      (mediaId: 'p1', speciesId: 'manta'),
      (mediaId: 'p2', speciesId: 'manta'),
    ]);
  });

  test('a photo that cannot be tagged fails the whole write', () async {
    holdSpeciesTags(session, [testMediaItem(id: 'p1')], tagging);
    tagging.failWith = StateError('Media p1 does not exist');

    await expectLater(session.runHeldWrites(), throwsStateError);
  });

  group('photos added', () {
    PreparedMedia prepared(String id) =>
        (item: testMediaItem(id: id, diveId: 'd1'), enrichment: null);

    test('holding added photos is a change of Photos', () {
      holdSpeciesImports(
        session,
        [prepared('m1')],
        write: (list) async => const [],
        tagging: tagging,
      );

      expect(session.changedCardIds, {'photos'});
      expect(heldSpeciesImports(session).map((p) => p.item.id), ['m1']);
    });

    test('releasing the last added photo is no change', () {
      holdSpeciesImports(
        session,
        [prepared('m1')],
        write: (list) async => const [],
        tagging: tagging,
      );

      releaseSpeciesImport(session, 'm1');

      expect(session.isDirty, isFalse);
    });

    test('the held write writes the rows, then tags them', () async {
      final written = <String>[];
      holdSpeciesImports(
        session,
        [prepared('m1'), prepared('m2')],
        write: (list) async {
          written.addAll([for (final p in list) p.item.id]);
          return [for (final p in list) p.item];
        },
        tagging: tagging,
      );

      await session.runHeldWrites();

      expect(written, ['m1', 'm2']);
      expect(tagging.tagged.map((t) => t.mediaId), ['m1', 'm2']);
      expect(speciesImportsWritten(session), ['m1', 'm2']);
    });

    test('the same photo added twice is held once', () {
      // Prepared twice: two fresh row ids for one photo on one dive.
      PreparedMedia again(String rowId) => (
        item: testMediaItem(
          id: rowId,
          diveId: 'd1',
        ).copyWith(platformAssetId: 'IMG_1'),
        enrichment: null,
      );
      holdSpeciesImports(
        session,
        [again('m1')],
        write: (list) async => const [],
        tagging: tagging,
      );
      holdSpeciesImports(
        session,
        [again('m2')],
        write: (list) async => const [],
        tagging: tagging,
      );

      expect(heldSpeciesImports(session).map((p) => p.item.id), ['m1']);
    });

    test('a write that fails tags nothing', () async {
      holdSpeciesImports(
        session,
        [prepared('m1')],
        write: (list) async => throw StateError('disk full'),
        tagging: tagging,
      );

      await expectLater(session.runHeldWrites(), throwsStateError);
      expect(tagging.tagged, isEmpty);
    });
  });
}
