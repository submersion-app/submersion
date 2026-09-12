import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/equipment/data/repositories/cylinder_gear_links.dart';

import '../../../../helpers/bound_variables.dart';
import '../../../../helpers/test_database.dart';

void main() {
  tearDown(tearDownTestDatabase);

  test('a bulk delete binds within SQLite\'s variable limit', () async {
    // Each chunk is bound twice, once per link column, so a chunk of 500
    // bound 1000 variables.
    final db = setUpLoggingTestDatabase();
    final ids = [for (var i = 0; i < 1200; i++) 'e$i'];
    final most = await maxBoundVariables(
      () => clearCylinderGearLinks(db, SyncRepository(), ids, now: 1),
    );
    expect(most, lessThanOrEqualTo(sqliteVariableLimit));
  });
}
