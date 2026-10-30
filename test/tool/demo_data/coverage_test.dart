import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';
import '../../../tool/demo_data/src/checks/coverage_check.dart';
import '../../../tool/demo_data/src/seeders/demo_seeding.dart';
import 'seed_harness.dart';

/// The demo logbook fills every part of the app (issue #3708). Built here
/// from synthetic shapes, so CI checks coverage without any real data: a
/// table added to the schema fails this until a seeder fills it or the
/// exclusion list explains why not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(tearDownTestDatabase);

  test('the synthetic build fills every table that is not excluded', () async {
    final ctx = await seedContext();

    await seedAll(ctx);

    expect(await CoverageCheck.emptyTables(ctx.db), isEmpty);
  });
}
