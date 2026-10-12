import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

void main() {
  tearDown(SyncCoordinator.reset);

  test('bodies run one at a time in order', () async {
    final log = <String>[];
    final first = SyncCoordinator.run(() async {
      log.add('a-start');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      log.add('a-end');
    });
    final second = SyncCoordinator.run(() async {
      log.add('b');
    });
    expect(SyncCoordinator.busy, isTrue);
    await Future.wait([first, second]);
    expect(log, ['a-start', 'a-end', 'b']);
    expect(SyncCoordinator.busy, isFalse);
  });

  test('a throwing body releases the gate', () async {
    await expectLater(
      SyncCoordinator.run(() async => throw StateError('x')),
      throwsStateError,
    );
    expect(await SyncCoordinator.run(() async => 1), 1);
    expect(SyncCoordinator.busy, isFalse);
  });

  test('the result of the body comes back', () async {
    expect(await SyncCoordinator.run(() async => 'ok'), 'ok');
  });
}
