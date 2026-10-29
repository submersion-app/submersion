import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Records the saved trip without the list notifier's own reloads.
class _RecordingTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _RecordingTripListNotifier() : super(const AsyncValue.data([]));

  final updated = <Trip>[];

  @override
  Future<void> updateTrip(Trip trip) async => updated.add(trip);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The trip form's "Part of" field (issue #3658): set on a trip of its own,
/// kept and saved, and hidden on a trip that already has side trips.
void main() {
  late String indonesiaId;
  late String cozumelId;

  Trip trip(String name, {String? parentTripId}) => Trip(
    id: '',
    name: name,
    startDate: DateTime(2026, 3, 2),
    endDate: DateTime(2026, 3, 16),
    parentTripId: parentTripId,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    await setUpTestDatabase();
    final repository = TripRepository();
    indonesiaId = (await repository.createTrip(trip('Indonesia'))).id;
    cozumelId = (await repository.createTrip(trip('Cozumel'))).id;
  });
  tearDown(tearDownTestDatabase);

  Future<_RecordingTripListNotifier> pumpEdit(
    WidgetTester tester,
    String tripId,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final notifier = _RecordingTripListNotifier();
    final router = GoRouter(
      initialLocation: '/trips/$tripId/edit',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (_, _) => const Scaffold(body: Text('LIST')),
          routes: [
            GoRoute(
              path: ':id/edit',
              builder: (_, s) => TripEditPage(tripId: s.pathParameters['id']),
            ),
          ],
        ),
      ],
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) => notifier),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('choosing a larger trip saves it', (tester) async {
    final notifier = await pumpEdit(tester, cozumelId);
    await tester.tap(find.text('Part of'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indonesia').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    expect(notifier.updated.single.parentTripId, indonesiaId);
  });

  testWidgets('a trip with side trips cannot become one', (tester) async {
    await tester.runAsync(
      () => TripRepository().createTrip(
        trip('Raja Ampat', parentTripId: indonesiaId),
      ),
    );
    await pumpEdit(tester, indonesiaId);
    expect(find.text('Part of'), findsNothing);
  });
}
