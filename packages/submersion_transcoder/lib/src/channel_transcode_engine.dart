import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:submersion_transcoder/src/color_encoder.dart';
import 'package:submersion_transcoder/src/color_timeline.dart';
import 'package:submersion_transcoder/src/mp4_recording_info.dart';
import 'package:submersion_transcoder/src/transcode_engine.dart';
import 'package:submersion_transcoder/src/transcode_target.dart';
import 'package:submersion_transcoder/src/video_probe.dart';

/// Channel client for native transcoder plugins (iOS/macOS via AVFoundation,
/// Android via Media3). A thin Dart shim over the plugin's method + event
/// channels; the real work lives in the platform's native code. Degrades to
/// "unavailable" when the plugin is not registered (e.g. `flutter test`), so
/// absence is a normal state that maps onto the pipeline's upload-the-original
/// fallback.
class ChannelTranscodeEngine implements TranscodeEngine, ColorEncoder {
  ChannelTranscodeEngine({
    MethodChannel? methods,
    EventChannel? progress,
    this.progressPollInterval = const Duration(milliseconds: 250),
  }) : _methods =
           methods ?? const MethodChannel('submersion_transcoder/methods'),
       _progress =
           progress ?? const EventChannel('submersion_transcoder/progress'),
       _usesDefaultProgress = progress == null;

  final MethodChannel _methods;
  final EventChannel _progress;

  /// How often a colour encode's progress is asked for, from an engine that
  /// keeps it rather than pushing it (the Windows plugin).
  final Duration progressPollInterval;

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
  Future<List<Uint8List?>> extractFrames({
    required File source,
    required List<Duration> times,
    int maxDimension = 160,
    bool exact = false,
  }) async {
    final none = List<Uint8List?>.filled(times.length, null);
    if (times.isEmpty) return none;
    try {
      final reply = await _methods.invokeListMethod<Object?>('extractFrames', {
        'path': source.path,
        'timesMs': [for (final t in times) t.inMilliseconds],
        'maxDimension': maxDimension,
        'exact': exact,
      });
      if (reply == null) return none;
      return [
        for (var i = 0; i < times.length; i++)
          i < reply.length && reply[i] is Uint8List
              ? reply[i] as Uint8List
              : null,
      ];
    } on MissingPluginException {
      return none;
    } on PlatformException {
      return none;
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

  @override
  Future<void> encodeWithColor({
    required File source,
    required File output,
    required ColorTimeline timeline,
    ColorEncodeCancel? cancel,
    void Function(double fraction)? onProgress,
  }) async {
    if (cancel?.isCancelled ?? false) throw const TranscodeCancelledException();
    // Read here, once, for every platform: encoders do not all read the
    // location Android cameras write, and every one stamps its copy with the
    // moment it was made.
    final recording = await readMp4RecordingInfo(source);
    // A cancel during that read would reach the plugin before the encode it
    // names, and be dropped there.
    if (cancel?.isCancelled ?? false) throw const TranscodeCancelledException();
    final progressId = 'p${_seq++}';
    // Pushed and polled progress both go through here, so a fraction is
    // reported once and never goes backwards.
    var reported = -1.0;
    void report(double fraction) {
      final f = fraction.clamp(0.0, 1.0);
      if (onProgress == null || f <= reported) return;
      reported = f;
      onProgress(f);
    }

    StreamSubscription<dynamic>? sub;
    if (onProgress != null) {
      sub = _progressStream.listen((event) {
        if (event is Map && event['progressId'] == progressId) {
          report((event['fraction'] as num).toDouble());
        }
      });
    }
    var finished = false;
    // Progress is also asked for, for an engine that keeps it rather than
    // pushing it on the event channel; one that does not answer the call
    // (MissingPluginException, not implemented) is not asked again.
    Timer? poll;
    if (onProgress != null) {
      var asking = false;
      poll = Timer.periodic(progressPollInterval, (timer) async {
        if (asking || finished) return;
        asking = true;
        try {
          final f = await _methods.invokeMethod<num>('colorEncodeProgress', {
            'progressId': progressId,
          });
          if (f != null && !finished) report(f.toDouble());
        } on Object {
          timer.cancel();
        } finally {
          asking = false;
        }
      });
    }
    unawaited(
      cancel?.whenCancelled.then((_) async {
        if (finished) return;
        try {
          await _methods.invokeMethod<void>('cancelEncode', {
            'progressId': progressId,
          });
        } on Object {
          // The encode reports its own outcome; a cancel that cannot be
          // delivered (no plugin, already finished) changes nothing.
        }
      }),
    );
    try {
      await _methods.invokeMethod<void>('encodeWithColor', {
        'source': source.path,
        'output': output.path,
        'timeline': timeline.toChannel(),
        'location': recording.location,
        'progressId': progressId,
      });
      final copy = await readMp4RecordingInfo(output);
      // An encoder that turned a rotated clip's frames upright (Media
      // Foundation) leaves the copy's matrix plain; give it the source's.
      // Done before the location is added: that rewrites the moov.
      final sourceMatrix = recording.videoMatrix;
      final copyMatrix = copy.videoMatrix;
      if (sourceMatrix != null &&
          copyMatrix != null &&
          !_sameMatrix(sourceMatrix, copyMatrix) &&
          _sameMatrix(copyMatrix, _identityMatrix)) {
        await setMp4VideoMatrix(output, sourceMatrix);
      }
      // An encoder that writes no location (Media Foundation) gets it added.
      final location = recording.location;
      if (location != null && copy.location == null) {
        await addMp4Location(output, location);
      }
      final created = recording.created;
      if (created != null) await stampMp4CreationTime(output, created);
      // Polled progress can miss the end, which comes between two polls.
      report(1.0);
    } on PlatformException catch (e) {
      final detail = e.message ?? e.details?.toString() ?? e.code;
      switch (e.code) {
        case 'cancelled':
          throw const TranscodeCancelledException();
        case 'unsupported':
          throw TranscodeUnsupportedException(detail);
        default:
          throw TranscodeException('colour encode failed: $detail');
      }
    } on MissingPluginException {
      throw const TranscodeException('transcoder plugin not registered');
    } finally {
      finished = true;
      poll?.cancel();
      await sub?.cancel();
    }
  }
}

const _identityMatrix = [0x10000, 0, 0, 0, 0x10000, 0, 0, 0, 0x40000000];

bool _sameMatrix(List<int> a, List<int> b) {
  for (var i = 0; i < 9; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
