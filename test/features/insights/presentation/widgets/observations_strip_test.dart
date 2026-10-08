import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/observation_card.dart';
import 'package:submersion/features/insights/presentation/widgets/observations_strip.dart';

import 'observation_test_harness.dart';

const _key = Key('strip-under-test');

Widget _strip() => const Column(
  children: [
    ObservationsStrip(key: _key, padding: EdgeInsets.all(16)),
    Text('below'),
  ],
);

List<Override> _strip3() => [
  observationStripProvider.overrideWith(
    (ref) => AsyncData<List<Observation>>([
      gapObservation(lastDiveId: 'a'),
      gapObservation(lastDiveId: 'b'),
      categoryObservation('time-patterns'),
    ]),
  ),
];

void main() {
  testWidgets('empty and loading take no space', (tester) async {
    for (final state in <AsyncValue<List<Observation>>>[
      const AsyncData([]),
      const AsyncLoading(),
    ]) {
      await pumpObservationApp(
        tester,
        child: _strip(),
        overrides: [observationStripProvider.overrideWith((ref) => state)],
      );
      expect(tester.getSize(find.byKey(_key)), Size.zero);
      expect(find.byType(ObservationCard), findsNothing);
    }
  });

  testWidgets('three observations under a header with See all', (tester) async {
    await pumpObservationApp(tester, child: _strip(), overrides: _strip3());
    expect(find.text('Observations'), findsOneWidget);
    expect(find.byType(ObservationCard), findsNWidgets(3));
    expect(find.byKey(const Key('observations-filter-note')), findsNothing);
  });

  testWidgets('See all pushes the page on a phone', (tester) async {
    await pumpObservationApp(tester, child: _strip(), overrides: _strip3());
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('at /insights/observations'), findsOneWidget);
  });

  testWidgets('See all selects the detail pane on desktop', (tester) async {
    final router = await pumpObservationApp(
      tester,
      size: desktop,
      child: _strip(),
      overrides: _strip3(),
    );
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/insights?selected=observations');
  });

  testWidgets('an active filter shows the whole-log note', (tester) async {
    await pumpObservationApp(
      tester,
      child: _strip(),
      overrides: [
        ..._strip3(),
        insightsFilterProvider.overrideWith(
          (ref) => DiveFilterState(startDate: DateTime(2026)),
        ),
      ],
    );
    expect(find.byKey(const Key('observations-filter-note')), findsOneWidget);
  });

  testWidgets('an error shows the card with Retry', (tester) async {
    await pumpObservationApp(
      tester,
      child: _strip(),
      overrides: [
        observationsProvider.overrideWith((ref) async {
          throw StateError('boom');
        }),
      ],
    );
    expect(find.text("Couldn't load observations"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Retry reloads the inputs, where a real failure lives', (
    tester,
  ) async {
    var loads = 0;
    await pumpObservationApp(
      tester,
      child: _strip(),
      overrides: [
        observationInputsProvider.overrideWith((ref) async {
          loads++;
          throw StateError('corrupt profile blob');
        }),
        dismissedObservationKeysProvider.overrideWith(
          (ref) => Stream.value(const <String>{}),
        ),
      ],
    );
    expect(find.text("Couldn't load observations"), findsOneWidget);
    final before = loads;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(loads, greaterThan(before));
  });
}
