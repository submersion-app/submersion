import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_list_sections.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The dive list's trip group header and the dive detail page name a side
/// trip's larger trip (issue #3658).
void main() {
  String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  Trip trip(String id, String name, {String? parent}) => Trip(
    id: id,
    name: name,
    startDate: DateTime(2026, 3, 8),
    endDate: DateTime(2026, 3, 11),
    parentTripId: parent,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final indonesia = trip('p', 'Indonesia');
  final rajaAmpat = trip('s', 'Raja Ampat', parent: 'p');

  TripSection section(String tripId, String name) => TripSection(
    tripId: tripId,
    tripName: name,
    startDate: DateTime(2026, 3, 8),
    endDate: DateTime(2026, 3, 11),
    entries: [
      DiveListEntry(
        dive: DiveSummary(
          id: 'd1',
          dateTime: DateTime(2026, 3, 8),
          sortTimestamp: 0,
          tripId: tripId,
          tripName: name,
        ),
        flatIndex: 0,
      ),
    ],
    collapsed: false,
    totalCount: 1,
  );

  Future<void> pumpHeader(
    WidgetTester tester,
    TripSection value,
    Trip? parent,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          parentTripProvider(value.tripId).overrideWith((ref) async => parent),
        ],
        child: TripGroupHeader(
          section: value,
          onToggle: () {},
          onOpenTrip: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("a side trip's group header names its larger trip", (
    tester,
  ) async {
    await pumpHeader(tester, section('s', 'Raja Ampat'), indonesia);
    expect(find.textContaining('Part of Indonesia'), findsOneWidget);
  });

  testWidgets('a trip of its own says nothing more', (tester) async {
    await pumpHeader(tester, section('p', 'Indonesia'), null);
    expect(find.textContaining('Part of'), findsNothing);
  });

  testWidgets('dive detail names the larger trip under the trip row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(tester.view.reset);
    final dive = Dive(
      id: 'dive-1',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 9),
      tripId: 's',
      trip: rajaAmpat,
    );
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(
          path: '/test',
          builder: (context, state) => DiveDetailPage(diveId: dive.id),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Raja Ampat'), findsOneWidget);
    expect(find.text('Part of Indonesia'), findsOneWidget);
  });
}
