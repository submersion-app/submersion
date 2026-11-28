import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_unlink.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

final _at = DateTime.utc(2026, 11, 1);

MediaItem _item({String? diveId, String? siteId, String? equipmentId}) =>
    MediaItem(
      id: 'p1',
      diveId: diveId,
      siteId: siteId,
      equipmentId: equipmentId,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      takenAt: _at,
      createdAt: _at,
      updatedAt: _at,
    );

EditSession<PhotoRecord> _session() => EditSession<PhotoRecord>(
  PhotoRecord(
    item: _item(diveId: 'd1'),
    species: const [],
    people: const [],
  ),
);

/// Writers whose unlink records the ids it was given, and whose drain
/// counts its runs.
({SittingMediaWriters writers, List<String> unlinked, List<int> drains})
_writers() {
  final unlinked = <String>[];
  final drains = <int>[];
  return (
    writers: SittingMediaWriters(
      writeRows: (_) async => const [],
      insertNetwork: (_) async => const [],
      unlink: (ids) async => unlinked.addAll(ids),
      replace: (_, _, _) async {},
      drainDeletes: () async => drains.add(1),
      enqueueUpload: (_) {},
    ),
    unlinked: unlinked,
    drains: drains,
  );
}

void main() {
  group('viewerOffersUnlink', () {
    test('a dive scope needs a dive link', () {
      expect(
        viewerOffersUnlink(ViewerUnlinkScope.dive, _item(diveId: 'd1')),
        isTrue,
      );
      expect(
        viewerOffersUnlink(ViewerUnlinkScope.dive, _item(siteId: 's1')),
        isFalse,
      );
    });

    test('a site scope needs a site link', () {
      expect(
        viewerOffersUnlink(ViewerUnlinkScope.site, _item(siteId: 's1')),
        isTrue,
      );
      expect(
        viewerOffersUnlink(ViewerUnlinkScope.site, _item(diveId: 'd1')),
        isFalse,
      );
    });

    test('a gear scope needs a gear link', () {
      expect(
        viewerOffersUnlink(ViewerUnlinkScope.gear, _item(equipmentId: 'g1')),
        isTrue,
      );
      expect(
        viewerOffersUnlink(ViewerUnlinkScope.gear, _item(diveId: 'd1')),
        isFalse,
      );
    });

    test('the library scope offers it for an item with no links', () {
      expect(viewerOffersUnlink(ViewerUnlinkScope.library, _item()), isTrue);
    });

    test('no scope offers nothing', () {
      expect(viewerOffersUnlink(null, _item(diveId: 'd1')), isFalse);
    });
  });

  test('holding marks the sitting changed with the unlink card', () {
    final session = _session();

    holdViewerUnlink(session, _writers().writers);

    expect(session.isDirty, isTrue);
    expect(session.changedCardIds, contains(photoUnlinkCardId));
    expect(viewerUnlinkHeld(session), isTrue);
    expect(viewerUnlinkDrain(session), isNotNull);
  });

  test('nothing held reads as not held, with no drain', () {
    final session = _session();

    expect(viewerUnlinkHeld(session), isFalse);
    expect(viewerUnlinkHeld(null), isFalse);
    expect(viewerUnlinkDrain(session), isNull);
  });

  test('undo drops only the unlink', () {
    final session = _session()..set(photoPinField, 42);
    holdViewerUnlink(session, _writers().writers);

    undoViewerUnlink(session);

    expect(viewerUnlinkHeld(session), isFalse);
    expect(viewerUnlinkDrain(session), isNull);
    expect(session.isDirty, isTrue, reason: 'the pin is still held');
    expect(session.changedCardIds, isNot(contains(photoUnlinkCardId)));
  });

  test('the held write unlinks the sitting photo', () async {
    final session = _session();
    final built = _writers();
    holdViewerUnlink(session, built.writers);

    await session.runHeldWrites();

    expect(built.unlinked, ['p1']);
  });

  test('the drain is the writers drain', () async {
    final session = _session();
    final built = _writers();
    holdViewerUnlink(session, built.writers);

    await viewerUnlinkDrain(session)!();

    expect(built.drains, [1]);
  });

  test('a disposed sitting reads as not held', () {
    final session = _session();
    holdViewerUnlink(session, _writers().writers);
    session.dispose();

    expect(viewerUnlinkHeld(session), isFalse);
    expect(viewerUnlinkDrain(session), isNull);
  });
}
