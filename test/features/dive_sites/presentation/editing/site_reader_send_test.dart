import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_site_models.dart';
import 'package:submersion/core/services/shared_library/suggestion_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_reader_send.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// A profile that only reads the site's library.
class _Reader extends LibraryEditStamper {
  @override
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async => false;
}

/// Records each proposal, and proposes the changed name as the service
/// would compare it.
class _Suggestions extends Fake implements SuggestionService {
  final calls =
      <({DiveSite proposed, String note, Map<String, Object?> child})>[];

  @override
  Future<SharedSiteSuggestion?> propose({
    required DiveSite proposed,
    required String diverId,
    String note = '',
    Map<String, Object?> childFields = const {},
  }) async {
    calls.add((proposed: proposed, note: note, child: childFields));
    return SharedSiteSuggestion(
      id: 'g1',
      libraryId: 'L',
      siteId: proposed.id,
      memberId: 'm1',
      memberName: 'Me',
      note: note,
      fields: const {'name': 'x'},
      createdAt: DateTime.utc(2026),
      direction: SharedSiteSuggestion.outgoing,
    );
  }
}

/// A proposal that fails after the reader's own write (the role changed, the
/// store refused it).
class _FailingSuggestions extends Fake implements SuggestionService {
  @override
  Future<SharedSiteSuggestion?> propose({
    required DiveSite proposed,
    required String diverId,
    String note = '',
    Map<String, Object?> childFields = const {},
  }) async => throw StateError('only a reader suggests changes');
}

/// A save that fails, as a write the database refused does.
class _FailingSave extends Fake implements SiteEditSaveService {
  @override
  Future<({DiveSite before, DiveSite after})?> save({
    required String siteId,
    required DiveSite Function(DiveSite stored) apply,
    required Iterable<String> changedCardIds,
    String? actingDiverId,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    Set<String> Function()? heldLibraryFields,
    bool privateOnly = false,
  }) async => throw StateError('the write was refused');
}

/// Records whether each save was told its held writes are a change, and
/// writes nothing.
class _RecordingSave extends Fake implements SiteEditSaveService {
  final alsoWriteIsAChange = <bool>[];

  @override
  Future<({DiveSite before, DiveSite after})?> save({
    required String siteId,
    required DiveSite Function(DiveSite stored) apply,
    required Iterable<String> changedCardIds,
    String? actingDiverId,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    Set<String> Function()? heldLibraryFields,
    bool privateOnly = false,
  }) async {
    this.alsoWriteIsAChange.add(alsoWriteIsAChange);
    return null;
  }
}

