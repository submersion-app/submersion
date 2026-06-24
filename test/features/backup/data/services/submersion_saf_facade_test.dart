import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_saf/submersion_saf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.submersion/saf');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('writeBackup passes args and returns the document URI', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return 'content://doc/1';
    });

    final uri = await SubmersionSaf.writeBackup(
      treeUri: 'content://tree/1',
      fileName: 'b.db',
      sourcePath: '/data/x.db',
    );

    expect(uri, 'content://doc/1');
    expect(seen!.method, 'writeBackup');
    expect((seen!.arguments as Map)['fileName'], 'b.db');
  });

  test('pickFolder maps a null channel result to null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await SubmersionSaf.pickFolder(), isNull);
  });

  test('resolveTree returns the display name', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'Backups');
    expect(await SubmersionSaf.resolveTree('content://tree/1'), 'Backups');
  });
}
