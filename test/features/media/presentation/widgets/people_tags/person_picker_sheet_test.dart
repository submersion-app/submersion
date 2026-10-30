import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/person_picker_sheet.dart';

import '../../../../../helpers/test_database.dart';
import '../../../data/repositories/species_photo_fixtures.dart';
import 'people_tag_test_host.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedPeopleTagFixtures();
    await insertTestBuddy(id: 'cal', name: 'Cal', diverId: 'A');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      'INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) '
      "VALUES ('db1', 'd1', 'cal', 'buddy', $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  /// Opens the picker for [diveId]; the chosen value lands in [result].
  Future<List<PersonChoice?>> open(WidgetTester tester, String? diveId) async {
    final result = <PersonChoice?>[];
    await tester.runAsync(() async {
      await tester.pumpWidget(
        await peopleTagHost(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result.add(
                  await showPersonPickerSheet(context, diveId: diveId),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    });
    await tester.tap(find.text('open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('lists Me, the dive buddies, then everyone else', (tester) async {
    await open(tester, 'd1');

    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(y('Me'), lessThan(y('On this dive')));
    expect(y('On this dive'), lessThan(y('Cal')));
    expect(y('Cal'), lessThan(y('Everyone else')));
    expect(y('Everyone else'), lessThan(y('Alex')));
    expect(y('Alex'), lessThan(y('Bea')));
    expect(find.text('Cal'), findsOneWidget);
  });

  testWidgets('without a dive there is no On this dive group', (tester) async {
    await open(tester, null);
    expect(find.text('On this dive'), findsNothing);
    expect(find.text('Cal'), findsOneWidget);
  });

  testWidgets('choosing Me returns the active diver', (tester) async {
    final result = await open(tester, 'd1');
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(result.single, isA<MeChoice>());
    expect((result.single! as MeChoice).diverId, 'A');
  });

  testWidgets('search narrows the list by name', (tester) async {
    await open(tester, 'd1');
    await tester.enterText(find.byType(TextField), 'be');
    await tester.pumpAndSettle();
    expect(find.text('Bea'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
    expect(find.text('Cal'), findsNothing);
  });

  testWidgets('searching for me still finds Me', (tester) async {
    await open(tester, 'd1');
    await tester.enterText(find.byType(TextField), 'me');
    await tester.pumpAndSettle();
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('New buddy creates the buddy and returns it', (tester) async {
    final result = await open(tester, 'd1');
    await tester.tap(find.text('New buddy'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Dana');
    await tester.tap(find.text('Add'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    final choice = result.single! as BuddyChoice;
    expect(choice.buddy.name, 'Dana');
    expect(choice.isNew, isTrue);
    final rows = await tester.runAsync(
      () => db
          .customSelect("SELECT diver_id FROM buddies WHERE name = 'Dana'")
          .get(),
    );
    expect(rows!.single.read<String?>('diver_id'), 'A');
  });
}
