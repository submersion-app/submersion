import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/outlier_suggestion_provider.dart';

/// The Profile card's outliers button watches this on every dive page
/// (issue #4527, plan 11): the detection runs again only when the profile
/// changes, not with every other change to the dive.
void main() {
  // A steady 10 m with one 45 m spike: two outliers.
  final spiked = List.generate(
    20,
    (i) => DiveProfilePoint(timestamp: i * 4, depth: i == 10 ? 45.0 : 10.0),
  );
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026),
    profile: spiked,
    notes: 'Calm',
  );

  late StateProvider<Dive?> stored;
  late ProviderContainer container;
  late int runs;

  setUp(() {
    stored = StateProvider<Dive?>((_) => dive);
    container = ProviderContainer(
      overrides: [diveProvider('d1').overrideWith((ref) => ref.watch(stored))],
    );
    addTearDown(container.dispose);
    runs = 0;
    container.listen(outlierSuggestionProvider('d1'), (_, next) {
      if (next.hasValue && !next.isLoading) runs++;
    }, fireImmediately: true);
  });

  test('a change to the dive that leaves the profile alone finds nothing '
      'again', () async {
    expect(
      await container.read(outlierSuggestionProvider('d1').future),
      hasLength(2),
    );
    final before = runs;

    container.read(stored.notifier).state = dive.copyWith(notes: 'Choppy');
    await container.read(diveProvider('d1').future);
    await Future<void>.delayed(Duration.zero);

    expect(runs, before);
  });

  // A reload reads the dive again from the database: an equal profile in a
  // new list is still the same profile.
  test('a reload bringing the same profile finds nothing again', () async {
    await container.read(outlierSuggestionProvider('d1').future);
    final before = runs;

    container.read(stored.notifier).state = dive.copyWith(
      notes: 'Choppy',
      profile: [
        for (final p in spiked)
          DiveProfilePoint(timestamp: p.timestamp, depth: p.depth),
      ],
    );
    await container.read(diveProvider('d1').future);
    await Future<void>.delayed(Duration.zero);

    expect(runs, before);
  });

  test('a new profile is checked again', () async {
    await container.read(outlierSuggestionProvider('d1').future);

    container.read(stored.notifier).state = dive.copyWith(
      profile: [
        for (final p in spiked)
          DiveProfilePoint(timestamp: p.timestamp, depth: 10),
      ],
    );
    // The new profile reaches the detection once the dive has reloaded.
    await container.read(diveProvider('d1').future);
    await Future<void>.delayed(Duration.zero);

    expect(
      await container.read(outlierSuggestionProvider('d1').future),
      isEmpty,
    );
  });
}
