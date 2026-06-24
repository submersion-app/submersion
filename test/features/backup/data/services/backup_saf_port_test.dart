import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/backup_saf_port.dart';

/// Exercises [MethodChannelBackupSafPort] (and, through it, the SubmersionSaf
/// facade) against a mocked `app.submersion/saf` channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.submersion/saf');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const port = MethodChannelBackupSafPort();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'writeBackup':
          return 'content://doc/new';
        case 'delete':
          return true;
        case 'exists':
          return false;
        case 'resolveTree':
          return 'Backups';
        default:
          return null;
      }
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Map args() => calls.single.arguments as Map;

  test('writeBackup forwards args and returns the document URI', () async {
    final uri = await port.writeBackup(
      treeUri: 'content://tree',
      fileName: 'b.db',
      sourcePath: '/data/x.db',
    );
    expect(uri, 'content://doc/new');
    expect(calls.single.method, 'writeBackup');
    expect(args()['treeUri'], 'content://tree');
    expect(args()['fileName'], 'b.db');
    expect(args()['sourcePath'], '/data/x.db');
  });

  test('readBackup forwards documentUri + destPath', () async {
    await port.readBackup(documentUri: 'content://doc', destPath: '/tmp/x.db');
    expect(calls.single.method, 'readBackup');
    expect(args()['documentUri'], 'content://doc');
    expect(args()['destPath'], '/tmp/x.db');
  });

  test('delete forwards documentUri and returns the result', () async {
    expect(await port.delete('content://doc'), isTrue);
    expect(calls.single.method, 'delete');
    expect(args()['documentUri'], 'content://doc');
  });

  test('exists forwards documentUri and returns the result', () async {
    expect(await port.exists('content://doc'), isFalse);
    expect(calls.single.method, 'exists');
    expect(args()['documentUri'], 'content://doc');
  });

  test('resolveTree forwards treeUri and returns the display name', () async {
    expect(await port.resolveTree('content://tree'), 'Backups');
    expect(calls.single.method, 'resolveTree');
    expect(args()['treeUri'], 'content://tree');
  });

  test('delete/exists coerce a null channel result to false', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await port.delete('content://doc'), isFalse);
    expect(await port.exists('content://doc'), isFalse);
  });
}
