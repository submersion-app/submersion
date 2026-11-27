import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/shared_database_ports.dart';

class _TinyDb extends GeneratedDatabase {
  _TinyDb(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

void main() {
  test("a second client sees the first client's table updates", () async {
    final dir = Directory.systemTemp.createTempSync('shared_ports');
    addTearDown(() => dir.deleteSync(recursive: true));
    const name = 'test.shared_ports.updates';
    addTearDown(() => unpublishDatabase(name));

    final background = await BackgroundDatabaseConnection.open(
      p.join(dir.path, 'app.db'),
    );
    final first = _TinyDb(background.connection);
    addTearDown(() async {
      await first.close();
      await background.awaitWorkerShutdown(
        timeout: const Duration(seconds: 10),
        killIfStuck: true,
      );
    });
    await first.customStatement('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    publishDatabase(name, background);

    final connection = await connectToPublishedDatabase(name);
    expect(connection, isNotNull);
    final second = _TinyDb(connection!);
    addTearDown(
      () =>
          second.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );

    final update = second
        .tableUpdates(const TableUpdateQuery.onTableName('t'))
        .first;
    await first.customStatement('INSERT INTO t DEFAULT VALUES');
    first.notifyUpdates({const TableUpdate('t')});

    await update.timeout(const Duration(seconds: 5));
    final count = await second
        .customSelect('SELECT count(*) AS c FROM t')
        .getSingle();
    expect(count.read<int>('c'), 1);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('connect returns null when nothing is published', () async {
    expect(
      await connectToPublishedDatabase('test.shared_ports.nothing_here'),
      isNull,
    );
  });
}
