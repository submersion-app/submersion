import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/web/web_forget_device_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

/// Forget this device (issue #4121) wipes everything the browser keeps, in
/// an order that leaves no half state: sync off first, then the secrets,
/// the preferences, the open database, the storage, and a reload.
void main() {
  tearDown(SyncCoordinator.reset);

  WebForgetDeviceService service(
    List<String> log, {
    Future<void> Function()? clearSecureStorage,
    Future<void> Function()? clearPreferences,
    Future<void> Function()? closeDatabase,
    Future<void> Function()? deleteDatabase,
  }) => WebForgetDeviceService(
    disableSync: () async => log.add('disableSync'),
    clearSecureStorage:
        clearSecureStorage ?? () async => log.add('clearSecureStorage'),
    clearPreferences:
        clearPreferences ?? () async => log.add('clearPreferences'),
    closeDatabase: closeDatabase ?? () async => log.add('closeDatabase'),
    deleteDatabase: deleteDatabase ?? () async => log.add('deleteDatabase'),
    removeStorageEntry: (name) async => log.add('remove $name'),
    announce: () => log.add('announce'),
    reload: () => log.add('reload'),
  );

  test('wipes in order and reloads last', () async {
    final log = <String>[];
    await service(log).forget();
    expect(log, [
      'disableSync',
      'clearSecureStorage',
      'clearPreferences',
      'closeDatabase',
      'deleteDatabase',
      'remove submersion-sync-tmp',
      'announce',
      'reload',
    ]);
  });

  test('a sync already running finishes before anything is deleted', () async {
    final log = <String>[];
    final gate = Completer<void>();
    final sync = SyncCoordinator.run(() async {
      log.add('sync start');
      await gate.future;
      log.add('sync end');
    });
    final forget = service(log).forget();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(log, ['sync start']);
    gate.complete();
    await sync;
    await forget;
    expect(log.indexOf('sync end'), lessThan(log.indexOf('disableSync')));
    expect(log.last, 'reload');
  });

  test('a step that fails does not stop the wipe or the reload', () async {
    final log = <String>[];
    await service(
      log,
      closeDatabase: () async => throw StateError('still busy'),
    ).forget();
    expect(log, contains('deleteDatabase'));
    expect(log.last, 'reload');
  });

  for (final (step, failing) in [
    ('the credentials', 'clearSecureStorage'),
    ('the preferences', 'clearPreferences'),
  ]) {
    test('$step left behind: the rest is wiped and the other tabs told, but '
        'this tab reports it instead of reloading', () async {
      final log = <String>[];
      Future<void> fail() async => throw StateError('storage refused');
      await expectLater(
        service(
          log,
          clearSecureStorage: failing == 'clearSecureStorage' ? fail : null,
          clearPreferences: failing == 'clearPreferences' ? fail : null,
        ).forget(),
        throwsA(isA<WebForgetIncompleteException>()),
      );
      expect(log, contains('deleteDatabase'));
      expect(log, contains('remove submersion-sync-tmp'));
      expect(log, contains('announce'));
      expect(log, isNot(contains('reload')));
    });
  }

  test('a database that survives stops the wipe before the reload', () async {
    final log = <String>[];
    await expectLater(
      service(
        log,
        deleteDatabase: () async => throw StateError('still there'),
      ).forget(),
      throwsStateError,
    );
    expect(log, isNot(contains('reload')));
    expect(log, isNot(contains('announce')));
    expect(log, isNot(contains('remove submersion-sync-tmp')));
    expect(log, contains('closeDatabase'));
  });
}
