import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';

import '../../../helpers/mock_providers.dart';

/// Counts the Follow prompt's lookups and drives its change tick by hand.
class _CountingRepository implements DiveRepository {
  final ticks = StreamController<void>.broadcast();
  int lookups = 0;

  @override
  Stream<void> watchMeasuredRuntimeChanges() => ticks.stream;

  @override
  Future<Dive?> getLatestEndedDive({
    String? diverId,
    required DateTime endedAfter,
    required DateTime notAfter,
  }) async {
    lookups++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The Follow prompt's suggestion (issue #4250) rereads when a dive's end
/// can move: a dive with no runtime ends where its profile does, and a
/// profile write can leave the dive row alone.
void main() {
  test('a measured runtime change reads the suggestion again', () async {
    final repository = _CountingRepository();
    addTearDown(repository.ticks.close);
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repository),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(followSuggestionProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(followSuggestionProvider.future);
    expect(repository.lookups, 1);

    repository.ticks.add(null);
    await Future<void>.delayed(Duration.zero);
    await container.read(followSuggestionProvider.future);

    expect(repository.lookups, 2);
  });
}
