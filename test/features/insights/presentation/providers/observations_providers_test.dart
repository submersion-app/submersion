import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/observation_inputs_loader.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

final _now = DateTime.utc(2026, 10, 5, 12);

ObservationDive _dive(String id, DateTime date) =>
    ObservationDive(id: id, date: date);

/// August leads 2023 and 2024 (busiest month), and the last dive is long
/// ago (dive gap).
final _inputs = ObservationInputs(
  now: _now,
  dives: [
    for (final y in [2023, 2024]) ...[
      _dive('$y-jan', DateTime.utc(y, 1, 5)),
      for (var d = 0; d < 4; d++) _dive('$y-aug-$d', DateTime.utc(y, 8, 2 + d)),
    ],
  ],
);

class _CountingLoader extends ObservationInputsLoader {
  int calls = 0;
  String? lastDiverId;
  @override
  Future<ObservationInputs> load({
    String? diverId,
    Diver? diver,
    required DateTime now,
  }) async {
    calls++;
    lastDiverId = diverId;
    return _inputs;
  }
}

void main() {
  group('observationsProvider', () {
    ProviderContainer container({Set<String> dismissed = const {}}) {
      final c = ProviderContainer(
        overrides: [
          observationInputsProvider.overrideWith((ref) async => _inputs),
          dismissedObservationKeysProvider.overrideWith(
            (ref) => Stream.value(dismissed),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(c.dispose);
      // Riverpod 3 pauses a provider nobody listens to, so its stream
      // dependency would never deliver.
      c.listen(observationsProvider, (_, _) {});
      return c;
    }

    test('runs the rules and drops dismissed keys', () async {
      final all = await container().read(observationsProvider.future);
      expect(
        all.map((o) => o.ruleId),
        containsAll([
          ObservationRuleId.diveGap,
          ObservationRuleId.busiestMonth,
        ]),
      );
      final c = container(dismissed: {'busiestMonth:8'});
      final kept = await c.read(observationsProvider.future);
      expect(
        kept.map((o) => o.ruleId),
        isNot(contains(ObservationRuleId.busiestMonth)),
      );
      expect(kept.map((o) => o.ruleId), contains(ObservationRuleId.diveGap));
    });

    test('a muted rule drops out, and the strip follows', () async {
      final c = container(dismissed: {'busiestMonth:8'});
      await c.read(observationsProvider.future);
      await c
          .read(settingsProvider.notifier)
          .setObservationRuleMuted(ObservationRuleId.diveGap, true);
      expect(await c.read(observationsProvider.future), isEmpty);
      expect(c.read(observationStripProvider).value, isEmpty);
    });
  });

  test('no current diver: no dismissed keys and nothing throws', () async {
    final c = ProviderContainer(
      overrides: [currentDiverProvider.overrideWith((ref) async => null)],
    );
    addTearDown(c.dispose);
    c.listen(dismissedObservationKeysProvider, (_, _) {});
    expect(await c.read(dismissedObservationKeysProvider.future), isEmpty);
  });

  test('the inputs ignore the Insights view filter', () async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final loader = _CountingLoader();
    final c = ProviderContainer(
      overrides: [
        observationInputsLoaderProvider.overrideWithValue(loader),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        currentDiverProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    c.listen(observationInputsProvider, (_, _) {});
    await c.read(observationInputsProvider.future);
    c.read(insightsFilterProvider.notifier).state = DiveFilterState(
      startDate: DateTime(2026),
    );
    await c.read(observationInputsProvider.future);
    expect(loader.calls, 1);
  });

  test('the dives are the resolved diver\'s, not the raw selection', () async {
    // No selection yet (or a stale one): the current diver falls back to the
    // default diver, whose prior experience and dismissals are used, so the
    // dives must be that diver's too rather than every diver's.
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final loader = _CountingLoader();
    final c = ProviderContainer(
      overrides: [
        observationInputsLoaderProvider.overrideWithValue(loader),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        currentDiverProvider.overrideWith(
          (ref) async => Diver(
            id: 'default-diver',
            name: 'D',
            createdAt: DateTime.utc(2020),
            updatedAt: DateTime.utc(2020),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(observationInputsProvider, (_, _) {});
    await c.read(observationInputsProvider.future);
    expect(loader.lastDiverId, 'default-diver');
  });

  test('a dismissal arriving on the stream drops the observation', () async {
    final dismissed = StreamController<Set<String>>();
    addTearDown(dismissed.close);
    final c = ProviderContainer(
      overrides: [
        observationInputsProvider.overrideWith((ref) async => _inputs),
        dismissedObservationKeysProvider.overrideWith(
          (ref) => dismissed.stream,
        ),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(c.dispose);
    c.listen(observationsProvider, (_, _) {});
    dismissed.add(const {});
    final before = await c.read(observationsProvider.future);
    expect(
      before.map((o) => o.ruleId),
      contains(ObservationRuleId.busiestMonth),
    );
    dismissed.add(const {'busiestMonth:8'});
    await Future<void>.delayed(Duration.zero);
    final after = await c.read(observationsProvider.future);
    expect(
      after.map((o) => o.ruleId),
      isNot(contains(ObservationRuleId.busiestMonth)),
    );
  });
}
