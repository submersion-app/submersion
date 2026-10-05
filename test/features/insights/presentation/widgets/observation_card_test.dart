import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/observation_card.dart';

import 'observation_test_harness.dart';

void main() {
  testWidgets('shows the sentence', (tester) async {
    await pumpObservationApp(
      tester,
      child: ObservationCard(observation: gapObservation()),
    );
    expect(find.text('Your last dive was 120 days ago'), findsOneWidget);
  });

  testWidgets('a dive target opens the dive', (tester) async {
    await pumpObservationApp(
      tester,
      child: ObservationCard(
        observation: gapObservation(target: const DiveTarget('dive-9')),
      ),
    );
    await tester.tap(find.text('Your last dive was 120 days ago'));
    await tester.pumpAndSettle();
    expect(find.text('at /dives/dive-9'), findsOneWidget);
  });

  testWidgets('a category target pushes on a phone', (tester) async {
    await pumpObservationApp(
      tester,
      child: ObservationCard(observation: categoryObservation('gas')),
    );
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('at /insights/gas'), findsOneWidget);
  });

  testWidgets('a category target selects the detail pane on desktop', (
    tester,
  ) async {
    final router = await pumpObservationApp(
      tester,
      size: desktop,
      child: ObservationCard(observation: categoryObservation('gas')),
    );
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/insights?selected=gas');
  });

  testWidgets('dismiss writes, then Undo restores', (tester) async {
    final fake = FakeDismissals();
    await pumpObservationApp(
      tester,
      diver: testDiver,
      overrides: [
        observationDismissalsRepositoryProvider.overrideWithValue(fake),
      ],
      child: ObservationCard(observation: gapObservation()),
    );
    await tester.tap(find.byTooltip('Observation actions'));
    await tester.pumpAndSettle();
    expect(find.text("Don't show this kind"), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['dismiss diver-1 diveGap dive-9']);
    expect(find.text('Observation dismissed'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'undismiss diver-1 diveGap dive-9');
  });

  testWidgets('no current diver: the menu offers no Dismiss', (tester) async {
    await pumpObservationApp(
      tester,
      child: ObservationCard(observation: gapObservation()),
    );
    await tester.tap(find.byTooltip('Observation actions'));
    await tester.pumpAndSettle();
    expect(find.text('Dismiss'), findsNothing);
    expect(find.text("Don't show this kind"), findsOneWidget);
  });

  testWidgets('a failed dismissal says so', (tester) async {
    await pumpObservationApp(
      tester,
      diver: testDiver,
      overrides: [
        observationDismissalsRepositoryProvider.overrideWithValue(
          FakeDismissals(fail: true),
        ),
      ],
      child: ObservationCard(observation: gapObservation()),
    );
    await tester.tap(find.byTooltip('Observation actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't dismiss the observation"), findsOneWidget);
  });

  testWidgets('mute hides the kind, and Undo unmutes', (tester) async {
    final settings = mutableSettings();
    await pumpObservationApp(
      tester,
      settings: settings,
      child: ObservationCard(observation: gapObservation()),
    );
    await tester.tap(find.byTooltip('Observation actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't show this kind"));
    await tester.pumpAndSettle();
    expect(settings.state.insightsMutedObservationRules, {'diveGap'});
    expect(find.text('Observations of this kind are hidden'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(settings.state.insightsMutedObservationRules, isEmpty);
  });
}
