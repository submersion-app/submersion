import 'dart:io';

import 'package:submersion_transcoder/src/darwin_avf_engine.dart';
import 'package:submersion_transcoder/src/linux_ffmpeg_engine.dart';
import 'package:submersion_transcoder/src/transcode_engine.dart';

/// The engine for the current platform, or null when none exists yet.
/// Apple (iOS/macOS) = AVFoundation; Linux = system ffmpeg; Android/Windows
/// arrive in later plans (B3/B4).
///
/// This factory lives in its own file so the [TranscodeEngine] interface and
/// the concrete engines it selects can stay on a one-way dependency edge
/// (engine -> interface). Wiring the factory into the interface file instead
/// would make transcode_engine.dart and the engine files import each other.
TranscodeEngine? engineForThisPlatform() {
  if (Platform.isIOS || Platform.isMacOS) return DarwinAvfEngine();
  if (Platform.isLinux) return LinuxFfmpegEngine();
  return null;
}
