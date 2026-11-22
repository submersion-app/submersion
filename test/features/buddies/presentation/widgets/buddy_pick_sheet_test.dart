import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart' show StateController;
import 'package:submersion/features/buddies/data/services/buddy_edit_save_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_routes.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_pick_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart' show getBaseOverrides;
import '../../../../helpers/test_database.dart';
import '../pages/buddy_detail_page_unlock_harness.dart';

void main() {
  Buddy buddy(String id, String name) => Buddy(
    id: id,
    name: name,
    notes: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final anna = buddy('anna', 'Anna Lindqvist');
  final sam = buddy('sam', 'Sam Okafor');
  final added = buddy('new', 'New Student');

  Future<void> pump(
    WidgetTester tester,
    List<Buddy> buddies,
    void Function(Buddy?) onPicked, {
    Widget Function(GoRouterState state)? newBuddy,
    List<Override> overrides = const [],
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    onPicked(await showBuddyPickSheet(context, ref)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/buddies/new',
          builder: (context, state) =>
              newBuddy?.call(state) ??
              Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(added),
                  child: const Text('save buddy'),
                ),
              ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allBuddiesProvider.overrideWith((ref) async => buddies),
          ...overrides,
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the diver\'s buddies and returns the one tapped', (
    tester,
  ) async {
    Buddy? picked;
    await pump(tester, [anna, sam], (b) => picked = b);

    expect(find.text('Choose a buddy'), findsOneWidget);
    expect(find.text('Anna Lindqvist'), findsOneWidget);
    await tester.tap(find.text('Sam Okafor'));
    await tester.pumpAndSettle();

    expect(picked, sam);
  });

  testWidgets('search narrows the list by name', (tester) async {
    await pump(tester, [anna, sam], (_) {});

    await tester.enterText(find.byType(TextField), 'oka');
    await tester.pumpAndSettle();

    expect(find.text('Anna Lindqvist'), findsNothing);
    expect(find.text('Sam Okafor'), findsOneWidget);
  });

  testWidgets('a search that matches nobody says so', (tester) async {
    await pump(tester, [anna], (_) {});

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No buddies found'), findsOneWidget);
  });

  testWidgets('with no buddies it says so and still offers to add one', (
    tester,
  ) async {
    await pump(tester, const [], (_) {});

    expect(find.text('No buddies yet'), findsOneWidget);
    expect(find.text('Add New Buddy'), findsOneWidget);
  });

  testWidgets('Add New Buddy returns the buddy just created', (tester) async {
    Buddy? picked;
    await pump(tester, [anna], (b) => picked = b);

    await tester.tap(find.text('Add New Buddy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save buddy'));
    await tester.pumpAndSettle();

    expect(picked, added);
  });

  testWidgets('cancelling Add New Buddy keeps the sheet open', (tester) async {
    Buddy? picked = anna;
    await pump(tester, [anna], (b) => picked = b);

    await tester.tap(find.text('Add New Buddy'));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.text('Choose a buddy'), findsOneWidget);
    expect(picked, anna);
  });

  testWidgets('says nothing about having no buddies until the list loads', (
    tester,
  ) async {
    final gate = Completer<List<Buddy>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [allBuddiesProvider.overrideWith((ref) => gate.future)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showBuddyPickSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('No buddies yet'), findsNothing);

    gate.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('No buddies yet'), findsOneWidget);
  });

  testWidgets('dismissing returns null', (tester) async {
    Buddy? picked = anna;
    await pump(tester, [anna], (b) => picked = b);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });
  // Behind the phase 3 switch Add New Buddy opens the buddy page on a new
  // buddy, which pops the buddy it created (issue #4527, plan 11).
  testWidgets('with the switch on, Add New Buddy returns the buddy created', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final base = await getBaseOverrides();
    late FakeBuddySave save;
    Buddy? picked;
    await pump(
      tester,
      [anna],
      (b) => picked = b,
      newBuddy: (state) => newBuddyPage(state.extra),
      overrides: [
        ...base.cast<Override>(),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        buddyEditSaveServiceProvider.overrideWith(
          (ref) => save = FakeBuddySave(StateController<Buddy?>(null)),
        ),
      ],
    );

    await tester.tap(find.text('Add New Buddy'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('buddy-edit-name')),
      'New Student',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(picked?.name, 'New Student');
    expect(picked?.id, save.creates.single.buddy.id);
  });
}
