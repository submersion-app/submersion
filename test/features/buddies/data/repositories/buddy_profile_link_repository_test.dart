import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddies;
  late DiverRepository divers;
  late BuddyProfileLinkRepository links;
  late String eric;
  late String chris;

  Future<String> diver(String name, {String? email}) async =>
      (await divers.createDiver(
        Diver(
          id: '',
          name: name,
          email: email,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      )).id;

  Buddy buddy(String? owner, String name, {String? linked, String? email}) =>
      Buddy(
        id: '',
        diverId: owner,
        linkedDiverId: linked,
        name: name,
        email: email,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  setUp(() async {
    await setUpTestDatabase();
    buddies = BuddyRepository();
    divers = DiverRepository();
    links = BuddyProfileLinkRepository(buddies: buddies, divers: divers);
    eric = await diver('Eric', email: 'eric@example.com');
    chris = await diver('Chris', email: 'chris@example.com');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('assertLinkAllowed', () {
    test('refuses linking a buddy to its own owner', () async {
      expect(
        () => links.assertLinkAllowed(ownerDiverId: eric, linkedDiverId: eric),
        throwsA(
          isA<BuddyLinkRefused>().having(
            (e) => e.reason,
            'reason',
            BuddyLinkRefusal.self,
          ),
        ),
      );
    });

    test(
      'refuses a second buddy in the same list linking the same profile',
      () async {
        final existing = await buddies.createBuddy(
          buddy(eric, 'C', linked: chris),
        );
        expect(
          () =>
              links.assertLinkAllowed(ownerDiverId: eric, linkedDiverId: chris),
          throwsA(
            isA<BuddyLinkRefused>()
                .having((e) => e.reason, 'reason', BuddyLinkRefusal.taken)
                .having((e) => e.existingBuddy?.id, 'existing', existing.id),
          ),
        );
      },
    );

    test('allows re-saving the buddy that already holds the link', () async {
      final existing = await buddies.createBuddy(
        buddy(eric, 'C', linked: chris),
      );
      await links.assertLinkAllowed(
        ownerDiverId: eric,
        linkedDiverId: chris,
        buddyId: existing.id,
      );
    });

    test(
      'allows the same profile linked from a different owner list',
      () async {
        await buddies.createBuddy(buddy(eric, 'C', linked: chris));
        final dana = await diver('Dana');
        await links.assertLinkAllowed(ownerDiverId: dana, linkedDiverId: chris);
      },
    );

    test('an owner-less list only sees owner-less holders', () async {
      await buddies.createBuddy(buddy(eric, 'C', linked: chris));
      await links.assertLinkAllowed(ownerDiverId: null, linkedDiverId: chris);
      await buddies.createBuddy(buddy(null, 'C2', linked: chris));
      expect(
        () => links.assertLinkAllowed(ownerDiverId: null, linkedDiverId: chris),
        throwsA(isA<BuddyLinkRefused>()),
      );
    });
  });

  group('suggestProfileFor', () {
    test('matches a single profile by case-folded, trimmed name', () async {
      final hit = await links.suggestProfileFor(
        ownerDiverId: eric,
        name: '  chris ',
      );
      expect(hit?.id, chris);
    });

    test('matches by email when the name differs', () async {
      final hit = await links.suggestProfileFor(
        ownerDiverId: eric,
        name: 'C.',
        email: 'chris@example.com',
      );
      expect(hit?.id, chris);
    });

    test('never suggests the owner itself', () async {
      final hit = await links.suggestProfileFor(
        ownerDiverId: eric,
        name: 'Eric',
      );
      expect(hit, isNull);
    });

    test('returns null when two profiles match', () async {
      await diver('Chris');
      final hit = await links.suggestProfileFor(
        ownerDiverId: eric,
        name: 'Chris',
      );
      expect(hit, isNull);
    });

    test(
      'returns null when the profile is already linked in this list',
      () async {
        await buddies.createBuddy(buddy(eric, 'Chris', linked: chris));
        final hit = await links.suggestProfileFor(
          ownerDiverId: eric,
          name: 'Chris',
        );
        expect(hit, isNull);
      },
    );

    test('returns null for a blank name and no email', () async {
      final hit = await links.suggestProfileFor(ownerDiverId: eric, name: ' ');
      expect(hit, isNull);
    });
  });

  group('ensureReciprocalBuddy', () {
    test('creates a linked buddy in the owner list from the profile', () async {
      final created = await links.ensureReciprocalBuddy(
        ownerDiverId: chris,
        linkedDiverId: eric,
      );
      expect(created.diverId, chris);
      expect(created.linkedDiverId, eric);
      expect(created.name, 'Eric');
      expect(created.email, 'eric@example.com');
    });

    test(
      'adopts an unlinked buddy of the same name instead of a second one',
      () async {
        // Chris already logs dives with Eric by hand. The mirror must adopt
        // that record rather than leave Chris with two buddies named Eric.
        final existing = await buddies.createBuddy(buddy(chris, 'Eric'));

        final result = await links.ensureReciprocalBuddy(
          ownerDiverId: chris,
          linkedDiverId: eric,
        );

        expect(result.id, existing.id);
        expect(result.linkedDiverId, eric);
        expect((await buddies.getAllBuddies(diverId: chris)).length, 1);
      },
    );

    test(
      'leaves a name-match that already links another profile alone',
      () async {
        final dana = await diver('Dana');
        await buddies.createBuddy(buddy(chris, 'Eric', linked: dana));

        final result = await links.ensureReciprocalBuddy(
          ownerDiverId: chris,
          linkedDiverId: eric,
        );

        expect(result.linkedDiverId, eric);
        expect((await buddies.getAllBuddies(diverId: chris)).length, 2);
      },
    );

    test('is idempotent: a second call returns the same buddy', () async {
      final first = await links.ensureReciprocalBuddy(
        ownerDiverId: chris,
        linkedDiverId: eric,
      );
      final second = await links.ensureReciprocalBuddy(
        ownerDiverId: chris,
        linkedDiverId: eric,
      );
      expect(second.id, first.id);
      expect((await buddies.getAllBuddies(diverId: chris)).length, 1);
    });

    test('linkedBuddyFor finds an existing link and null otherwise', () async {
      expect(
        await links.linkedBuddyFor(ownerDiverId: chris, linkedDiverId: eric),
        isNull,
      );
      final created = await buddies.createBuddy(
        buddy(chris, 'E', linked: eric),
      );
      expect(
        (await links.linkedBuddyFor(
          ownerDiverId: chris,
          linkedDiverId: eric,
        ))?.id,
        created.id,
      );
    });
  });
}
