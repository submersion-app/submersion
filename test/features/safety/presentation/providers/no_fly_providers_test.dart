import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// Fake repository that fails if the no-fly query is ever run, so the test can
/// prove the provider short-circuits before touching the database.
class _NoQueryDiveRepository extends Fake implements DiveRepository {
  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Future<List<NoFlyDiveInput>> getNoFlyDiveInputs({
    required DateTime since,
    String? diverId,
  }) async {
    throw StateError('getNoFlyDiveInputs must not run without an active diver');
  }
}

/// Fake repository that returns a fixed set of dive inputs for the active-diver
/// happy path. Records the diverId it was queried with.
class _StubDiveRepository extends Fake implements DiveRepository {
  final List<NoFlyDiveInput> inputs;
  String? queriedDiverId;

  _StubDiveRepository(this.inputs);

  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Future<List<NoFlyDiveInput>> getNoFlyDiveInputs({
    required DateTime since,
    String? diverId,
  }) async {
    queriedDiverId = diverId;
    return inputs;
  }
}

void main() {
  test('returns null without querying dives when no diver is active', () async {
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(_NoQueryDiveRepository()),
        // MockCurrentDiverIdNotifier defaults to null (no active diver).
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);

    final status = await container.read(noFlyStatusProvider.future);
    expect(status, isNull);
  });

  test(
    'computes a restriction for the active diver from recent dives',
    () async {
      // One no-deco dive an hour ago -> single-dive category, 12 h guideline.
      final repo = _StubDiveRepository([
        NoFlyDiveInput(
          endTime: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
          hadDecoObligation: false,
        ),
      ]);
      final diverNotifier = MockCurrentDiverIdNotifier();
      diverNotifier.setCurrentDiver('diver-1');

      final container = ProviderContainer(
        overrides: [
          diveRepositoryProvider.overrideWithValue(repo),
          currentDiverIdProvider.overrideWith((ref) => diverNotifier),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(noFlyStatusProvider.future);
      expect(status, isNotNull);
      expect(status!.category, NoFlyCategory.single);
      expect(repo.queriedDiverId, 'diver-1');
    },
  );
}
