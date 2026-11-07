import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/agent_access/presentation/providers/agent_write_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');
  late List<String> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'isMinimized' ? false : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initializes the plugin before it touches the window (#4298)', () async {
    // On macOS the plugin finds the app's window only in ensureInitialized;
    // any window call before it unwraps nil in native code and the app
    // crashes, which is what an agent's first change did.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await raiseAppWindow();

    expect(calls, isNotEmpty);
    expect(calls.first, 'ensureInitialized');
    expect(calls, containsAllInOrder(['ensureInitialized', 'show', 'focus']));
  });

  test(
    'a reveal without focus shows the window and leaves focus alone',
    () async {
      // The exit guard's path: it shows the window behind its own dialog.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await revealDesktopWindow();

      expect(calls.first, 'ensureInitialized');
      expect(calls, contains('show'));
      expect(calls, isNot(contains('focus')));
    },
  );

  test('leaves the plugin alone where there is no desktop window', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await raiseAppWindow();

    expect(calls, isEmpty);
  });
}