/// A library reader's Send (issue #4527, phase 2, plan 5): their own
/// changes are written as one History entry, and the rest is proposed to
/// the library's owner; the site itself is untouched.
void main() {
  late SiteRepository sites;
  late SiteEditSaveService service;
  late _Suggestions suggestions;

  setUp(() async {
    final db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await insertDiver(db, 'me');
    sites = SiteRepository();
    await sites.createSite(
      const DiveSite(
        id: 's1',
        diverId: 'me',
        name: 'Lake',
        notes: 'Calm',
        sharedLibraryId: 'L',
      ),
    );
    service = SiteEditSaveService(sites, stamper: _Reader());
    suggestions = _Suggestions();
  });
  tearDown(tearDownTestDatabase);

  Future<DiveSite> stored() async => (await sites.getSiteById('s1'))!;

  Future<EditSession<DiveSite>> sitting() async =>
      EditSession<DiveSite>(await stored());

  Future<SiteReaderSent> send(
    EditSession<DiveSite> session, {
    SiteEditSaveService? save,
    String note = '',
  }) async => (await sendReaderSitting(
    session,
    service: save ?? service,
    suggestions: suggestions,
    diverId: 'me',
    note: note,
  )).outcome;

  test('notes only: saved privately, nothing proposed', () async {
    final session = await sitting()
      ..set(siteNotesField, 'Choppy');

    expect(await send(session), SiteReaderSent.savedPrivate);
    expect(suggestions.calls, isEmpty);
    expect((await stored()).notes, 'Choppy');
  });

  test('a shared field and notes: the notes are written and the field '
      'proposed, the site\'s field untouched', () async {
    final session = await sitting()
      ..set(siteNotesField, 'Choppy')
      ..set(siteNameField, 'Big Lake');

    expect(await send(session, note: 'Renamed locally'), SiteReaderSent.sent);
    final after = await stored();
    expect(after.notes, 'Choppy');
    expect(after.name, 'Lake');
    expect(suggestions.calls.single.proposed.name, 'Big Lake');
    expect(suggestions.calls.single.note, 'Renamed locally');
  });

  test('tags go to the proposal by name', () async {
    final session = await sitting();
    await siteTagsList.load(session);
    final now = DateTime.utc(2026);
    siteTagsList.set(session, [
      Tag(id: 'g1', name: 'Night', createdAt: now, updatedAt: now),
    ]);

    await send(session);

    expect(suggestions.calls.single.child['tags'], ['Night']);
  });

  // Review Focus 5: nothing is proposed after a private write that failed.
  test('a failed private write proposes nothing', () async {
    final session = await sitting()
      ..set(siteNotesField, 'Choppy')
      ..set(siteNameField, 'Big Lake');

    await expectLater(send(session, save: _FailingSave()), throwsStateError);
    expect(suggestions.calls, isEmpty);
  });

  // The reader's own write has committed: a failed proposal says so and
  // ends the Send, rather than handing back a sitting whose held writes
  // would run a second time.
  test(
    'a failed proposal after the own write is saved privately, not sent',
    () async {
      final session = await sitting()
        ..set(siteNotesField, 'Choppy')
        ..set(siteNameField, 'Big Lake');

      final outcome = (await sendReaderSitting(
        session,
        service: service,
        suggestions: _FailingSuggestions(),
        diverId: 'me',
        note: '',
      )).outcome;

      expect(outcome, SiteReaderSent.savedPrivateNotSent);
      expect((await stored()).notes, 'Choppy');
    },
  );

  // The sitting goes on with only what goes to the owner, so a second Send
  // proposes again without writing the reader's own part twice.
  test('a failed proposal leaves only what goes to the owner in the '
      'sitting', () async {
    final ran = <String>[];
    final session = await sitting()
      ..set(siteNotesField, 'Choppy')
      ..set(siteNameField, 'Big Lake')
      ..holdChange(
        'media.held',
        cardId: 'media',
        write: () async {
          ran.add('media');
        },
      )
      // As the controller's save holds it while it writes.
      ..freeze();

    await sendReaderSitting(
      session,
      service: service,
      suggestions: _FailingSuggestions(),
      diverId: 'me',
      note: '',
    );
    session.thaw();

    expect(session.changedCardIds, {siteHeaderCardId});
    expect(session.heldChangeCardIds, isEmpty);
    expect(await send(session), SiteReaderSent.sent);
    expect(ran, ['media']);
    expect(suggestions.calls.single.proposed.name, 'Big Lake');
  });

  test('a failed proposal with nothing written fails the Send', () async {
    final session = await sitting()
      ..set(siteNameField, 'Big Lake');

    await expectLater(
      sendReaderSitting(
        session,
        service: service,
        suggestions: _FailingSuggestions(),
        diverId: 'me',
        note: '',
      ),
      throwsStateError,
    );
  });

  test('held media is written, held type changes are not', () async {
    final ran = <String>[];
    final session = await sitting()
      ..holdChange(
        'media.held',
        cardId: 'media',
        write: () async {
          ran.add('media');
        },
      )
      ..holdChange(
        'site.types',
        cardId: siteHeaderCardId,
        write: () async {
          ran.add('types');
        },
      );

    await send(session);

    expect(ran, ['media']);
  });

  // Held changes that go before the record are filtered the same way.
  test('held media before the record is written, a held header change '
      'is not', () async {
    final ran = <String>[];
    final session = await sitting()
      ..holdChange(
        'media.first',
        cardId: 'media',
        beforeRecord: true,
        write: () async {
          ran.add('media');
        },
      )
      ..holdChange(
        'header.first',
        cardId: siteHeaderCardId,
        beforeRecord: true,
        write: () async {
          ran.add('header');
        },
      );

    await send(session);

    expect(ran, ['media']);
  });

  // A change of the library's cards, made while the profile could edit, is
  // neither the reader's own nor theirs to propose: the Send refuses rather
  // than drop it.
  test(
    'a held library card change refuses the Send and writes nothing',
    () async {
      final ran = <String>[];
      final session = await sitting()
        ..set(siteNotesField, 'Choppy')
        ..set(siteNameField, 'Big Lake')
        ..holdChange(
          'features.held',
          cardId: 'features',
          write: () async {
            ran.add('features');
          },
        );

      await expectLater(send(session), throwsA(isA<RecordSittingRefusal>()));
      expect(ran, isEmpty);
      expect((await stored()).notes, 'Calm');
      expect(suggestions.calls, isEmpty);
    },
  );

  // The held writes are a change of their own only for a held change of the
  // reader's cards: a notes change is the row's, and a held header change
  // is proposed, not written.
  test(
    'only a held change of the reader\'s own cards is a held change',
    () async {
      final spy = _RecordingSave();
      final notes = await sitting()
        ..set(siteNotesField, 'Choppy')
        ..holdChange(
          'site.types',
          cardId: siteHeaderCardId,
          write: () async {},
        );
      await send(notes, save: spy);
      final media = await sitting()
        ..holdChange('media.held', cardId: 'media', write: () async {});
      await send(media, save: spy);

      expect(spy.alsoWriteIsAChange, [false, true]);
    },
  );
}
