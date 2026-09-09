import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  test('sourceTankIndex round-trips through create and read', () async {
    await repo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 9, 8, 10),
        tanks: const [
          domain.DiveTank(
            id: 'tA',
            gasMix: domain.GasMix(o2: 21, he: 0),
            order: 0,
            sourceTankIndex: 1,
          ),
          domain.DiveTank(
            id: 'tB',
            gasMix: domain.GasMix(o2: 100, he: 0),
            order: 1,
          ),
        ],
      ),
    );

    final dive = await repo.getDiveById('d1');
    final byId = {for (final t in dive!.tanks) t.id: t};
    expect(byId['tA']!.sourceTankIndex, 1);
    expect(byId['tB']!.sourceTankIndex, isNull);
  });
}
