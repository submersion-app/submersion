import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A shared trip's page offers Delete to its owner and "Remove from my
/// profile" to everyone else (issue #2594).
void main() {
  final trip = Trip(
    id: 'shared-trip',
    name: 'Salt Pier Getaway',
    startDate: DateTime(2024, 1, 15),
    endDate: DateTime(2024, 1, 22),
    diverId: 'd1',
    isShared: true,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
  final divers = [
    for (final (id, name) in [('d1', 'Alice'), ('d2', 'Bob')])
      Diver(
        id: id,
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
  ];

  Future<_RecordingTripListNotifier> pump(
    WidgetTester tester, {
    required String active,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final notifier = _RecordingTripListNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripWithStatsProvider(trip.id).overrideWith(
            (ref) async =>
                TripWithStats(trip: trip, diveCount: 2, totalRuntime: 3600),
          ),
          diveIdsForTripProvider(
            trip.id,
          ).overrideWith((ref) async => <String>[]),
          tripListNotifierProvider.overrideWith((ref) => notifier),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith((_) async => active),
          profileHidesRepositoryProvider.overrideWithValue(_FakeHides()),
        ],
        // The page pops through go_router after a remove, so it sits one
        // route above a home page, as it does in the app.
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/trip',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('home')),
                routes: [
                  GoRoute(
                    path: 'trip',
                    builder: (_, _) => TripDetailPage(tripId: trip.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('another profile sees Shared by and removes it from itself', (
    tester,
  ) async {
    final notifier = await pump(tester, active: 'd2');
    expect(find.text('Shared by Alice'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Remove from my profile'));
    await tester.pumpAndSettle();

    expect(
      find.text("Remove 'Salt Pier Getaway' from your profile?"),
      findsOneWidget,
    );
    expect(find.textContaining('2 of your dives stay linked'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(notifier.hidden, ['shared-trip']);
    expect(notifier.deleted, isEmpty);
    expect(find.text('Removed from your profile'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('the owner deletes it, warned about other profiles\' dives', (
    tester,
  ) async {
    await pump(tester, active: 'd1');
    expect(find.textContaining('Shared by'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Remove from my profile'), findsNothing);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete shared trip?'), findsOneWidget);
    expect(
      find.textContaining('5 dives in other profiles will lose this trip.'),
      findsOneWidget,
    );
  });
}

class _FakeHides extends Fake implements ProfileHidesRepository {
  @override
  Future<({int mine, int others})> diveLinkCounts(
    SharedItemKind kind,
    String id,
    String? diverId,
  ) async => (mine: 2, others: 5);
}

class _RecordingTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _RecordingTripListNotifier() : super(const AsyncValue.data([]));

  final hidden = <String>[];
  final deleted = <String>[];

  @override
  Future<bool> hideTrip(String id) async {
    hidden.add(id);
    return true;
  }

  @override
  Future<bool> deleteTrip(String id) async {
    deleted.add(id);
    return true;
  }

  @override
  Future<void> unhideTrip(String id) async {}

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
