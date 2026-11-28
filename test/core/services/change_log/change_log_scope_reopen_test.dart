import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';

import '../../../helpers/test_database.dart';
import '../../database/change_log/change_log_support.dart';

Future<void> _edit(AppDatabase db, String notes) =>
    db.customStatement("UPDATE dives SET notes = '$notes' WHERE id = 'dive'");

Future<List<ChangeLogOperationRow>> _operations(AppDatabase db) =>
    db.select(db.changeLogOperations).get();

/// A batch of Find species runs files every dive's apply under one
/// operation (issue #5127): a scope given an operation id reopens it.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await insertDiver(db, 'diver');
    await insertDive(db, 'dive', diverId: 'diver');
    await clearLog(db);
  });
  tearDown(() => db.close());

  test('a scope given an id it does not know creates that operation', () async {
    await ChangeLogScope.automatic(
      db,
      label: ChangeLogLabels.marineLifeId,
      operationId: 'batch',
      body: () => _edit(db, 'First'),
    );

    final operation = (await _operations(db)).single;
    expect(operation.id, 'batch');
    expect(operation.source, 'automatic');
    expect(operation.label, ChangeLogLabels.marineLifeId);
    expect(operation.closed, isTrue);
    expect((await logEvents(db)).single['operation_id'], 'batch');
  });

  test('a second scope with the same id joins the first operation', () async {
    await ChangeLogScope.automatic(
      db,
      label: ChangeLogLabels.marineLifeId,
      operationId: 'batch',
      body: () => _edit(db, 'First'),
    );
    final first = (await _operations(db)).single;

    await ChangeLogScope.automatic(
      db,
      label: ChangeLogLabels.marineLifeId,
      operationId: 'batch',
      body: () => _edit(db, 'Second'),
    );

    final operations = await _operations(db);
    expect(operations, hasLength(1));
    expect(operations.single.closed, isTrue);
    // Started when the batch first wrote, not when it last did.
    expect(operations.single.startedAt, first.startedAt);
    expect(operations.single.endedAt, greaterThanOrEqualTo(first.endedAt));
    final events = await logEvents(db);
    expect(events, hasLength(2));
    expect(events.map((e) => e['operation_id']).toSet(), {'batch'});
  });

  test('a write between two reopened scopes is not filed under them', () async {
    await ChangeLogScope.automatic(
      db,
      label: ChangeLogLabels.marineLifeId,
      operationId: 'batch',
      body: () => _edit(db, 'First'),
    );
    await _edit(db, 'By the diver');
    await ChangeLogScope.automatic(
      db,
      label: ChangeLogLabels.marineLifeId,
      operationId: 'batch',
      body: () => _edit(db, 'Second'),
    );

    final events = await logEvents(db);
    expect(events.map((e) => e['operation_id']).toList(), [
      'batch',
      null,
      'batch',
    ]);
  });

  test('a scope already running in the zone is joined, id or not', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.manual,
      label: 'outer',
      body: () => ChangeLogScope.automatic(
        db,
        label: ChangeLogLabels.marineLifeId,
        operationId: 'batch',
        body: () => _edit(db, 'Inside'),
      ),
    );

    final operation = (await _operations(db)).single;
    expect(operation.label, 'outer');
  });

  test('without a database the body still runs', () async {
    var ran = false;
    await ChangeLogScope.automatic(
      null,
      label: ChangeLogLabels.marineLifeId,
      operationId: 'batch',
      body: () async => ran = true,
    );
    expect(ran, isTrue);
  });
}
