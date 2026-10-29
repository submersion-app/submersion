import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/part_of_trip_field.dart';
import 'package:submersion/features/trips/presentation/widgets/part_of_trip_link.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_dives_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The trip page's side-trip pieces (issue #3658): the Dives tab tags, the
/// "Part of" link and the form's "Part of" field.
void main() {
  Trip trip(String id, String name, {String? parent}) => Trip(
    id: id,
    name: name,
    startDate: DateTime(2026, 3, 2),
    endDate: DateTime(2026, 3, 16),
    parentTripId: parent,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final indonesia = trip('p', 'Indonesia');
  final rajaAmpat = trip('s', 'Raja Ampat', parent: 'p');
  final cozumel = trip('c', 'Cozumel');

  Widget app(Widget child, List<Override> overrides) => ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ...overrides,
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('the Dives tab tags only the side-trip dives', (tester) async {
    final own = Dive(
      id: 'd1',
      diveNumber: 1,
      dateTime: DateTime.utc(2026, 3, 3),
      tripId: 'p',
    );
    final side = Dive(
      id: 'd2',
      diveNumber: 2,
      dateTime: DateTime.utc(2026, 3, 9),
      tripId: 's',
    );
    await tester.pumpWidget(
      app(const TripDivesTab(tripId: 'p'), [
        divesForTripProvider('p').overrideWith((ref) async => [side, own]),
        sideTripsProvider('p').overrideWith((ref) async => [rajaAmpat]),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Raja Ampat'), findsOneWidget);
    final tagTop = tester.getTopLeft(find.text('Raja Ampat')).dy;
    expect(tagTop, greaterThan(tester.getTopLeft(find.text('#1')).dy));
  });

  testWidgets('PartOfTripLink names the larger trip', (tester) async {
    await tester.pumpWidget(
      app(const PartOfTripLink(tripId: 's'), [
        parentTripProvider('s').overrideWith((ref) async => indonesia),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Part of Indonesia'), findsOneWidget);
  });

  testWidgets('PartOfTripLink shows nothing for a trip of its own', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const PartOfTripLink(tripId: 'p'), [
        parentTripProvider('p').overrideWith((ref) async => null),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Part of'), findsNothing);
  });

  testWidgets('the field offers only trips that may be a parent', (
    tester,
  ) async {
    String? chosen = 'unset';
    await tester.pumpWidget(
      app(
        PartOfTripField(tripId: 'x', value: null, onChanged: (v) => chosen = v),
        [
          allTripsProvider.overrideWith(
            (ref) async => [indonesia, rajaAmpat, cozumel],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part of'));
    await tester.pumpAndSettle();
    expect(find.text('Indonesia'), findsOneWidget);
    expect(find.text('Cozumel'), findsOneWidget);
    expect(find.text('Raja Ampat'), findsNothing);
    await tester.tap(find.text('Cozumel'));
    await tester.pumpAndSettle();
    expect(chosen, 'c');
  });

  testWidgets('the field shows the chosen larger trip and clears it', (
    tester,
  ) async {
    String? chosen = 'unset';
    await tester.pumpWidget(
      app(
        PartOfTripField(tripId: 's', value: 'p', onChanged: (v) => chosen = v),
        [
          allTripsProvider.overrideWith(
            (ref) async => [indonesia, rajaAmpat, cozumel],
          ),
          visibleTripProvider('p').overrideWith((ref) async => indonesia),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Indonesia'), findsOneWidget);
    await tester.tap(find.text('Indonesia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None (a trip of its own)'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
  });

  testWidgets("the field never names a trip the profile can't see", (
    tester,
  ) async {
    final secret = trip('x', 'Secret Trip');
    await tester.pumpWidget(
      app(PartOfTripField(tripId: 's', value: 'x', onChanged: (_) {}), [
        tripByIdProvider('x').overrideWith((ref) async => secret),
        visibleTripProvider('x').overrideWith((ref) async => null),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Secret Trip'), findsNothing);
  });

  testWidgets('PartOfTripLink opens the larger trip', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: PartOfTripLink(tripId: 's')),
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (_, state) => Text('TRIP ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          parentTripProvider('s').overrideWith((ref) async => indonesia),
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
    await tester.tap(find.text('Part of Indonesia'));
    await tester.pumpAndSettle();
    expect(find.text('TRIP p'), findsOneWidget);
  });
}
