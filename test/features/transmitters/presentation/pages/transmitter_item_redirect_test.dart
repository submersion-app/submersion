import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_item_redirect.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A transmitter's page is its Equipment item's (issue #3676): the old edit
/// route forwards there.
void main() {
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
          path: '/transmitters/:transmitterId/edit',
          builder: (_, s) => TransmitterItemRedirect(
            transmitterId: s.pathParameters['transmitterId']!,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transmitterProvider('tx1').overrideWith(
            (ref) async => Transmitter(
              id: 'tx1',
              transmitterSerial: '4A21F',
              label: 'Tx',
              transmitterEquipmentId: 'tx-gear',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
          transmitterProvider('gone').overrideWith((ref) async => null),
          transmitterProvider(
            'broken',
          ).overrideWith((ref) async => throw StateError('db closed')),
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

  testWidgets('/transmitters/<id>/edit lands on the item', (tester) async {
    await pumpAt(tester, '/transmitters/tx1/edit');
    expect(find.text('ITEM tx-gear'), findsOneWidget);
  });

  testWidgets('an unknown transmitter says so', (tester) async {
    await pumpAt(tester, '/transmitters/gone/edit');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a lookup that fails says so instead of spinning (review)', (
    tester,
  ) async {
    await pumpAt(tester, '/transmitters/broken/edit');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
