import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide Buddy;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_card_columns.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/data/services/buddy_edit_save_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_fields.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart'
    as domain;
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../helpers/test_database.dart';

/// A buddy page's sitting is written as one History entry, and writes only
/// what it changed (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late BuddyRepository buddies;
  late BuddyEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<Buddy> stored([String id = 'b1']) async =>
      (await buddies.getBuddyById(id))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<({Buddy before, Buddy after})?> save(EditSession<Buddy> session) =>
      service.save(
        buddyId: session.stored.id,
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
      );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    buddies = BuddyRepository();
    service = BuddyEditSaveService(
      buddies,
      BuddyProfileLinkRepository(buddies: buddies, divers: DiverRepository()),
    );
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) VALUES '
      "('me', 'Me', 0, 0), ('p1', 'Profile one', 0, 0), "
      "('other', 'Other', 0, 0)",
    );
    // Alex, with the figures a received buddy card wrote.
    await db.customStatement(
      'INSERT INTO buddies (id, diver_id, name, phone, country, '
      'country_code, card_id, card_dive_count, card_diving_since, '
      'card_last_dive, card_received_at, created_at, updated_at) VALUES '
      "('b1', 'me', 'Alex', '555', 'Italy', 'IT', 'card-1', 120, 2010, "
      '1689984000000, 1700000000000, 0, 0)',
    );
    await db.customStatement(
      'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
      "VALUES ('b2', 'me', 'Sam', 0, 0)",
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('writes a phone change as one History entry', () async {
    final session = EditSession(await stored())..set(buddyPhoneField, '777');

    final result = await save(session);

    expect((await stored()).phone, '777');
    expect(result!.before.phone, '555');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:buddies:b1:contact');
  });

  // One case per column the buddy's update writes: a value changed in
  // storage during the sitting, on a field the diver did not touch,
  // survives the Save.
  final census = <String, ({String sql, bool Function(Buddy) kept})>{
    'name': (
      sql: "UPDATE buddies SET name = 'Alexander'",
      kept: (b) => b.name == 'Alexander',
    ),
    'email': (
      sql: "UPDATE buddies SET email = 'a@b.co'",
      kept: (b) => b.email == 'a@b.co',
    ),
    'phone': (
      sql: "UPDATE buddies SET phone = '999'",
      kept: (b) => b.phone == '999',
    ),
    'country': (
      sql: "UPDATE buddies SET country = 'Malta', country_code = 'MT'",
      kept: (b) => b.country == 'Malta' && b.countryCode == 'MT',
    ),
    'linked profile': (
      sql: "UPDATE buddies SET linked_diver_id = 'p1'",
      kept: (b) => b.linkedDiverId == 'p1',
    ),
    'photo': (
      sql: "UPDATE buddies SET photo = x'0102'",
      kept: (b) => b.photo != null && b.photo!.length == 2,
    ),
    'favourite': (
      sql: 'UPDATE buddies SET is_favorite = 1',
      kept: (b) => b.isFavorite,
    ),
    'rankings exclusion': (
      sql: 'UPDATE buddies SET excluded_from_rankings = 1',
      kept: (b) => b.excludedFromRankings,
    ),
    'social handle': (
      sql: "UPDATE buddies SET social_handle = '@alex'",
      kept: (b) => b.socialHandle == '@alex',
    ),
    'card dive count': (
      sql: 'UPDATE buddies SET card_dive_count = 300',
      kept: (b) => b.cardDiveCount == 300,
    ),
    'card diving since': (
      sql: 'UPDATE buddies SET card_diving_since = 2005',
      kept: (b) => b.cardDivingSince?.year == 2005,
    ),
    'card last dive': (
      sql: 'UPDATE buddies SET card_last_dive = 1649980800000',
      kept: (b) => b.cardLastDive == BuddyCardColumns.lastDive(1649980800000),
    ),
    'card received at': (
      sql: 'UPDATE buddies SET card_received_at = 1800000000000',
      kept: (b) => b.cardReceivedAt?.millisecondsSinceEpoch == 1800000000000,
    ),
    'notes': (
      sql: "UPDATE buddies SET notes = 'Newer'",
      kept: (b) => b.notes == 'Newer',
    ),
  };
  for (final MapEntry(key: column, value: change) in census.entries) {
    test('a $column changed underneath keeps its newer value', () async {
      final EditField<Buddy, String> touched = column == 'notes'
          ? buddyNameField
          : buddyNotesField;
      final session = EditSession(await stored())..set(touched, 'Edited');
      await db.customStatement('${change.sql} WHERE id = ?', ['b1']);

      await save(session);

      final after = await stored();
      expect(change.kept(after), isTrue, reason: column);
      expect(touched.read(after), 'Edited');
    });
  }

  test("a received card's details survive a save", () async {
    final session = EditSession(await stored())..set(buddyNotesField, 'Edited');

    await save(session);

    final after = await stored();
    expect(after.cardId, 'card-1');
    expect(after.cardDiveCount, 120);
    expect(after.cardDivingSince?.year, 2010);
    expect(after.cardLastDive, BuddyCardColumns.lastDive(1689984000000));
    expect(after.cardReceivedAt?.millisecondsSinceEpoch, 1700000000000);
  });

  test('a link to a free profile is written', () async {
    final session = EditSession(await stored())
      ..set(buddyLinkedDiverField, 'p1');

    await save(session);

    expect((await stored()).linkedDiverId, 'p1');
  });

  test(
    'a linked profile taken by another buddy refuses the whole save',
    () async {
      final session = EditSession(await stored())
        ..set(buddyNameField, 'Alexander')
        ..set(buddyLinkedDiverField, 'p1');
      // Another device links the profile to Sam meanwhile.
      await db.customStatement(
        "UPDATE buddies SET linked_diver_id = 'p1' WHERE id = 'b2'",
      );
      await changeLog.settleAll();
      await db.customStatement('DELETE FROM change_log_operations');

      final refusal = await save(
        session,
      ).then<Object?>((_) => null, onError: (Object error) => error);

      expect(refusal, isA<RecordSittingRefusal>());
      final l = AppLocalizationsEn();
      expect(
        (refusal! as RecordSittingRefusal).message(l),
        l.buddies_linkedProfile_refusedTaken('Sam'),
      );
      final after = await stored();
      expect(after.name, 'Alex');
      expect(after.linkedDiverId, isNull);
      expect(await operations(), isEmpty);
    },
  );

  test('linking the diver themselves is refused', () async {
    final session = EditSession(await stored())
      ..set(buddyLinkedDiverField, 'me');

    await expectLater(save(session), throwsA(isA<RecordSittingRefusal>()));
    expect((await stored()).linkedDiverId, isNull);
  });

  test('a link the buddy already holds is not checked again', () async {
    await db.customStatement(
      "UPDATE buddies SET linked_diver_id = 'p1' WHERE id = 'b1'",
    );
    final session = EditSession(await stored())..set(buddyPhoneField, '1');

    await save(session);

    expect((await stored()).linkedDiverId, 'p1');
  });

  test('the country code follows a changed country', () async {
    final session = EditSession(await stored())
      ..set(buddyCountryField, 'France');

    await save(session);

    final after = await stored();
    expect(after.country, 'France');
    expect(after.countryCode, 'FR');
  });

  test('clearing the photo clears its path', () async {
    await buddies.updateBuddy(
      (await stored()).copyWith(
        photo: Uint8List.fromList([1, 2]),
        photoPath: '/p.jpg',
      ),
    );
    final session = EditSession(await stored())..set(buddyPhotoField, null);

    await save(session);

    final after = await stored();
    expect(after.photo, isNull);
    expect(after.photoPath, isNull);
  });

  test('unchanged returns null and writes nothing', () async {
    expect(await save(EditSession(await stored())), isNull);
    expect(await operations(), isEmpty);
  });

  /// A new buddy's sitting (issue #4527, phase 3, plan 11).
  group('create', () {
    Buddy fresh({String id = 'n1', String? linkedDiverId}) => Buddy(
      id: id,
      diverId: 'me',
      name: 'Kai',
      email: 'kai@example.com',
      linkedDiverId: linkedDiverId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('creates the buddy with its id, as one History entry', () async {
      final created = await service.create(
        buddy: fresh(),
        changedCardIds: const ['header', 'contact'],
      );

      expect(created.id, 'n1');
      expect((await stored('n1')).email, 'kai@example.com');
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['source'], 'manual');
      expect(ops.single['label'], 'record_edit:buddies:n1:contact,header');
    });

    test('certifications held in the sitting are created for it', () async {
      await service.create(
        buddy: fresh(),
        changedCardIds: const ['certifications'],
        alsoWrite: () => CertificationRepository().createCertification(
          domain.Certification(
            id: '',
            buddyId: 'n1',
            name: 'Open Water',
            agency: 'padi',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          notify: false,
        ),
      );

      final certs = await CertificationRepository().getCertificationsByBuddy(
        'n1',
      );
      expect(certs.single.name, 'Open Water');
      expect(await operations(), hasLength(1));
    });

    test('a held write that throws leaves nothing', () async {
      await expectLater(
        service.create(
          buddy: fresh(),
          changedCardIds: const ['header'],
          alsoWrite: () async => throw StateError('refused'),
        ),
        throwsStateError,
      );

      expect(await buddies.getBuddyById('n1'), isNull);
      expect(await operations(), isEmpty);
    });

    test('an empty id or one already stored is refused', () async {
      await expectLater(
        service.create(
          buddy: fresh(id: ''),
          changedCardIds: const [],
        ),
        throwsStateError,
      );
      await expectLater(
        service.create(
          buddy: fresh(id: 'b1'),
          changedCardIds: const [],
        ),
        throwsStateError,
      );

      expect((await stored()).name, 'Alex');
      expect(await operations(), isEmpty);
    });

    test(
      'a profile linked to another buddy is refused, nothing written',
      () async {
        await db.customStatement(
          "UPDATE buddies SET linked_diver_id = 'p1' WHERE id = 'b2'",
        );
        await changeLog.settleAll();
        await db.customStatement('DELETE FROM change_log_operations');

        await expectLater(
          service.create(
            buddy: fresh(linkedDiverId: 'p1'),
            changedCardIds: const ['contact'],
          ),
          throwsA(isA<RecordSittingRefusal>()),
        );

        expect(await buddies.getBuddyById('n1'), isNull);
        expect(await operations(), isEmpty);
      },
    );
  });
}
