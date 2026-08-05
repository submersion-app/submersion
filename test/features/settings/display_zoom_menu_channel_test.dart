import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_menu_channel.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _channelName = 'app.submersion/display';
const _codec = StandardMethodCodec();

/// Drives the channel the way the macOS View menu does, and returns the reply
/// envelope so error responses can be asserted on.
Future<ByteData?> _sendMenuCall(WidgetTester tester, String method) async {
  ByteData? reply;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _channelName,
    _codec.encodeMethodCall(MethodCall(method)),
    (ByteData? response) => reply = response,
  );
  return reply;
}

Future<ProviderContainer> _pumpRegistrar(
  WidgetTester tester,
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      _channelName,
      null,
    );
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          registerDisplayZoomMenuChannel(ref);
          return const SizedBox();
        },
      ),
    ),
  );

  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('zoomIn and zoomOut step the zoom level', (tester) async {
    final container = await _pumpRegistrar(tester, {});

    await _sendMenuCall(tester, 'zoomIn');
    expect(container.read(displayZoomNotifierProvider), 1.05);

    await _sendMenuCall(tester, 'zoomOut');
    await _sendMenuCall(tester, 'zoomOut');
    expect(container.read(displayZoomNotifierProvider), 0.95);
  });

  testWidgets('actualSize resets to the default', (tester) async {
    final container = await _pumpRegistrar(tester, {'display_zoom': 0.75});

    await _sendMenuCall(tester, 'actualSize');
    expect(
      container.read(displayZoomNotifierProvider),
      DisplayZoom.defaultValue,
    );
  });

  testWidgets('an unknown method reports an error instead of no-opping', (
    tester,
  ) async {
    final container = await _pumpRegistrar(tester, {});

    // A renamed selector or a typo in the xib must not look like success.
    final reply = await _sendMenuCall(tester, 'zoomSideways');

    expect(reply, isNotNull);
    expect(
      () => _codec.decodeEnvelope(reply!),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'unimplemented'),
      ),
    );
    expect(
      container.read(displayZoomNotifierProvider),
      DisplayZoom.defaultValue,
    );
  });
}
