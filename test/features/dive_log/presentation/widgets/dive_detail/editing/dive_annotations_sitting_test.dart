import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_providers.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/test_database.dart';

/// Fails its first read, then reads the database.
class _FailingOnceRepo extends AnnotationRepository {
  var reads = 0;

  @override
  Future<List<ProfileEvent>> annotationsForDive(String diveId) {
    if (reads++ == 0) throw StateError('database closed');
    return super.annotationsForDive(diveId);
  }
}

/// Annotations placed, moved and removed in a sitting, settled with the
/// notes at Save (issue #4527, plan 6).
void main() {
  late AppDatabase db;
  late AnnotationRepository repo;
  late ProviderContainer container;
  late String storedId;
  late Dive dive;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = AnnotationRepository();
    container = ProviderContainer();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, notes, created_at, updated_at) '
      "VALUES ('d1', 0, 'Calm', 0, 0)",
    );
    storedId = await repo.addAnnotation(
      diveId: 'd1',
      timestamp: 300,
      depth: 12,
      words: 'turtle',
    );
    final notes =
        (await db
                .customSelect("SELECT notes FROM dives WHERE id = 'd1'")
                .getSingle())
            .read<String>('notes');
    dive = Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026),
      notes: notes,
      runtime: const Duration(minutes: 40),
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<EditSession<Dive>> started() async {
    final session = EditSession<Dive>(dive);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    loadDiveAnnotations(session, container.read);
    await session.settled();
    return session;
  }

  /// What Save does after the dive row is written: the dive's own write
  /// is the save service's; here the notes are written as it would.
  Future<void> save(EditSession<Dive> session) async {
    await db.customStatement('UPDATE dives SET notes = ? WHERE id = ?', [
      session.working.notes,
      'd1',
    ]);
    await session.runHeldWrites();
  }

  Future<List<String>> storedIds() async => [
    for (final a in await repo.annotationsForDive('d1')) a.id,
  ];

  test('placing appends a linked line to the notes and holds one placed: '
      'Notes and Profile both changed', () async {
    final session = await started();
    final id = placeAnnotation(session, seconds: 600, words: 'manta')!;

    expect(
      session.working.notes,
      contains(annotationLinkMarkdown('manta', id)),
    );
    expect(session.changedCardIds, {'notes', 'profile'});
    expect(
      sittingAnnotationEvents(session).map((e) => e.id),
      containsAll([storedId, id]),
    );

    await save(session);
    expect(await storedIds(), containsAll([storedId, id]));
  });

  test(
    'placed then removed: the notes are as stored and nothing is held',
    () async {
      final session = await started();
      final id = placeAnnotation(session, seconds: 600, words: 'manta')!;
      removeSittingAnnotation(session, id);

      expect(session.working.notes, dive.notes);
      expect(session.isDirty, isFalse);
    },
  );

  test(
    'placed, then its line deleted in the notes: nothing is written',
    () async {
      final session = await started();
      final id = placeAnnotation(session, seconds: 600, words: 'manta')!;
      session.set(diveNotesField, dive.notes);
      // Nothing is left to save: no Profile dot, no History entry.
      expect(session.changedCardIds, isEmpty);
      expect(session.isDirty, isFalse);

      await save(session);
      expect(await storedIds(), [storedId]);
      expect(sittingAnnotationEvents(session).map((e) => e.id), [storedId]);
      expect(id, isNot(storedId));
    },
  );

  test('a stored annotation moved: moveAnnotation at Save; moved back: no '
      'change', () async {
    final session = await started();
    moveSittingAnnotation(session, storedId, seconds: 900, depth: 18);
    expect(session.changedCardIds, {'profile'});
    expect(sittingAnnotationEvents(session).single.timestamp, 900);

    moveSittingAnnotation(session, storedId, seconds: 300, depth: 12);
    expect(session.isDirty, isFalse);

    moveSittingAnnotation(session, storedId, seconds: 900, depth: 18);
    await save(session);
    final stored = (await repo.annotationsForDive('d1')).single;
    expect((stored.timestamp, stored.depth), (900, 18.0));
  });

  test('a stored annotation removed: its words stay in the notes as plain '
      'text and its row goes at Save', () async {
    final session = await started();
    removeSittingAnnotation(session, storedId);
    expect(session.working.notes, contains('turtle'));
    expect(annotationIdsInNotes(session.working.notes), isEmpty);
    expect(session.changedCardIds, {'notes', 'profile'});

    await save(session);
    expect(await storedIds(), isEmpty);
  });

  test(
    'notes edited to drop a link, nothing else: Save deletes that row',
    () async {
      final session = await started();
      session.set(diveNotesField, unlinkAnnotation(dive.notes, storedId));
      expect(session.changedCardIds, {'notes'});

      await save(session);
      expect(await storedIds(), isEmpty);
    },
  );

  // Link markup broken by hand (#4815) would read at Save as the
  // annotation removed, so the Notes card holds Save until it is mended.
  group('annotationLinksIntact', () {
    test('a link deleted whole beside a stored break left as it is: a '
        'removal, as always', () async {
      final stored = dive.copyWith(
        notes: '${dive.notes}\n\n[x](annotation:orphan',
      );
      final session = EditSession<Dive>(stored);
      addTearDown(() {
        if (!session.isDisposed) session.dispose();
      });
      loadDiveAnnotations(session, container.read);
      await session.settled();

      session.set(diveNotesField, 'Calm\n\n[x](annotation:orphan');
      expect(annotationLinksIntact(session), isTrue);
    });

    test('a link pasted from elsewhere, to an annotation this dive does not '
        'hold, loses nothing and is intact', () async {
      final session = await started();
      session.set(
        diveNotesField,
        '${session.working.notes}\n\n[shark](annotation:from-another-dive)',
      );
      expect(annotationLinksIntact(session), isTrue);
    });

    test('a broken link whose annotation is gone loses nothing and is '
        'intact', () async {
      final session = await started();
      session.set(
        diveNotesField,
        '${session.working.notes}\n\n[old](annotation:no-row-for-this',
      );
      expect(annotationLinksIntact(session), isTrue);
    });

    test('an id edited inside a link that still reads as one is not '
        'intact', () async {
      final session = await started();
      session.set(
        diveNotesField,
        session.working.notes.replaceFirst(storedId, storedId.substring(0, 8)),
      );
      expect(annotationLinksIntact(session), isFalse);
    });

    test('an id deleted whole, its link left empty, is not intact', () async {
      final session = await started();
      session.set(
        diveNotesField,
        session.working.notes.replaceFirst(storedId, ''),
      );
      expect(annotationLinksIntact(session), isFalse);
    });

    test('a stored break whose id changes case is a new break', () async {
      final broken = dive.copyWith(notes: '[a](annotation:ABC');
      final session = EditSession<Dive>(broken);
      addTearDown(session.dispose);
      session.set(diveNotesField, '[a](annotation:abc');
      expect(annotationLinksIntact(session), isFalse);
    });

    test('a stored break whose annotation is still held: other edits to the '
        'notes are held too, untouched notes are not', () async {
      final notes = dive.notes.substring(0, dive.notes.length - 1);
      final session = EditSession<Dive>(dive.copyWith(notes: notes));
      addTearDown(() {
        if (!session.isDisposed) session.dispose();
      });
      loadDiveAnnotations(session, container.read);
      await session.settled();
      expect(annotationLinksIntact(session), isTrue);

      session.set(diveNotesField, 'Before. $notes');
      expect(annotationLinksIntact(session), isFalse);

      // Mended, the link reads again and the notes can be saved.
      session.set(diveNotesField, 'Before. ${dive.notes}');
      expect(annotationLinksIntact(session), isTrue);
    });

    test('a link to an annotation with no row, mended from a stored break, '
        'is intact', () async {
      final broken = dive.copyWith(notes: '[a](annotation:gone');
      final session = EditSession<Dive>(broken);
      addTearDown(session.dispose);
      session.set(diveNotesField, '[a](annotation:gone)');
      expect(annotationLinksIntact(session), isTrue);
    });

    test('a sitting as opened is intact', () async {
      final session = await started();
      expect(annotationLinksIntact(session), isTrue);
    });

    test('a link that lost its closing parenthesis is not', () async {
      final session = await started();
      final notes = session.working.notes;
      session.set(diveNotesField, notes.substring(0, notes.length - 1));
      expect(annotationLinksIntact(session), isFalse);

      session.set(diveNotesField, notes);
      expect(annotationLinksIntact(session), isTrue);
    });

    test('the link deleted whole, address and all, removes the annotation '
        'as before', () async {
      final session = await started();
      session.set(diveNotesField, 'Calm');
      expect(annotationLinksIntact(session), isTrue);
    });

    test('words edited inside the link are intact', () async {
      final session = await started();
      session.set(
        diveNotesField,
        session.working.notes.replaceFirst('turtle', 'turtle buggy'),
      );
      expect(annotationLinksIntact(session), isTrue);
    });

    test('notes stored already broken do not hold Save while left so, but a '
        'second break does', () async {
      // A stored break whose annotation is gone, beside the turtle's link.
      final broken = dive.copyWith(
        notes: '${dive.notes}\n\n[x](annotation:gone',
      );
      final session = EditSession<Dive>(broken);
      addTearDown(() {
        if (!session.isDisposed) session.dispose();
      });
      loadDiveAnnotations(session, container.read);
      await session.settled();
      expect(annotationLinksIntact(session), isTrue);

      session.set(diveNotesField, '${broken.notes} more');
      expect(annotationLinksIntact(session), isTrue);

      // The turtle's link loses its closing parenthesis.
      session.set(
        diveNotesField,
        broken.notes.replaceFirst('$storedId)', storedId),
      );
      expect(annotationLinksIntact(session), isFalse);
    });

    test('a stored break mended does not excuse another link broken in the '
        'same sitting', () async {
      final broken = dive.copyWith(
        notes: '[a](annotation:old\n\n[b](annotation:other)',
      );
      final session = EditSession<Dive>(broken);
      addTearDown(session.dispose);

      // The stored break mended, and the other link's parenthesis deleted.
      session.set(
        diveNotesField,
        '[a](annotation:old)\n\n[b](annotation:other',
      );
      expect(annotationLinksIntact(session), isFalse);
    });
  });

  test('limits: the profile end, else the runtime, capped as today', () async {
    final session = await started();
    expect(annotationTimeLimits(session), (min: 0, max: 2400));

    session.set(diveRuntimeField, 1800.0);
    expect(annotationTimeLimits(session).max, 1800);

    final profiled = EditSession<Dive>(
      dive.copyWith(
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 2000, depth: 0),
        ],
      ),
    );
    addTearDown(profiled.dispose);
    expect(annotationTimeLimits(profiled).max, 2000);

    final bare = EditSession<Dive>(Dive(id: 'x', dateTime: DateTime.utc(2026)));
    addTearDown(bare.dispose);
    expect(annotationTimeLimits(bare).max, 24 * 3600);
  });

  test(
    'loads once per sitting; a read answering after Cancel sets nothing',
    () async {
      final session = EditSession<Dive>(dive);
      loadDiveAnnotations(session, container.read);
      session.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sittingAnnotations(session), isNull);
    },
  );

  test(
    'a read that failed is marked, and a retry reads the annotations',
    () async {
      final failing = _FailingOnceRepo();
      final local = ProviderContainer(
        overrides: [annotationRepositoryProvider.overrideWithValue(failing)],
      );
      addTearDown(local.dispose);
      final session = EditSession<Dive>(dive);
      addTearDown(session.dispose);
      loadDiveAnnotations(session, local.read);
      await session.settled();

      expect(sittingAnnotations(session), isNull);
      expect(annotationsLoadFailed(session), isTrue);

      await retryDiveAnnotations(session);

      expect(failing.reads, 2);
      expect(annotationsLoadFailed(session), isFalse);
      expect(sittingAnnotations(session)?.loaded.map((e) => e.id), [storedId]);
      // The held write is in place once read, so a pin placed now is saved.
      expect(placeAnnotation(session, seconds: 600, words: 'manta'), isNotNull);
    },
  );

  test(
    'a read that failed still settles the rows with the notes at Save',
    () async {
      final local = ProviderContainer(
        overrides: [
          annotationRepositoryProvider.overrideWithValue(_FailingOnceRepo()),
        ],
      );
      addTearDown(local.dispose);
      final session = EditSession<Dive>(dive);
      addTearDown(session.dispose);
      loadDiveAnnotations(session, local.read);
      await session.settled();
      expect(annotationsLoadFailed(session), isTrue);

      // The stored annotation's line is cut from the notes.
      session.set(diveNotesField, unlinkAnnotation(dive.notes, storedId));
      await save(session);

      expect(await storedIds(), isEmpty);
    },
  );
}
