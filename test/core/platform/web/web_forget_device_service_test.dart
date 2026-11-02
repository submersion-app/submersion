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
    Future<void> Function()? closeDatabase,
  }) => WebForgetDeviceService(
    disableSync: () async => log.add('disableSync'),
    clearSecureStorage: () async => log.add('clearSecureStorage'),
    clearPreferences: () async => log.add('clearPreferences'),
    closeDatabase: closeDatabase ?? () async => log.add('closeDatabase'),
    removeStorageEntry: (name) async => log.add('remove $name'),
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
      'remove drift_db',
      'remove submersion-sync-tmp',
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
    expect(log, contains('remove drift_db'));
    expect(log.last, 'reload');
  });
}
