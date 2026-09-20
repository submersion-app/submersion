import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/data/channel_nl_engine.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('submersion_nl');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('maps availability strings', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'availability');
      expect(call.arguments, {'locale': 'en-US'});
      return 'unsupportedLocale';
    });
    expect(
      await ChannelNlEngine().availability('en-US'),
      NlAvailability.unsupportedLocale,
    );
  });

  test('a missing plugin is an unsupported platform, not an error', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw MissingPluginException(),
    );
    expect(
      await ChannelNlEngine().availability('en-US'),
      NlAvailability.unsupportedPlatform,
    );
  });

  test('compile returns the JSON string and maps native error codes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'compile');
      expect(call.arguments, {'sentence': 'turtles', 'locale': 'en-US'});
      return '{"schemaVersion":1,"subject":"dives"}';
    });
    expect(
      await ChannelNlEngine().compile('turtles', localeTag: 'en-US'),
      '{"schemaVersion":1,"subject":"dives"}',
    );

    messenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          throw PlatformException(code: 'context_exceeded', message: 'long'),
    );
    await expectLater(
      () => ChannelNlEngine().compile('x', localeTag: 'en-US'),
      throwsA(
        isA<NlException>().having(
          (e) => e.error,
          'error',
          NlError.contextExceeded,
        ),
      ),
    );

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'weird'),
    );
    await expectLater(
      () => ChannelNlEngine().compile('x', localeTag: 'en-US'),
      throwsA(
        isA<NlException>().having((e) => e.error, 'error', NlError.unknown),
      ),
    );
  });

  test('prepare sends the instructions and vocabulary once', () async {
    Map<Object?, Object?>? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'prepare') {
        sent = call.arguments as Map<Object?, Object?>;
      }
      return null;
    });
    await ChannelNlEngine().prepare();
    expect(sent!['instructions'], NlPrompt.instructions());
    expect((sent!['vocabulary'] as Map)['schemaVersion'], kQuerySchemaVersion);
  });
}
