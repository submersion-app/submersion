import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/test_database.dart';

/// A dive's buddies and the diver's own roles, held in a sitting (issue
/// #4527, plan 6).
void main() {
  late AppDatabase db;
  late BuddyRepository repo;
  late ProviderContainer container;
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final ana = Buddy(id: 'b1', name: 'Ana', createdAt: epoch, updatedAt: epoch);
  final ben = Buddy(id: 'b2', name: 'Ben', createdAt: epoch, updatedAt: epoch);
  final cara = Buddy(
    id: 'b3',
    name: 'Cara',
    createdAt: epoch,
    updatedAt: epoch,
  );
  final dive = Dive(id: 'd1', dateTime: epoch, diverId: 'me');

  BuddyWithRole linked(Buddy b, [String role = DiveRole.buddyId]) =>
      BuddyWithRole(buddy: b, roles: [DiveRole.synthetic(role)]);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = BuddyRepository();
    // The role list reads the diver's preferences; no role here is custom.
    container = ProviderContainer(
      overrides: [diveRoleMapProvider.overrideWith((ref) async => {})],
    );
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
      "updated_at) VALUES ('d1', 'me', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
      "VALUES ('b1', 'me', 'Ana', 0, 0), ('b2', 'me', 'Ben', 0, 0), "
      "('b3', 'me', 'Cara', 0, 0)",
    );
    await repo.setBuddiesForDive('d1', [linked(ana), linked(ben)]);
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
    startDiveSitting(session, container.read);
    await session.settled();
    return session;
  }

  Set<String> idsOf(List<BuddyWithRole> buddies) => {
    for (final b in buddies) b.buddy.id,
  };

  test(
    'buddies load as the sitting starts; untouched, Save writes none',
    () async {
      final session = await started();
      expect(idsOf(diveBuddiesList.current(session)!), {'b1', 'b2'});
      expect(session.isDirty, isFalse);
      expect(session.hasHeldChanges, isFalse);
    },
  );

  test('a buddy added and a role changed: one held change of buddies, written '
      'once', () async {
    final session = await started();
    diveBuddiesList.set(session, [
      linked(ana, 'diveGuide'),
      linked(ben),
      linked(cara),
    ]);
    expect(session.changedCardIds, {'buddies'});

    await session.runHeldWrites();
    final stored = await repo.getBuddiesForDive('d1');
    expect(idsOf(stored), {'b1', 'b2', 'b3'});
    expect(stored.firstWhere((b) => b.buddy.id == 'b1').roleIds, ['diveGuide']);
  });

  test('the same buddies in another order are no change', () async {
    final session = await started();
    diveBuddiesList.set(session, [linked(ben), linked(ana)]);
    expect(session.isDirty, isFalse);
  });

  test('a buddy linked on another device during the sitting is kept by a Save '
      'that removed a different one', () async {
    final session = await started();
    // Another device links Cara while the sitting is open.
    await repo.setBuddiesForDive('d1', [
      linked(ana),
      linked(ben),
      linked(cara),
    ]);
    diveBuddiesList.set(session, [linked(ana)]);

    await session.runHeldWrites();
    expect(idsOf(await repo.getBuddiesForDive('d1')), {'b1', 'b3'});
  });

  test('my role changed is a field of the buddies card', () {
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    session.set(diveDiverRoleIdsField, const ['instructor']);

    expect(session.changedCardIds, {'buddies'});
    expect(session.working.diverRoleIds, ['instructor']);
  });

  test('legacy link: the buddies are created at once, the link is held, and '
      'Cancel leaves them unlinked', () async {
    await repo.setBuddiesForDive('d1', const []);
    final session = await started();

    await linkLegacyBuddiesInSitting(
      session,
      read: container.read,
      newBuddyNote: 'From the old buddy text',
      plan: (_) async => const ConversionPlan(
        diveId: 'd1',
        buddyText: 'Dora',
        links: [PlannedLink(target: NewBuddyTarget('Dora'), roleId: 'buddy')],
      ),
    );

    final current = diveBuddiesList.current(session)!;
    expect(current.map((b) => b.buddy.name), ['Dora']);
    expect(session.changedCardIds, {'buddies'});
    // The buddy exists already; the dive has no link to it yet.
    final created = await db
        .customSelect("SELECT id FROM buddies WHERE name = 'Dora'")
        .get();
    expect(created, hasLength(1));
    expect(await repo.getBuddiesForDive('d1'), isEmpty);

    // Cancel.
    session.dispose();
    expect(await repo.getBuddiesForDive('d1'), isEmpty);
    expect(
      await db.customSelect("SELECT id FROM buddies WHERE name = 'Dora'").get(),
      hasLength(1),
    );
  });

  test('legacy link to an unowned buddy: claimed at Save, not before, and '
      'Cancel leaves it unowned', () async {
    await repo.setBuddiesForDive('d1', const []);
    await db.customStatement(
      'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
      "VALUES ('b4', NULL, 'Eve', 0, 0)",
    );
    Future<String?> ownerOfEve() async =>
        (await db
                .customSelect("SELECT diver_id FROM buddies WHERE id = 'b4'")
                .getSingle())
            .read<String?>('diver_id');
    Future<EditSession<Dive>> linked() async {
      final session = await started();
      await linkLegacyBuddiesInSitting(
        session,
        read: container.read,
        newBuddyNote: 'From the old buddy text',
        plan: (_) async => const ConversionPlan(
          diveId: 'd1',
          buddyText: 'Eve',
          links: [
            PlannedLink(
              target: ExistingBuddyTarget(buddyId: 'b4', name: 'Eve'),
              roleId: 'buddy',
            ),
          ],
        ),
      );
      return session;
    }

    final cancelled = await linked();
    expect(await ownerOfEve(), isNull);
    cancelled.dispose();
    expect(await ownerOfEve(), isNull);

    final saved = await linked();
    // Every write it holds is the dive's own: none reaches a site, so the
    // page does not reload the site list after this Save.
    expect(saved.heldKeys.difference(diveOwnHeldWriteKeys), isEmpty);
    await saved.runHeldWrites();
    expect(await ownerOfEve(), 'me');
    expect((await repo.getBuddiesForDive('d1')).map((b) => b.buddy.id), ['b4']);
  });
}
