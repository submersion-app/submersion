import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_pick_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
    void Function(Buddy?) onPicked,
  ) async {
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
          builder: (context, state) => Scaffold(
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
        overrides: [allBuddiesProvider.overrideWith((ref) async => buddies)],
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

  testWidgets('dismissing returns null', (tester) async {
    Buddy? picked = anna;
    await pump(tester, [anna], (b) => picked = b);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });
}
