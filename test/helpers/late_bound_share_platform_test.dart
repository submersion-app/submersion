import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'late_bound_share_platform.dart';

class _RecordingSharePlatform extends SharePlatform {
  final calls = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharePlatform original;

  setUp(() => original = SharePlatform.instance);
  tearDown(() => SharePlatform.instance = original);

  test('the harness pins the forwarder before any test runs', () {
    expect(SharePlatform.instance, isA<LateBoundSharePlatform>());
  });

  test('a share reaches whichever fake is installed at the time', () async {
    final first = _RecordingSharePlatform();
    final second = _RecordingSharePlatform();

    SharePlatform.instance = first;
    await SharePlus.instance.share(ShareParams(text: 'one'));
    SharePlatform.instance = second;
    await SharePlus.instance.share(ShareParams(text: 'two'));

    expect(first.calls.map((c) => c.text), ['one']);
    expect(second.calls.map((c) => c.text), ['two']);
  });

  test('with no fake installed a share goes to the plugin channel', () async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final methods = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await SharePlus.instance.share(ShareParams(text: 'three'));

    expect(methods, ['share']);
  });

  test('pinning twice keeps the first forwarder', () {
    final pinned = SharePlatform.instance;

    pinLateBoundSharePlatform();

    expect(SharePlatform.instance, same(pinned));
  });
}
