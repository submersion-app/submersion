import 'dart:io';

import 'package:submersion_transcoder/src/linux_ffmpeg_engine.dart';
import 'package:submersion_transcoder/src/transcode_engine.dart';

/// The engine for the current platform, or null when none exists yet.
/// B1 ships Linux only; darwin/Android/Windows arrive in later plans.
///
/// This factory lives in its own file so the [TranscodeEngine] interface and
/// the concrete engines it selects can stay on a one-way dependency edge
/// (engine -> interface). Wiring the factory into the interface file instead
/// would make transcode_engine.dart and linux_ffmpeg_engine.dart import each
/// other.
TranscodeEngine? engineForThisPlatform() =>
    Platform.isLinux ? LinuxFfmpegEngine() : null;
