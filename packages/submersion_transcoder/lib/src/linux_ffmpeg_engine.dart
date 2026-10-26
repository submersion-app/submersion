import 'dart:io';
import 'dart:typed_data';

import 'package:submersion_transcoder/src/process_runner.dart';
import 'package:submersion_transcoder/src/transcode_engine.dart';
import 'package:submersion_transcoder/src/transcode_target.dart';
import 'package:submersion_transcoder/src/video_probe.dart';

/// System-ffmpeg engine (spec section 10, Linux): shells out to ffmpeg and
/// ffprobe found on PATH. Zero vendored binaries; absence means unavailable
/// and the caller uploads originals.
class LinuxFfmpegEngine implements TranscodeEngine {
  LinuxFfmpegEngine({TranscoderProcessRunner? runner})
    : _runner = runner ?? SystemProcessRunner();

  final TranscoderProcessRunner _runner;

  @override
  Future<bool> isAvailable() async {
    final ffmpeg = await _runner.run('ffmpeg', const ['-version']);
    if (ffmpeg.exitCode != 0) return false;
    final ffprobe = await _runner.run('ffprobe', const ['-version']);
    return ffprobe.exitCode == 0;
  }

  @override
  Future<VideoProbe?> probe(File source) async {
    final result = await _runner.run('ffprobe', [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      source.path,
    ]);
    if (result.exitCode != 0) return null;
    return parseFfprobeJson(result.stdout);
  }

  @override
  Future<List<Uint8List?>> extractFrames({
    required File source,
    required List<Duration> times,
    int maxDimension = 160,
    bool exact = false,
  }) async {
    if (times.isEmpty) return const [];
    final dir = await Directory.systemTemp.createTemp('frames');
    try {
      final frames = <Uint8List?>[];
      for (var i = 0; i < times.length; i++) {
        final out = File.fromUri(dir.uri.resolve('frame_$i.jpg'));
        final seconds = times[i].inMilliseconds / 1000;
        final at = seconds.toStringAsFixed(3);
        final result = await _runner.run('ffmpeg', [
          '-v',
          'error',
          // Before -i: seeks to the keyframe and decodes on to the very frame
          // (-accurate_seek is on by default), so it serves an exact pick as
          // well. After -i it would decode the clip from its start.
          '-ss',
          at,
          '-i',
          source.path,
          '-frames:v',
          '1',
          '-vf',
          'scale=$maxDimension:$maxDimension:force_original_aspect_ratio=decrease',
          '-q:v',
          '4',
          '-y',
          out.path,
        ]);
        frames.add(
          result.exitCode == 0 && await out.exists()
              ? await out.readAsBytes()
              : null,
        );
      }
      return frames;
    } finally {
      await dir.delete(recursive: true);
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
    final tmp = File('${output.path}.tmp');
    final durationMs = probe?.durationMs ?? 0;
    final result = await _runner.stream(
      'ffmpeg',
      [
        '-y',
        '-i',
        source.path,
        '-c:v',
        'libx264',
        '-b:v',
        '${target.videoBitrateKbps}k',
        '-vf',
        "scale=w=-2:h='min(${target.maxHeight},ih)'",
        '-c:a',
        'aac',
        '-b:a',
        '${target.audioBitrateKbps}k',
        '-movflags',
        '+faststart',
        '-progress',
        'pipe:1',
        '-nostats',
        // Force the MP4 muxer: the temp file ends in ".tmp", so ffmpeg cannot
        // infer the format from the extension (it would error "Unable to
        // choose an output format"). Explicit -f keeps the tmp-rename reliable.
        '-f',
        'mp4',
        tmp.path,
      ],
      onStdoutLine: (line) {
        if (onProgress == null || durationMs <= 0) return;
        if (line.startsWith('out_time_us=')) {
          final us = int.tryParse(line.substring('out_time_us='.length));
          if (us != null) {
            onProgress((us / 1000 / durationMs).clamp(0.0, 1.0));
          }
        } else if (line == 'progress=end') {
          onProgress(1.0);
        }
      },
    );
    if (result.exitCode != 0) {
      try {
        await tmp.delete();
      } on FileSystemException {
        // Nothing to clean.
      }
      final stderr = result.stderr;
      throw TranscodeException(
        'ffmpeg exited ${result.exitCode}${stderr.isEmpty ? '' : ': $stderr'}',
      );
    }
    // The final rename can still fail (permission/IO); surface it as a
    // TranscodeException (contract: engine failures throw TranscodeException,
    // never a raw FileSystemException) so PlatformVideoTranscoder's
    // fallback-to-original path catches it, and leave no .tmp behind.
    try {
      await tmp.rename(output.path);
    } on FileSystemException catch (e) {
      try {
        await tmp.delete();
      } on FileSystemException {
        // Nothing to clean.
      }
      throw TranscodeException('failed to finalize output: ${e.message}');
    }
  }
}
