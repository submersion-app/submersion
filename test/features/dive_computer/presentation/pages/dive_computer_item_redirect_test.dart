import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/navigation/dive_computer_location.dart';
import 'package:submersion/features/dive_computer/presentation/pages/dive_computer_item_redirect.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A dive computer's page is its Equipment item's page (issue #3676): the old
/// route forwards there, while its download child still opens the wizard.
void main() {
  final computer = DiveComputer(
    id: 'comp-1',
    name: 'Teric',
    equipmentId: 'gear-1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpAt(WidgetTester tester, String location) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (_, s) =>
              Scaffold(body: Text('ITEM ${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/dive-computers/:computerId',
          builder: (_, s) => DiveComputerItemRedirect(
            computerId: s.pathParameters['computerId']!,
          ),
          routes: [
            GoRoute(
              path: 'download',
              builder: (_, _) => const Scaffold(body: Text('DOWNLOAD')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveComputerByIdProvider(
            'comp-1',
          ).overrideWith((ref) async => computer),
          diveComputerByIdProvider('gone').overrideWith((ref) async => null),
          diveComputerByIdProvider(
            'broken',
          ).overrideWith((ref) async => throw StateError('db closed')),
          diveComputerByIdProvider('bare').overrideWith(
            (ref) async => DiveComputer(
              id: 'bare',
              name: 'Teric',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('/dive-computers/<id> lands on the item', (tester) async {
    await pumpAt(tester, '/dive-computers/comp-1');
    expect(find.text('ITEM gear-1'), findsOneWidget);
  });

  testWidgets('/dive-computers/<id>/download still opens the download '
      'wizard', (tester) async {
    await pumpAt(tester, '/dive-computers/comp-1/download');
    expect(find.text('DOWNLOAD'), findsOneWidget);
  });

  testWidgets('an unknown computer says so', (tester) async {
    await pumpAt(tester, '/dive-computers/gone');
    expect(find.textContaining('not found'), findsOneWidget);
  });

  testWidgets('a computer with no item says so instead of spinning '
      '(review)', (tester) async {
    await pumpAt(tester, '/dive-computers/bare');
    expect(find.textContaining('not found'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a lookup that fails says so instead of spinning (review)', (
    tester,
  ) async {
    await pumpAt(tester, '/dive-computers/broken');
    expect(find.textContaining('not found'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  test('diveComputerLocation prefers the item', () {
    expect(diveComputerLocation(computer), '/equipment/gear-1');
    expect(
      diveComputerLocation(
        DiveComputer(
          id: 'c2',
          name: 'x',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
      '/dive-computers/c2',
    );
  });
}
