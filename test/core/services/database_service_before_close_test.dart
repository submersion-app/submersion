import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/shared_database_ports.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/test_database.dart';

void main() {
  final service = DatabaseService.instance;

  tearDown(service.resetForTesting);

  // A desktop pop-out reads the main window's database (#5078). Every close
  // (restore, storage move, demo switch, quit) closes the pop-out first.
  test('close runs before-close hooks first', () async {
    service.setTestDatabase(createTestDatabase());
    final seen = <String>[];

    service.addBeforeCloseHook(() async {
      // The database is still there when the hook runs.
      seen.add('open=${service.databaseOrNull != null}');
    });
    service.addBeforeCloseHook(() async => throw StateError('pop-out gone'));
    final remove = service.addBeforeCloseHook(() async => seen.add('removed'));
    remove();

    await service.close();

    expect(seen, ['open=true']);
    expect(service.databaseOrNull, isNull);
  });

  test('a strict close runs the hooks too', () async {
    service.setTestDatabase(createTestDatabase());
    var ran = false;
    service.addBeforeCloseHook(() async => ran = true);

    await service.close(strict: true);

    expect(ran, isTrue);
  });

  test('attachSharedDatabase installs the database', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final before = service.generation;

    service.attachSharedDatabase(db);

    expect(service.database, same(db));
    expect(service.generation, before + 1);
  });

  test('resetForTesting forgets the hooks', () async {
    var ran = false;
    service.addBeforeCloseHook(() async => ran = true);
    service.resetForTesting();
    service.setTestDatabase(createTestDatabase());

    await service.close();

    expect(ran, isFalse);
  });

  test('a hook that never finishes is given up on', () async {
    service.setTestDatabase(createTestDatabase());
    service.beforeCloseHookTimeout = const Duration(milliseconds: 50);
    service.addBeforeCloseHook(() => Completer<void>().future);

    await service.close().timeout(const Duration(seconds: 5));

    expect(service.databaseOrNull, isNull);
  });

  test('resetForTesting restores the hook limit', () async {
    service.beforeCloseHookTimeout = const Duration(milliseconds: 1);
    service.resetForTesting();
    expect(service.beforeCloseHookTimeout, const Duration(seconds: 4));
  });

  test('resetForTesting withdraws the published database', () async {
    final port = ReceivePort();
    addTearDown(port.close);
    addTearDown(
      () => IsolateNameServer.removePortNameMapping(kMainDatabasePortName),
    );
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      kMainDatabasePortName,
    );

    service.resetForTesting();

    expect(IsolateNameServer.lookupPortByName(kMainDatabasePortName), isNull);
  });
}
