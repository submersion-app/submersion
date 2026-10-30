import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/data/repositories/dive_gear_usage_sql.dart';

import '../../../../helpers/bound_variables.dart';
import '../../../../helpers/test_database.dart';

void main() {
  tearDown(tearDownTestDatabase);

  test('a large batch binds within SQLite\'s variable limit', () async {
    // Each chunk is bound once per branch of the gear usage union.
    final db = setUpLoggingTestDatabase();
    final ids = [for (var i = 0; i < 1200; i++) 'd$i'];
    final most = await maxBoundVariables(() => gearUsageForDives(db, ids));
    expect(most, lessThanOrEqualTo(sqliteVariableLimit));
  });
}
