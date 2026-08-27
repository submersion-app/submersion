import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Future<void> _insertDiver() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    await _insertDiver();
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('allDiveRolesProvider returns built-ins plus the current diver\'s '
      'custom roles', () async {
    final repo = container.read(diveRoleRepositoryProvider);
    await repo.createDiveRole(name: 'Hekkensluiter', diverId: 'diver-1');

    final roles = await container.read(allDiveRolesProvider.future);
    expect(roles.length, 10);
    expect(roles.first.id, DiveRole.buddyId);
    expect(roles.last.name, 'Hekkensluiter');
  });

  test('diveRoleMapProvider indexes roles by id', () async {
    final map = await container.read(diveRoleMapProvider.future);
    expect(map.length, 9);
    expect(map[DiveRole.rearGuardId]!.name, 'Rear Guard');
  });

  test('notifier addDiveRoleByName, renameDiveRole, deleteDiveRole, and '
      'isDiveRoleInUse round-trip', () async {
    final notifier = container.read(diveRoleListNotifierProvider.notifier);

    final created = await notifier.addDiveRoleByName('Hekkensluiter');
    expect(created.name, 'Hekkensluiter');
    expect(notifier.state.value, isNotNull);
    expect(notifier.state.value!.map((r) => r.id), contains(created.id));

    await notifier.renameDiveRole(created.id, 'Sweep');
    expect(
      notifier.state.value!.singleWhere((r) => r.id == created.id).name,
      'Sweep',
    );

    expect(await notifier.isDiveRoleInUse(created.id), isFalse);

    await notifier.deleteDiveRole(created.id);
    expect(notifier.state.value!.map((r) => r.id), isNot(contains(created.id)));
  });

  test('notifier flips to loading and reloads when the current diver '
      'changes', () async {
    final sub = container.listen(
      diveRoleListNotifierProvider,
      (previous, next) {},
    );
    addTearDown(sub.close);
    final notifier = container.read(diveRoleListNotifierProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(notifier.state.value, isNotNull);

    // Mutating the mock notifier's state rebuilds the autoDispose provider
    // (it watches currentDiverIdProvider), replacing the notifier.
    await diverIdNotifier.setCurrentDiver('diver-2');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // The rebuilt notifier reloaded; built-ins are still listed.
    final rebuilt = container.read(diveRoleListNotifierProvider.notifier);
    expect(identical(rebuilt, notifier), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(rebuilt.state.value, isNotNull);
    expect(rebuilt.state.value!.length, greaterThanOrEqualTo(9));
  });

  test('notifier silently reloads when the dive_roles table changes '
      'outside the notifier (e.g. a sync write)', () async {
    // Keep the autoDispose notifier alive for the whole test.
    final sub = container.listen(
      diveRoleListNotifierProvider,
      (previous, next) {},
    );
    addTearDown(sub.close);
    final notifier = container.read(diveRoleListNotifierProvider.notifier);
    // Wait for the initial load.
    await container.read(allDiveRolesProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(notifier.state.value, isNotNull);

    // Write through the repository directly, bypassing the notifier, the
    // way a sync apply would.
    final repo = container.read(diveRoleRepositoryProvider);
    await repo.createDiveRole(name: 'Hekkensluiter', diverId: 'diver-1');

    // The tableUpdates subscription reloads without a loading flash.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(notifier.state.value!.map((r) => r.name), contains('Hekkensluiter'));
  });
}
