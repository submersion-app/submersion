import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:submersion/shared/services/file_share_handler.dart';

/// A share plugin holding one launch share, whose [reset] can be made to
/// fail the way a platform channel call can.
class _LaunchSharePlugin extends ReceiveSharingIntent {
  _LaunchSharePlugin(this._initial, {this.resetFails = false});

  final List<SharedMediaFile> _initial;
  final bool resetFails;
  int resets = 0;

  @override
  Future<List<SharedMediaFile>> getInitialMedia() async => _initial;

  @override
  Stream<List<SharedMediaFile>> getMediaStream() => const Stream.empty();

  @override
  Future<dynamic> reset() async {
    resets++;
    if (resetFails) throw StateError('channel gone');
  }
}

void main() {
  late Directory dir;
  late SharedMediaFile launchShare;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final original = ReceiveSharingIntent.instance;
    addTearDown(() {
      ReceiveSharingIntent.instance = original;
      debugDefaultTargetPlatformOverride = null;
    });
    dir = Directory.systemTemp.createTempSync('launch_share_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'dive.uddf'))
      ..writeAsStringSync('<uddf/>');
    launchShare = SharedMediaFile(path: file.path, type: SharedMediaType.file);
  });

  /// Initializes a handler against [plugin] and returns the names of the
  /// files it was handed once the launch share has been processed.
  Future<List<String>> receiveLaunchShare(_LaunchSharePlugin plugin) async {
    ReceiveSharingIntent.instance = plugin;
    final received = Completer<List<String>>();
    final handler = FileShareHandler(
      onFileReceived: (Uint8List bytes, String name) async =>
          received.complete([name]),
      onError: received.completeError,
    );
    addTearDown(handler.dispose);
    handler.initialize();
    return received.future.timeout(const Duration(seconds: 5));
  }

  test('takes the launch share once, so a later app root is not handed it '
      'again', () async {
    final plugin = _LaunchSharePlugin([launchShare]);

    expect(await receiveLaunchShare(plugin), ['dive.uddf']);
    expect(plugin.resets, 1);
  });

  test('still opens the launch share when the plugin cannot reset', () async {
    final plugin = _LaunchSharePlugin([launchShare], resetFails: true);

    expect(await receiveLaunchShare(plugin), ['dive.uddf']);
    expect(plugin.resets, 1);
  });

  test(
    'leaves the plugin alone when the app was not launched by a share',
    () async {
      final plugin = _LaunchSharePlugin(const []);
      ReceiveSharingIntent.instance = plugin;
      final handler = FileShareHandler(onFileReceived: (_, _) async {});
      addTearDown(handler.dispose);

      handler.initialize();
      await pumpEventQueue();

      expect(plugin.resets, 0);
    },
  );
}
