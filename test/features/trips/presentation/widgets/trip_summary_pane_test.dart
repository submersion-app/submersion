import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/summary_pane_view.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_pane.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_scene.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/summary/summary_pane_switcher.dart';

import '../../../../helpers/mock_providers.dart';
import 'trip_summary_scene_facts_test.dart' show sceneTrip;

class _StubTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _StubTripListNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pumpPane(
    WidgetTester tester, {
    AsyncValue<List<TripWithStats>>? trips,
    AppSettings settings = const AppSettings(),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    final router = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (_, _) => const Scaffold(body: TripSummaryPane()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          tripListNotifierProvider.overrideWith(
            (ref) => _StubTripListNotifier(
              trips ??
                  AsyncValue.data([
                    sceneTrip('b', 'Bali', DateTime(2025, 5, 1)),
                  ]),
            ),
          ),
        ].cast(),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows the scene by default', (tester) async {
    await pumpPane(tester);

    expect(find.byType(TripSummaryScene), findsOneWidget);
    expect(find.byType(TripSummaryWidget), findsNothing);
  });

  testWidgets('shows the details when the setting says details', (
    tester,
  ) async {
    await pumpPane(
      tester,
      settings: const AppSettings(summaryPaneView: SummaryPaneView.details),
    );

    expect(find.byType(TripSummaryWidget), findsOneWidget);
    expect(find.byType(TripSummaryScene), findsNothing);
  });

  testWidgets('an empty list shows the details and keeps the toggle', (
    tester,
  ) async {
    await pumpPane(tester, trips: const AsyncValue.data([]));

    expect(find.byType(TripSummaryWidget), findsOneWidget);
    expect(find.byType(SummaryPaneToggle), findsOneWidget);
  });

  testWidgets('a loading list shows the scene, not the details', (
    tester,
  ) async {
    await pumpPane(tester, trips: const AsyncValue.loading());

    expect(find.byType(TripSummaryScene), findsOneWidget);
    expect(find.byType(TripSummaryWidget), findsNothing);
  });
}
