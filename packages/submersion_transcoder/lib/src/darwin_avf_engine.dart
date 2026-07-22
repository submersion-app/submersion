import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:submersion_transcoder/src/transcode_engine.dart';
import 'package:submersion_transcoder/src/transcode_target.dart';
import 'package:submersion_transcoder/src/video_probe.dart';

/// AVFoundation engine (iOS + macOS). A thin Dart client over the plugin's
/// channels; the real work is in Swift. Degrades to "unavailable" when the
/// plugin is not registered (e.g. `flutter test`), so absence is a normal
/// state that maps onto the pipeline's upload-the-original fallback.
class DarwinAvfEngine implements TranscodeEngine {
  DarwinAvfEngine({MethodChannel? methods, EventChannel? progress})
    : _methods =
          methods ?? const MethodChannel('submersion_transcoder/methods'),
      _progress =
          progress ?? const EventChannel('submersion_transcoder/progress'),
      _usesDefaultProgress = progress == null;

  final MethodChannel _methods;
  final EventChannel _progress;

  // True when no EventChannel was injected, i.e. we're on the default
  // production channel. Tests that inject their own channel get an isolated,
  // per-instance stream instead of the shared static one.
  final bool _usesDefaultProgress;

  // Static so progressIds are unique across ALL engine instances in this
  // isolate -- an instance-local counter would emit p0, p1, ... per instance
  // and collide on the shared progress EventChannel when two engines run
  // concurrently, misattributing progress events.
  static int _seq = 0;

  // One broadcast stream over the DEFAULT progress channel, shared by every
  // engine instance in this isolate. receiveBroadcastStream() triggers a
  // native onListen each time it's first listened to, and the Swift side keeps
  // a single progressSink -- so a per-instance stream would let a second
  // engine's onListen overwrite the first engine's sink and starve its
  // progress. One shared stream = exactly one native onListen; per-call
  // listeners filter by progressId.
  static Stream<dynamic>? _sharedDefaultProgressStream;

  // The default channel resolves to the shared static stream (one onListen for
  // the whole isolate); an injected test channel gets its own stream so tests
  // stay isolated from each other and from production.
  late final Stream<dynamic> _progressStream = _usesDefaultProgress
      ? (_sharedDefaultProgressStream ??= _progress.receiveBroadcastStream())
      : _progress.receiveBroadcastStream();

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
      sub = _progressStream.listen((event) {
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
      // message can be null; fall back to details/code so the failure always
      // carries something identifying rather than "... failed: null".
      final detail = e.message ?? e.details?.toString() ?? e.code;
      throw TranscodeException('AVFoundation transcode failed: $detail');
    } on MissingPluginException {
      throw const TranscodeException('transcoder plugin not registered');
    } finally {
      await sub?.cancel();
    }
  }
}
