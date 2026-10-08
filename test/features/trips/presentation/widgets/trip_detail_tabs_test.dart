import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The master-detail pane reuses the tabs for the next trip (#2845).
void main() {
  Trip trip(String id) => Trip(
    id: id,
    name: 'Trip $id',
    startDate: DateTime(2024, 1, 15),
    endDate: DateTime(2024, 1, 22),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  testWidgets('selecting another trip starts it on Overview', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shown = ValueNotifier(TripWithStats(trip: trip('a'), diveCount: 0));
    addTearDown(shown.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          for (final id in ['a', 'b'])
            divesForTripProvider(id).overrideWith((ref) async => <Dive>[]),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<TripWithStats>(
              valueListenable: shown,
              builder: (_, value, _) => TripDetailTabs(tripWithStats: value),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(Tab, 'Dives'));
    await tester.pumpAndSettle();
    TabController controller() =>
        DefaultTabController.of(tester.element(find.byType(TabBar)));
    expect(controller().index, TripDetailTab.dives.index);

    shown.value = TripWithStats(trip: trip('b'), diveCount: 0);
    await tester.pumpAndSettle();
    expect(controller().index, TripDetailTab.overview.index);
  });
}
