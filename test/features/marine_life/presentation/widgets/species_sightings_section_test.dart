import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/marine_life/domain/entities/species_sighting_record.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_sightings_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// [count] records, newest first as the repository returns them. Record 1
/// has no site, a depth, a count of 3 and notes; the rest are plain.
List<SpeciesSightingRecord> _records(int count) => [
  for (var i = 1; i <= count; i++)
    SpeciesSightingRecord(
      sightingId: 'sg$i',
      diveId: 'd$i',
      diveNumber: 100 + i,
      diveDateTime: DateTime(2024, 1, 31 - i),
      siteId: i == 1 ? null : 's1',
      siteName: i == 1 ? null : 'Blue Hole',
      maxDepthMeters: i == 1 ? 18.0 : null,
      count: i == 1 ? 3 : 1,
      notes: i == 1 ? 'Under the ledge' : '',
    ),
];

GoRouter _router() => GoRouter(
  initialLocation: '/detail',
  routes: [
    GoRoute(
      path: '/detail',
      builder: (context, state) => const Scaffold(
        body: SingleChildScrollView(
          child: SpeciesSightingsSection(speciesId: 'sp_x'),
        ),
      ),
    ),
    GoRoute(
      path: '/dives/:diveId',
      builder: (context, state) =>
          Scaffold(body: Text('DIVE ${state.pathParameters['diveId']}')),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  List<SpeciesSightingRecord> records,
) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testAppRouter(
      router: _router(),
      locale: const Locale('en'),
      overrides: [
        ...overrides,
        speciesSightingsProvider('sp_x').overrideWith((ref) async => records),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows ten records and a Show all toggle when more exist', (
    tester,
  ) async {
    await _pump(tester, _records(12));

    expect(find.text('Sightings (12)'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(10));
    expect(find.text('Show all (12)'), findsOneWidget);
    expect(find.text('#111'), findsNothing);
  });

  testWidgets('expands to every record and offers Show fewer', (tester) async {
    await _pump(tester, _records(12));

    // Ten tiles push the toggle below the 600 px test surface; a tap on an
    // off-screen widget is silently a miss.
    final toggle = find.byKey(const ValueKey('sightings_toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(12));
    expect(find.text('Show fewer'), findsOneWidget);
    expect(find.text('#112'), findsOneWidget);
  });

  testWidgets('shows fewer than ten records without a toggle', (tester) async {
    await _pump(tester, _records(3));

    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.byKey(const ValueKey('sightings_toggle')), findsNothing);
  });

  testWidgets('renders unknown site, count, notes and depth', (tester) async {
    await _pump(tester, _records(2));

    expect(find.text('Unknown site'), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.textContaining('× 3'), findsOneWidget);
    expect(find.textContaining('Under the ledge'), findsOneWidget);
    // Same formatter and default settings as the widget, so the assertion
    // holds whichever depth unit the defaults use.
    final depth = const UnitFormatter(AppSettings()).formatDepth(18.0);
    expect(find.text(depth), findsOneWidget);
  });

  testWidgets('tapping a record opens its dive', (tester) async {
    await _pump(tester, _records(2));

    await tester.tap(find.text('Blue Hole'));
    await tester.pumpAndSettle();
    expect(find.text('DIVE d2'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no records', (tester) async {
    await _pump(tester, const []);

    expect(find.byType(ListTile), findsNothing);
    expect(find.textContaining('Sightings'), findsNothing);
  });
}
