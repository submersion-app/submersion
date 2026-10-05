import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/presentation/pages/insights_observations_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/observation_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../widgets/observation_test_harness.dart';

void main() {
  final five = [
    for (final id in ['a', 'b', 'c', 'd']) gapObservation(lastDiveId: id),
    categoryObservation('time-patterns'),
  ];

  testWidgets('lists every observation', (tester) async {
    await pumpObservationApp(
      tester,
      child: const InsightsObservationsPage(embedded: true),
      overrides: observationsOverride(five),
    );
    expect(find.byType(ObservationCard), findsNWidgets(5));
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Muted kinds'), findsOneWidget);
  });

  testWidgets('not embedded: its own app bar', (tester) async {
    await pumpObservationApp(
      tester,
      child: const InsightsObservationsPage(),
      overrides: observationsOverride(five),
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Observations'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty state', (tester) async {
    await pumpObservationApp(
      tester,
      child: const InsightsObservationsPage(embedded: true),
      overrides: observationsOverride(const []),
    );
    expect(find.text('Observations appear as your log grows'), findsOneWidget);
  });

  testWidgets('an error offers Retry', (tester) async {
    await pumpObservationApp(
      tester,
      child: const InsightsObservationsPage(embedded: true),
      overrides: [
        observationsProvider.overrideWith((ref) async => throw StateError('x')),
      ],
    );
    expect(find.text("Couldn't load observations"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('an active filter shows the whole-log note', (tester) async {
    await pumpObservationApp(
      tester,
      child: const InsightsObservationsPage(embedded: true),
      overrides: [
        ...observationsOverride(five),
        insightsFilterProvider.overrideWith(
          (ref) => DiveFilterState(startDate: DateTime(2026)),
        ),
      ],
    );
    expect(
      find.text(
        'Observations use your whole log, so the filter does not apply to them',
      ),
      findsOneWidget,
    );
  });

  group('muted kinds sheet', () {
    testWidgets('lists known muted kinds; Unmute keeps unknown ids', (
      tester,
    ) async {
      final settings = MockSettingsNotifier(
        const AppSettings(
          insightsMutedObservationRules: {'rmvTrend', 'fromANewerBuild'},
        ),
      );
      await pumpObservationApp(
        tester,
        settings: settings,
        child: const InsightsObservationsPage(embedded: true),
        overrides: observationsOverride(const []),
      );
      await tester.tap(find.byTooltip('Muted kinds'));
      await tester.pumpAndSettle();
      expect(find.text('RMV trend'), findsOneWidget);
      expect(find.textContaining('fromANewerBuild'), findsNothing);
      await tester.tap(find.byTooltip('Unmute'));
      await tester.pumpAndSettle();
      expect(settings.state.insightsMutedObservationRules, {'fromANewerBuild'});
      expect(find.text('No kinds are muted'), findsOneWidget);
    });

    testWidgets('says so when nothing is muted', (tester) async {
      await pumpObservationApp(
        tester,
        child: const InsightsObservationsPage(embedded: true),
        overrides: observationsOverride(const []),
      );
      await tester.tap(find.byTooltip('Muted kinds'));
      await tester.pumpAndSettle();
      expect(find.text('No kinds are muted'), findsOneWidget);
    });
  });

  testWidgets('Retry reloads the inputs', (tester) async {
    var loads = 0;
    await pumpObservationApp(
      tester,
      child: const InsightsObservationsPage(embedded: true),
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
    final before = loads;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(loads, greaterThan(before));
  });
}
