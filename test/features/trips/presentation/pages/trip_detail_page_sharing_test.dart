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
    bool allowed = true,
    bool hidden = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final notifier = _RecordingTripListNotifier(allowed: allowed);
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
          profileHidesRepositoryProvider.overrideWithValue(
            _FakeHides(hidden: hidden),
          ),
        ],
        // The page pops through go_router after a remove, so it sits one
        // route above a home page, as it does in the app.
        child: MaterialApp.router(
          locale: const Locale('en'),
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
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(notifier.unhidden, ['shared-trip']);
  });

  testWidgets('a trip already hidden here offers Unhide, not Remove (#2679)', (
    tester,
  ) async {
    final notifier = await pump(tester, active: 'd2', hidden: true);
    expect(
      find.text('Shared by Alice · Hidden from your profile'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Remove from my profile'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Show in my profile'));
    await tester.pumpAndSettle();

    expect(notifier.unhidden, ['shared-trip']);
    expect(notifier.hidden, isEmpty);
    expect(find.text('home'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a refused remove stays on the page and says nothing', (
    tester,
  ) async {
    final notifier = await pump(tester, active: 'd2', allowed: false);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from my profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(notifier.hidden, ['shared-trip']);
    expect(find.text('Removed from your profile'), findsNothing);
    expect(find.text('Shared by Alice'), findsOneWidget);
  });

  testWidgets('an owner whose trip changed hands meanwhile is refused', (
    tester,
  ) async {
    final notifier = await pump(tester, active: 'd1', allowed: false);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(notifier.deleted, ['shared-trip']);
    expect(find.text('Only its owner can delete this trip'), findsOneWidget);
    expect(find.text('home'), findsNothing);
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
  _FakeHides({this.hidden = false});

  /// Whether the active profile has already hidden the item.
  final bool hidden;

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Future<bool> isHidden(SharedItemKind kind, String id, String diverId) async =>
      hidden;

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
  _RecordingTripListNotifier({this.allowed = true})
    : super(const AsyncValue.data([]));

  /// What the repository answers: false when it refuses the action.
  final bool allowed;
  final hidden = <String>[];
  final deleted = <String>[];
  final unhidden = <String>[];

  @override
  Future<bool> hideTrip(String id) async {
    hidden.add(id);
    return allowed;
  }

  @override
  Future<bool> deleteTrip(String id) async {
    deleted.add(id);
    return allowed;
  }

  @override
  Future<void> unhideTrip(String id) async => unhidden.add(id);

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
