import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:submersion_transcoder/src/transcode_engine.dart';
import 'package:submersion_transcoder/src/transcode_target.dart';
import 'package:submersion_transcoder/src/video_probe.dart';

/// Channel client for native transcoder plugins (iOS/macOS via AVFoundation,
/// Android via Media3). A thin Dart shim over the plugin's method + event
/// channels; the real work lives in the platform's native code. Degrades to
/// "unavailable" when the plugin is not registered (e.g. `flutter test`), so
/// absence is a normal state that maps onto the pipeline's upload-the-original
/// fallback.
class ChannelTranscodeEngine implements TranscodeEngine {
  ChannelTranscodeEngine({MethodChannel? methods, EventChannel? progress})
    : _methods =
          methods ?? const MethodChannel('submersion_transcoder/methods'),
      _progress =
          progress ?? const EventChannel('submersion_transcoder/progress');

  final MethodChannel _methods;
  final EventChannel _progress;
  int _seq = 0;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _methods.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<VideoProbe?> probe(File source) async {
    try {
      final map = await _methods.invokeMapMethod<String, dynamic>('probe', {
        'path': source.path,
      });
      if (map == null) return null;
      return VideoProbe(
        width: map['width'] as int,
        height: map['height'] as int,
        durationMs: map['durationMs'] as int,
        overallBitrateKbps: map['overallBitrateKbps'] as int,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> transcode({
    required File source,
    required File output,
    required TranscodeTarget target,
    VideoProbe? probe,
    void Function(double fraction)? onProgress,
  }) async {
    final progressId = 'p${_seq++}';
    StreamSubscription<dynamic>? sub;
    if (onProgress != null) {
      sub = _progress.receiveBroadcastStream().listen((event) {
        if (event is Map && event['progressId'] == progressId) {
          final f = (event['fraction'] as num).toDouble();
          onProgress(f.clamp(0.0, 1.0));
        }
      });
    }
    try {
      await _methods.invokeMethod<void>('transcode', {
        'source': source.path,
        'output': output.path,
        'maxHeight': target.maxHeight,
        'videoBitrateKbps': target.videoBitrateKbps,
        'audioBitrateKbps': target.audioBitrateKbps,
        'progressId': progressId,
      });
    } on PlatformException catch (e) {
      throw TranscodeException('AVFoundation transcode failed: ${e.message}');
    } on MissingPluginException {
      throw const TranscodeException('transcoder plugin not registered');
    } finally {
      await sub?.cancel();
    }
  }
}
