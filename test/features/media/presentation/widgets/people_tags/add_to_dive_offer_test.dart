import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/add_to_dive_offer.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/person_picker_sheet.dart';

import '../../../../../helpers/test_database.dart';
import 'people_tag_test_host.dart';

Buddy buddy(String id, String name) => Buddy(
  id: id,
  name: name,
  diverId: 'A',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedPeopleTagFixtures();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      'INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) '
      "VALUES ('db1', 'd1', 'bea', 'buddy', $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> offer(
    WidgetTester tester, {
    required String? diveId,
    required PersonChoice choice,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        await peopleTagHost(
          Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => offerAddToDive(
                  context,
                  ref,
                  diveId: diveId,
                  choice: choice,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
    });
    await tester.tap(find.text('go'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<List<String>> buddiesOnDive(WidgetTester tester) async {
    final rows = await tester.runAsync(
      () => db
          .customSelect(
            "SELECT buddy_id, role FROM dive_buddies WHERE dive_id = 'd1'",
          )
          .get(),
    );
    return [
      for (final r in rows!)
        '${r.read<String>('buddy_id')}:${r.read<String>('role')}',
    ];
  }

  testWidgets('offers a buddy not on the dive, and Add logs them', (
    tester,
  ) async {
    await offer(
      tester,
      diveId: 'd1',
      choice: BuddyChoice(buddy('alex', 'Alex')),
    );

    expect(find.text("Add Alex to this dive's buddies?"), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(
      await buddiesOnDive(tester),
      unorderedEquals(['bea:buddy', 'alex:buddy']),
    );
  });

  testWidgets('ignoring the offer leaves the dive alone', (tester) async {
    await offer(
      tester,
      diveId: 'd1',
      choice: BuddyChoice(buddy('alex', 'Alex')),
    );
    expect(find.text("Add Alex to this dive's buddies?"), findsOneWidget);
    expect(await buddiesOnDive(tester), ['bea:buddy']);
  });

  testWidgets('no offer for a buddy already on the dive', (tester) async {
    await offer(tester, diveId: 'd1', choice: BuddyChoice(buddy('bea', 'Bea')));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no offer for Me', (tester) async {
    await offer(tester, diveId: 'd1', choice: const MeChoice('A'));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no offer for media with no dive', (tester) async {
    await offer(
      tester,
      diveId: null,
      choice: BuddyChoice(buddy('alex', 'Alex')),
    );
    expect(find.byType(SnackBar), findsNothing);
  });
}
