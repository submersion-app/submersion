import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/marine_life/domain/entities/species_sighting_record.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_sightings_timeline.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

SpeciesSightingRecord _record(String dive, DateTime at) =>
    SpeciesSightingRecord(
      sightingId: 's_$dive',
      diveId: dive,
      diveDateTime: at,
      count: 1,
      notes: '',
    );

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<SpeciesSightingRecord> records,
  ) async {
    final base = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              Scaffold(body: SpeciesSightingsTimeline(records: records)),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) =>
              Scaffold(body: Text('DIVE ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(testAppRouter(router: router, overrides: base));
    await tester.pumpAndSettle();
  }

  testWidgets('a dot per dive and tap opens the dive', (tester) async {
    await pump(tester, [
      _record('d2', DateTime.utc(2026, 5, 7)),
      _record('d1', DateTime.utc(2024, 1, 10)),
    ]);
    expect(find.byKey(const ValueKey('timeline_dot_d1')), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline_dot_d2')), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('timeline_dot_d1')));
    await tester.pumpAndSettle();
    expect(find.text('DIVE d1'), findsOneWidget);
  });

  testWidgets('a single year still draws a usable axis', (tester) async {
    await pump(tester, [_record('d1', DateTime.utc(2025, 6, 1))]);
    expect(find.byKey(const ValueKey('timeline_dot_d1')), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no records draws nothing', (tester) async {
    await pump(tester, const []);
    expect(find.byKey(const ValueKey('species_timeline')), findsNothing);
  });
}
