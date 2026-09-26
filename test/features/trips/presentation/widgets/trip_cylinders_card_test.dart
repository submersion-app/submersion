import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_cylinders_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final at = DateTime.utc(2026, 3, 9, 8);

  Trip trip({bool past = false}) {
    final start = past
        ? DateTime(2025, 3, 1)
        : DateTime.now().add(const Duration(days: 10));
    return Trip(
      id: 't1',
      name: 'Bonaire',
      startDate: start,
      endDate: start.add(const Duration(days: 6)),
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
  }

  TripCylinder cylinder(String id, String label) => TripCylinder(
    id: id,
    tripId: 't1',
    label: label,
    workingPressure: 207,
    createdAt: at,
    updatedAt: at,
  );

  List<TripCylinderState> states() => [
    foldCylinderState(
      cylinder: cylinder('c1', 'Truck 1'),
      events: [
        TripCylinderEvent(
          id: 'f1',
          tripCylinderId: 'c1',
          kind: TripCylinderEventKind.fill,
          occurredAt: at,
          bottleLabel: '14',
          pressure: 200,
          o2Percent: 32,
          createdAt: at,
          updatedAt: at,
        ),
      ],
      uses: const [],
    ),
    foldCylinderState(
      cylinder: cylinder('c2', 'Truck 2'),
      events: const [],
      uses: const [],
    ),
  ];

  Widget host(
    List<TripCylinderState> slots, {
    bool past = false,
    MockSettingsNotifier? settings,
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: TripCylindersCard(trip: trip(past: past)),
          ),
        ),
        GoRoute(
          path: '/trips/:tripId/cylinders',
          builder: (_, _) => const Scaffold(body: Text('BOARD')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => settings ?? MockSettingsNotifier(),
        ),
        tripCylinderStatesProvider('t1').overrideWith((ref) async => slots),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets('an upcoming trip with no slots offers set-up', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.text('Cylinders'), findsOneWidget);
    expect(find.byKey(const Key('cylinders-set-up')), findsOneWidget);
  });

  testWidgets('a past trip with no slots shows nothing', (tester) async {
    await tester.pumpWidget(host(const [], past: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-cylinders-card')), findsNothing);
  });

  testWidgets('a past trip with slots keeps its record', (tester) async {
    await tester.pumpWidget(host(states(), past: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-cylinders-card')), findsOneWidget);
  });

  testWidgets('summarizes the slots and shows a chip for each', (tester) async {
    await tester.pumpWidget(host(states()));
    await tester.pumpAndSettle();
    const units = UnitFormatter(AppSettings());
    expect(
      find.text('Full 1 · Partial 0 · Empty 0 · Not filled yet 1'),
      findsOneWidget,
    );
    expect(
      find.text('14 · EAN32 · ${units.formatPressure(200)}'),
      findsOneWidget,
    );
    expect(find.text('Truck 2 · -- · --'), findsOneWidget);
  });

  testWidgets('an imperial diver sees psi on the chips', (tester) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await tester.pumpWidget(host(states(), settings: imperial));
    await tester.pumpAndSettle();
    expect(find.textContaining('psi'), findsOneWidget);
  });

  testWidgets('tapping the card opens the board', (tester) async {
    await tester.pumpWidget(host(states()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-cylinders-card')));
    await tester.pumpAndSettle();
    expect(find.text('BOARD'), findsOneWidget);
  });
}
