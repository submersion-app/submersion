import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';

import '../../../helpers/test_database.dart';

void main() {
  late ServiceKindRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = ServiceKindRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('getAllKinds returns the 9 built-ins', () async {
    final kinds = await repo.getAllKinds();
    expect(kinds.length, 9);
    expect(kinds.every((k) => k.isBuiltIn), isTrue);
    final hydro = kinds.firstWhere((k) => k.id == 'hydro');
    expect(hydro.applicableTypes, [EquipmentType.tank]);
    expect(hydro.defaultIntervalDays, 1825);
  });

  test('custom kind CRUD; built-ins are protected', () async {
    final custom = await repo.createKind(
      ServiceKind(
        id: '',
        name: 'Scrubber repack',
        applicableTypes: const [EquipmentType.other],
        defaultIntervalHours: 5.0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    expect(custom.id, isNotEmpty);
    expect(custom.isBuiltIn, isFalse);

    await repo.updateKind(custom.copyWith(defaultIntervalHours: 6.0));
    final reloaded = await repo.getKindById(custom.id);
    expect(reloaded!.defaultIntervalHours, 6.0);

    await repo.deleteKind(custom.id);
    expect(await repo.getKindById(custom.id), isNull);

    final hydro = await repo.getKindById('hydro');
    expect(() => repo.deleteKind('hydro'), throwsStateError);
    expect(() => repo.updateKind(hydro!.copyWith(name: 'x')), throwsStateError);
  });
}
