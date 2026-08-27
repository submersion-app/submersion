import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

Future<void> pumpVessel(WidgetTester tester, LiveaboardDetails? details) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        liveaboardDetailsProvider(
          'trip-1',
        ).overrideWith((ref) async => details),
      ].cast(),
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TripVesselSection(tripId: 'trip-1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders every vessel detail row when all fields are set', (
    tester,
  ) async {
    final details = LiveaboardDetails(
      id: 'lad-1',
      tripId: 'trip-1',
      vesselName: 'MV Explorer',
      operatorName: 'Blue Water Divers',
      vesselType: 'Motor yacht',
      cabinType: 'Twin ensuite',
      capacity: 22,
      embarkPort: 'Sorong',
      disembarkPort: 'Sorong',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await pumpVessel(tester, details);

    expect(find.text('MV Explorer'), findsOneWidget);
    expect(find.text('Blue Water Divers'), findsOneWidget);
    expect(find.text('Motor yacht'), findsOneWidget);
    expect(find.text('Twin ensuite'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('Sorong'), findsNWidgets(2)); // embark + disembark
  });

  testWidgets('shows the vessel name even with no optional fields', (
    tester,
  ) async {
    // vesselName is the one required detail; a record with nothing else set
    // must still render more than the section heading.
    final details = LiveaboardDetails(
      id: 'lad-2',
      tripId: 'trip-1',
      vesselName: 'MV Explorer',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await pumpVessel(tester, details);

    expect(find.text('MV Explorer'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no liveaboard details', (
    tester,
  ) async {
    await pumpVessel(tester, null);
    expect(find.byType(Card), findsNothing);
  });
}
