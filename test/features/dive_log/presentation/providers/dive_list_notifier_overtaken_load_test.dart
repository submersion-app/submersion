import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_list_snapshot.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// Answers each snapshot read only when the test says so, and gives every
/// watcher of the dives tick its own stream, so that a test can tick the
/// notifier without also invalidating [divesProvider]. [DiveRepository]'s only
/// public constructor is a factory, so this implements rather than extends.
class _ScriptedRepository implements DiveRepository {
  final diveTicks = <StreamController<void>>[];
  final reads = <Completer<DiveListSnapshot>>[];

  @override
  Stream<void> watchDivesChanges() {
    final ticks = StreamController<void>.broadcast();
    diveTicks.add(ticks);
    return ticks.stream;
  }

  @override
  Stream<void> watchDiveHydrationWrites() => const Stream<void>.empty();

  @override
  Stream<void> watchTables(Set<String> tableNames) =>
      const Stream<void>.empty();

  @override
  Future<DiveListSnapshot> getDiveListSnapshot({
    String? diverId,
    DiveListSnapshot? previous,
  }) {
    final read = Completer<DiveListSnapshot>();
    reads.add(read);
    return read.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DiveListSnapshot _snapshot() => const DiveListSnapshot.empty().advancedTo(
  [(id: 'a', digest: 1)],
  hydrated: [Dive(id: 'a', dateTime: DateTime(2026))],
);

void main() {
  late _ScriptedRepository repository;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = _ScriptedRepository();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diveRepositoryProvider.overrideWithValue(repository),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
  });

  test(
    'a load a silent reload overtook still refreshes divesProvider',
    () async {
      addTearDown(container.dispose);
      container.listen(diveListNotifierProvider, (_, _) {});
      await pumpEventQueue();
      repository.reads.single.complete(_snapshot());
      await pumpEventQueue();
      container.listen(divesProvider, (_, _) {});
      await pumpEventQueue();
      repository.reads.last.complete(_snapshot());
      await pumpEventQueue();

      final reload = container
          .read(diveListNotifierProvider.notifier)
          .refresh();
      await pumpEventQueue();
      final overtaken = repository.reads.last;
      repository.diveTicks.first.add(null);
      await pumpEventQueue();
      final readsBehindTheTick = repository.reads.length;

      overtaken.complete(_snapshot());
      await reload;
      await pumpEventQueue();

      expect(repository.reads, hasLength(readsBehindTheTick + 1));
    },
  );

  test('a load that outlives its notifier touches nothing', () async {
    container.listen(diveListNotifierProvider, (_, _) {});
    await pumpEventQueue();

    container.dispose();
    repository.reads.single.complete(_snapshot());

    await expectLater(pumpEventQueue(), completes);
  });
}
