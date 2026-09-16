import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';

import '../../../../helpers/test_database.dart';

/// The equipment tag providers refresh on their own when a link changes,
/// including a change made outside any notifier (a sync or an import).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_equipment) VALUES ('t1', 'Travel kit', 0, 0, 1)",
    );
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  Future<T> pollUntil<T>(
    Future<T> Function() read,
    bool Function(T) settled,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    var value = await read();
    while (!settled(value) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      value = await read();
    }
    return value;
  }

  test('tagsForEquipmentProvider follows a link written elsewhere', () async {
    final c = makeContainer();
    final sub = c.listen(tagsForEquipmentProvider('e1'), (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(tagsForEquipmentProvider('e1').future), isEmpty);

    await EquipmentTagRepository().replaceTags('e1', ['t1']);

    final tags = await pollUntil(
      () => c.read(tagsForEquipmentProvider('e1').future),
      (v) => v.isNotEmpty,
    );
    expect(tags.map((t) => t.name), ['Travel kit']);
  });

  test('tagsByEquipmentProvider follows a link written elsewhere', () async {
    final c = makeContainer();
    final sub = c.listen(tagsByEquipmentProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(tagsByEquipmentProvider.future), isEmpty);

    await EquipmentTagRepository().addTags(['e1'], ['t1']);

    final byItem = await pollUntil(
      () => c.read(tagsByEquipmentProvider.future),
      (v) => v.isNotEmpty,
    );
    expect(byItem['e1']!.single.id, 't1');
  });
}
