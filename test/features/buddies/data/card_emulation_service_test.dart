import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/data/services/card_emulation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.submersion/card_emulation');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'isSupported' ? true : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  });

  test('start sends the NDEF bytes over the channel', () async {
    await const ChannelCardEmulation().start(Uint8List.fromList([1, 2, 3]));
    expect(calls.single.method, 'start');
    expect(calls.single.arguments, [1, 2, 3]);
  });

  test('stop is sent', () async {
    await const ChannelCardEmulation().stop();
    expect(calls.single.method, 'stop');
  });

  test('the channel reports support', () async {
    expect(await const ChannelCardEmulation().isSupported(), isTrue);
  });

  test('an unsupported platform reports false and ignores start', () async {
    const none = UnsupportedCardEmulation();
    expect(await none.isSupported(), isFalse);
    await none.start(Uint8List(1));
    await none.stop();
    expect(calls, isEmpty);
  });
}
