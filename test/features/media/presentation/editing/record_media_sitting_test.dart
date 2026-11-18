import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Photos added, unlinked and relinked in a sitting, written at Save
/// (issue #4527, plan 6).
void main() {
  final dive = Dive(id: 'dive-1', dateTime: DateTime.utc(2026));
  MediaItem row(String id, int minute) => MediaItem(
    id: id,
    diveId: 'dive-1',
    mediaType: MediaType.photo,
    takenAt: DateTime.utc(2026, 1, 1, 10, minute),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final stored = [row('s1', 5), row('s2', 20)];

  late List<String> calls;
  late List<String> queued;
  late bool failRows;

  setUp(() {
    calls = [];
    queued = [];
    failRows = false;
  });

  EditSession<Dive> started() {
    final session = EditSession<Dive>(dive);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    holdSittingMedia(
      session,
      SittingMediaWriters(
        writeRows: (prepared) async {
          if (failRows) throw StateError('disk full');
          calls.add('rows ${[for (final p in prepared) p.item.id]}');
          return [for (final p in prepared) p.item.id];
        },
        insertNetwork: (requests) async => const [],
        unlink: (ids) async => calls.add('unlink $ids'),
        replace: (proposals, afterCommit, onRollback) async {
          calls.add('replace ${proposals.length}');
          afterCommit.add(() async => calls.add('relink settled'));
          onRollback.add(() async => calls.add('relink undone'));
        },
        drainDeletes: () async => calls.add('drain deletes'),
        enqueueUpload: queued.add,
      ),
      cardId: 'media',
    );
    return session;
  }

  HeldMediaAdd added(String id, int minute) =>
      HeldMediaRow((item: row(id, minute), enrichment: null));

  test('an added photo and an unlinked one: written at Save, uploads queued '
      'after; Cancel writes nothing', () async {
    final session = started();
    addMediaToSitting(session, [added('n1', 10)]);
    unlinkMediaInSitting(session, {'s2'});
    expect(session.changedCardIds, {'media'});
    expect(calls, isEmpty);

    await session.runHeldWrites();
    expect(calls, ['rows [n1]', 'unlink [s2]']);
    expect(queued, isEmpty);
    for (final step in mediaAfterCommit(session)) {
      await step();
    }
    expect(queued, ['n1']);
    // The unlink's remote deletes wait for the commit too.
    expect(calls.last, 'drain deletes');

    final cancelled = started();
    addMediaToSitting(cancelled, [added('n2', 12)]);
    calls.clear();
    cancelled.dispose();
    expect(calls, isEmpty);
  });

  // Add photos then Scan gallery, or a drop then the same file picked:
  // each finds what the other already holds, which is not stored yet.
  test('the same photo added twice in a sitting is held once', () async {
    final session = started();
    HeldMediaAdd asset(String id, String assetId) => HeldMediaRow((
      item: row(id, 10).copyWith(platformAssetId: assetId),
      enrichment: null,
    ));
    HeldMediaAdd file(String id, String path) => HeldMediaRow((
      item: row(id, 11).copyWith(localPath: path),
      enrichment: null,
    ));
    addMediaToSitting(session, [
      asset('n1', 'gallery-7'),
      file('n2', '/a.jpg'),
    ]);
    addMediaToSitting(session, [
      asset('n3', 'gallery-7'),
      file('n4', '/a.jpg'),
      asset('n5', 'gallery-8'),
    ]);

    await session.runHeldWrites();
    expect(calls, ['rows [n1, n2, n5]']);
  });

  test("a relink's work outside the database waits for the commit", () async {
    final session = started();
    replaceLinkInSitting(
      session,
      's1',
      RepairProposal(
        item: stored.first,
        confidence: RepairConfidence.exact,
        candidate: const RepairCandidate.file(
          path: '/new/s1.jpg',
          sizeBytes: 4,
        ),
      ),
    );

    await session.runHeldWrites();
    expect(calls, ['replace 1']);
    for (final step in mediaAfterCommit(session)) {
      await step();
    }
    expect(calls, ['replace 1', 'relink settled']);
  });

  // Code review (#4527): what a relink wrote outside the database is
  // taken away when the save's write fails.
  group('undoMediaOnFailure', () {
    void relink(EditSession<Dive> session) => replaceLinkInSitting(
      session,
      's1',
      RepairProposal(
        item: stored.first,
        confidence: RepairConfidence.exact,
        candidate: const RepairCandidate.file(
          path: '/new/s1.jpg',
          sizeBytes: 4,
        ),
      ),
    );

    test('a write that fails after the relink: its undo runs, and the '
        'failure is the caller\'s', () async {
      final session = started();
      relink(session);

      await expectLater(
        undoMediaOnFailure(session, () async {
          await session.runHeldWrites();
          throw StateError('a later card failed');
        }),
        throwsStateError,
      );
      expect(calls, ['replace 1', 'relink undone']);
    });

    test('a write that goes through: nothing undone, its answer '
        'returned', () async {
      final session = started();
      relink(session);

      final answer = await undoMediaOnFailure(session, () async {
        await session.runHeldWrites();
        return 7;
      });
      expect(answer, 7);
      expect(calls, ['replace 1']);
    });

    test('an undo that fails is logged; the rest still run', () async {
      final session = EditSession<Dive>(dive);
      addTearDown(session.dispose);
      final ran = <String>[];
      holdSittingMedia(
        session,
        SittingMediaWriters(
          writeRows: (_) async => const [],
          insertNetwork: (_) async => const [],
          unlink: (_) async {},
          replace: (proposals, afterCommit, onRollback) async => onRollback
            ..add(() async => throw StateError('keychain locked'))
            ..add(() async => ran.add('second')),
          drainDeletes: () async {},
          enqueueUpload: (_) {},
        ),
        cardId: 'media',
      );
      relink(session);

      await expectLater(
        undoMediaOnFailure(session, () async {
          await session.runHeldWrites();
          throw StateError('a later card failed');
        }),
        throwsStateError,
      );
      expect(ran, ['second']);
    });
  });

  test('a photo added then unlinked in the sitting: nothing held', () {
    final session = started();
    addMediaToSitting(session, [added('n1', 10)]);
    unlinkMediaInSitting(session, {'n1'});
    expect(session.isDirty, isFalse);
    expect(sittingMedia(session).added, isEmpty);
  });

  test('mediaInSitting: unlinked gone, added shown in time order, one synced '
      'in meanwhile kept', () {
    final session = started();
    addMediaToSitting(session, [added('n1', 10)]);
    unlinkMediaInSitting(session, {'s1'});
    final synced = [...stored, row('s3', 30)];
    expect(mediaInSitting(session, synced).map((m) => m.id), [
      'n1',
      's2',
      's3',
    ]);
  });

  test('a failing write leaves no after-commit work', () async {
    failRows = true;
    final session = started();
    addMediaToSitting(session, [added('n1', 10)]);
    await expectLater(session.runHeldWrites(), throwsStateError);
    expect(mediaAfterCommit(session), isEmpty);
  });

  // A sitting starts on every unlock, with or without media to write: its
  // writers must not need the media services (or the database behind
  // them) until Save writes something.
  test('the app\'s writers read nothing until a write runs', () {
    final read = <Object>[];
    T reading<T>(ProviderListenable<T> provider) {
      read.add(provider);
      throw StateError('read at unlock');
    }

    SittingMediaWriters.forDive(reading);
    expect(read, isEmpty);
  });
}
