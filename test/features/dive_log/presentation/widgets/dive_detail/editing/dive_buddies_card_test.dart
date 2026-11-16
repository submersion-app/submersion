import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_buddies_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The Buddies card of the dive page, edited in place (issue #4527,
/// plan 6).
void main() {
  late AppDatabase db;
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final ana = Buddy(id: 'b1', name: 'Ana', createdAt: epoch, updatedAt: epoch);
  final cara = Buddy(
    id: 'b3',
    name: 'Cara',
    createdAt: epoch,
    updatedAt: epoch,
  );
  final dive = Dive(id: 'd1', dateTime: epoch, diverId: 'me');
  final roles = [
    for (final (i, id) in DiveRole.builtInIds.indexed)
      DiveRole(
        id: id,
        name: id,
        isBuiltIn: true,
        sortOrder: i,
        createdAt: epoch,
        updatedAt: epoch,
      ),
  ];

  BuddyWithRole linked(Buddy b) =>
      BuddyWithRole(buddy: b, roles: [DiveRole.synthetic(DiveRole.buddyId)]);

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Ana', 0, 0), ('b3', 'Cara', 0, 0)",
    );
    await BuddyRepository().setBuddiesForDive('d1', [linked(ana)]);
  });
  tearDown(tearDownTestDatabase);

  Future<RecordEditController<Dive>> pump(
    WidgetTester tester,
    Dive d, {
    bool open = true,
    bool unlocked = true,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = RecordEditController<Dive>(
      onSave: (_) async {},
      onStart: (session) => diveBuddiesList.load(session),
    );
    addTearDown(controller.dispose);
    if (unlocked) controller.unlock(d);
    if (open) controller.openCard(DiveDetailSectionId.buddies.name);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          allDiveRolesProvider.overrideWith((ref) async => roles),
          allBuddiesProvider.overrideWith((ref) async => [ana, cara]),
          diveRoleMapProvider.overrideWith(
            (ref) async => {for (final r in roles) r.id: r},
          ),
          diveOwnerProvider.overrideWith((ref, id) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => Column(
                    children: [
                      if (open && unlocked)
                        DiveBuddiesCardEditor(session: controller.session!)
                      else
                        DiveBuddiesSection(
                          dive: controller.session?.working ?? d,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  BuddyPicker picker(WidgetTester tester) =>
      tester.widget<BuddyPicker>(find.byType(BuddyPicker));

  test('the Buddies card is always on the page, like Notes', () {
    final card = diveEditCards[DiveDetailSectionId.buddies]!;
    expect(card.isEmpty(dive), isFalse);
    expect(card.isEmptyInSitting, isNull);
  });

  testWidgets('opening and closing leaves the sitting clean', (tester) async {
    final c = await pump(tester, dive);
    expect(picker(tester).selectedBuddies.map((b) => b.buddy.id), ['b1']);
    c.closeCard(DiveDetailSectionId.buddies.name);
    await tester.pumpAndSettle();
    expect(c.session!.isDirty, isFalse);
  });

  testWidgets('a buddy picked reaches the sitting, and the read card lists '
      'them after Done', (tester) async {
    final c = await pump(tester, dive);
    picker(tester).onChanged([linked(ana), linked(cara)]);
    await tester.pumpAndSettle();
    expect(c.session!.changedCardIds, {'buddies'});
    expect(picker(tester).selectedBuddies, hasLength(2));

    c.closeCard(DiveDetailSectionId.buddies.name);
    await tester.pumpWidget(const SizedBox.shrink());
    // The read card in the sitting shows the sitting's list.
    final session = c.session!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          diveRoleMapProvider.overrideWith((ref) async => {}),
          diveOwnerProvider.overrideWith((ref, id) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordEditScope<Dive>(
              controller: c,
              child: DiveBuddiesSection(dive: session.working),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cara'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('my role from the Me chip is a field of the sitting', (
    tester,
  ) async {
    final c = await pump(tester, dive);
    expect(picker(tester).onDiverRoleChanged, isNotNull);
    picker(tester).onDiverRoleChanged!(['instructor']);
    await tester.pumpAndSettle();

    expect(c.session!.valueOf(diveDiverRoleIdsField), ['instructor']);
    expect(c.session!.changedCardIds, {'buddies'});
  });

  testWidgets('legacy buddy text: the Link is hidden on the read card, and '
      'offered in the open card', (tester) async {
    await BuddyRepository().setBuddiesForDive('d1', const []);
    final legacy = dive.copyWith(buddy: 'Dora');

    await pump(tester, legacy, open: false, unlocked: false);
    expect(find.text('Dora'), findsOneWidget);
    // It keeps its room, so the card does not grow on unlock.
    expect(find.text('Link to buddy records').hitTestable(), findsNothing);

    await pump(tester, legacy);
    expect(find.text('Link to buddy records').hitTestable(), findsOneWidget);
  });
}
