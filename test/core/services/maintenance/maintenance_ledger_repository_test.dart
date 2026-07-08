import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/maintenance/maintenance_ledger_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late MaintenanceLedgerRepository ledger;

  setUp(() async {
    await setUpTestDatabase();
    ledger = MaintenanceLedgerRepository(DatabaseService.instance.database);
  });
  tearDown(tearDownTestDatabase);

  test('records and counts processed entities per task', () async {
    expect(await ledger.countProcessed('task-a'), 0);

    await ledger.markProcessed('task-a', ['e1', 'e2']);
    expect(await ledger.countProcessed('task-a'), 2);
    expect(await ledger.processedEntityIds('task-a'), {'e1', 'e2'});
  });

  test('is idempotent on (taskName, entityId)', () async {
    await ledger.markProcessed('task-a', ['e1']);
    await ledger.markProcessed('task-a', ['e1']); // no throw, no duplicate
    expect(await ledger.countProcessed('task-a'), 1);
  });

  test('task namespaces are independent', () async {
    await ledger.markProcessed('task-a', ['e1']);
    await ledger.markProcessed('task-b', ['e1', 'e2']);
    expect(await ledger.countProcessed('task-a'), 1);
    expect(await ledger.countProcessed('task-b'), 2);
    expect(await ledger.processedEntityIds('task-a'), {'e1'});
  });

  test('markProcessed with an empty id list is a no-op', () async {
    await ledger.markProcessed('task-a', const []);
    expect(await ledger.countProcessed('task-a'), 0);
  });
}
