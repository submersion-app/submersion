import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion_transcoder/submersion_transcoder.dart';

import '../../integration_test/helpers/color_encode_cases.dart';

export '../../integration_test/helpers/color_encode_cases.dart';

/// Host side of the colour-encode integration check (issue #3521), run by
/// scripts/run_color_encode_it.sh: synthesizes input clips with ffmpeg for
/// the in-app encode, and reads its output back with ffprobe and ffmpeg.
/// Kept out of the app because the sandboxed macOS app may not run ffmpeg.

/// Where the app may look for inputs: COLOR_IT_DIR alone when set; else the
/// system temp folder, plus on macOS the sandboxed app's own temp folder (an
/// unsigned CI build runs without the sandbox and uses the system one).
List<Directory> colorItDirs() {
  final env = Platform.environment['COLOR_IT_DIR'];
  if (env != null && env.isNotEmpty) return [Directory(env)];
  return [
    Directory(p.join(Directory.systemTemp.path, colorItFolder)),
    if (Platform.isMacOS)
      Directory(
        p.join(
          Platform.environment['HOME']!,
          'Library',
          'Containers',
          'app.submersion',
          'Data',
          'tmp',
          colorItFolder,
        ),
      ),
  ];
}

/// The folder the app wrote its outputs into.
Directory colorItOutputRoot() => colorItDirs().firstWhere(
  (d) => Directory(p.join(d.path, 'out')).existsSync(),
  orElse: () => colorItDirs().first,
);

const _width = 320;
const _height = 240;

/// Centre of each of the three colour bands.
const bandCentres = [53, 160, 266];

/// [exe] on PATH, or in the usual Homebrew and /usr/local places: a macOS
/// test app is launched with a minimal PATH that leaves those out.
Future<String?> which(String exe) async {
  final result = await Process.run(Platform.isWindows ? 'where' : 'which', [
    exe,
  ]);
  final found = (result.stdout as String).trim().split('\n').first.trim();
  if (result.exitCode == 0 && found.isNotEmpty) return found;
  if (Platform.isWindows) return null;
  for (final dir in ['/opt/homebrew/bin', '/usr/local/bin']) {
    final candidate = File(p.join(dir, exe));
    if (await candidate.exists()) return candidate.path;
  }
  return null;
}

String _tags(SignalTransfer t) => switch (t) {
  SignalTransfer.sdr => 'bt709',
  SignalTransfer.hlg => 'arib-std-b67',
  SignalTransfer.pq => 'smpte2084',
};

/// Writes a [seconds]-long clip of three flat bands (blue water, grey, a
/// warm highlight) with a tone, a recording date and a location.
Future<File> synthesize(
  String ffmpeg,
  Directory dir,
  ColorCase c, {
  double seconds = 2.5,
  int width = _width,
  int height = _height,
}) async {
  final target = File(p.join(dir.path, c.fileName));
  final plain = c.rotation == 0
      ? target
      : File(p.join(dir.path, 'unrotated_${c.fileName}'));
  final hdr = c.transfer != SignalTransfer.sdr;
  final source =
      'color=c=0x1464a0:s=${width}x$height:d=$seconds:r=30,'
      'drawbox=x=${width ~/ 3}:y=0:w=${width ~/ 3}:h=$height:color=0x808080:t=fill,'
      'drawbox=x=${2 * width ~/ 3}:y=0:w=${width - 2 * width ~/ 3}:h=$height:'
      'color=0xf0c83c:t=fill';
  final args = [
    '-y',
    '-v',
    'error',
    '-f',
    'lavfi',
    '-i',
    source,
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=440:duration=$seconds',
    if (c.codec == 'h264') ...[
      '-c:v',
      'libx264',
    ] else ...[
      '-c:v',
      'libx265',
      '-tag:v',
      'hvc1',
    ],
    '-pix_fmt',
    c.tenBit ? 'yuv420p10le' : 'yuv420p',
    '-color_primaries',
    hdr ? 'bt2020' : 'bt709',
    '-color_trc',
    _tags(c.transfer),
    '-colorspace',
    hdr ? 'bt2020nc' : 'bt709',
    // libx265 writes the colour tags only from its own parameters.
    if (c.codec == 'hevc') ...[
      '-x265-params',
      [
        'colorprim=${hdr ? 'bt2020' : 'bt709'}',
        'transfer=${_tags(c.transfer)}',
        'colormatrix=${hdr ? 'bt2020nc' : 'bt709'}',
        if (c.transfer == SignalTransfer.pq) ...[
          'hdr10=1',
          'master-display=G(13250,34500)B(7500,3000)R(34000,16000)'
              'WP(15635,16450)L(10000000,1)',
          'max-cll=1000,400',
        ],
      ].join(':'),
    ],
    '-c:a',
    'aac',
    '-metadata',
    'creation_time=2026-05-01T10:00:00Z',
    '-metadata',
    'location=+20.5000-087.0000/',
    if (c.startOffsetSeconds > 0) ...[
      '-output_ts_offset',
      '${c.startOffsetSeconds}',
    ],
    '-shortest',
    plain.path,
  ];
  final gen = await Process.run(ffmpeg, args);
  expect(gen.exitCode, 0, reason: 'fixture ${c.name}: ${gen.stderr}');
  if (c.rotation == 0) return plain;
  final rotated = target;
  final rot = await Process.run(ffmpeg, [
    '-y',
    '-v',
    'error',
    '-display_rotation',
    '${c.rotation}',
    '-i',
    plain.path,
    '-c',
    'copy',
    // A stream copy does not carry the movie header date over.
    '-metadata',
    'creation_time=2026-05-01T10:00:00Z',
    rotated.path,
  ]);
  expect(rot.exitCode, 0, reason: 'rotating ${c.name}: ${rot.stderr}');
  await plain.delete();
  return rotated;
}

/// ffprobe's view of [file]: format and streams, plus the first frame's
/// side data.
Future<Map<String, dynamic>> probeJson(String ffprobe, File file) async {
  final result = await Process.run(ffprobe, [
    '-v',
    'error',
    '-print_format',
    'json',
    '-show_format',
    '-show_streams',
    '-show_frames',
    '-read_intervals',
    '%+#1',
    '-select_streams',
    'v:0',
    file.path,
  ]);
  expect(result.exitCode, 0, reason: 'ffprobe: ${result.stderr}');
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}

Future<bool> hasAudio(String ffprobe, File file) async {
  final result = await Process.run(ffprobe, [
    '-v',
    'error',
    '-select_streams',
    'a',
    '-show_entries',
    'stream=codec_type',
    '-of',
    'csv=p=0',
    file.path,
  ]);
  return (result.stdout as String).contains('audio');
}

/// Every metadata tag on [file]'s container and its streams, keys lower-cased.
Future<Map<String, String>> allTags(String ffprobe, File file) async {
  final result = await Process.run(ffprobe, [
    '-v',
    'error',
    '-print_format',
    'json',
    '-show_format',
    '-show_streams',
    file.path,
  ]);
  final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final tags = <String, String>{};
  void add(Object? t) {
    if (t is Map) {
      t.forEach((k, v) => tags['$k'.toLowerCase()] = '$v');
    }
  }

  add((json['format'] as Map?)?['tags']);
  for (final s in (json['streams'] as List? ?? const [])) {
    add((s as Map)['tags']);
  }
  return tags;
}

/// The presentation time of [file]'s first video frame, in seconds.
Future<double> firstFrameSeconds(String ffprobe, File file) async {
  final json = await probeJson(ffprobe, file);
  final frame = (json['frames'] as List).first as Map;
  return double.parse(
    '${frame['best_effort_timestamp_time'] ?? frame['pts_time']}',
  );
}

/// The presentation time of [file]'s last video frame, in seconds.
Future<double> lastFrameSeconds(String ffprobe, File file) async {
  final result = await Process.run(ffprobe, [
    '-v',
    'error',
    '-select_streams',
    'v:0',
    '-show_entries',
    'frame=best_effort_timestamp_time',
    '-of',
    'csv=p=0',
    file.path,
  ]);
  final times = (result.stdout as String)
      // Some streams add an empty field after the time ("2.466667,").
      .split(RegExp(r'[\s,]+'))
      .map(double.tryParse)
      .whereType<double>();
  return times.reduce((a, b) => a > b ? a : b);
}

/// The encoded R'G'B' (0..1) at the centre of each band in the first frame
/// at or after presentation time [seconds], decoded the same way for every
/// file: the clip's own YUV matrix, no transfer change, no rotation.
Future<List<List<double>>> bandColors(
  String ffmpeg,
  File file,
  double seconds, {
  required bool hdr,
}) async {
  final at = seconds;
  final result = await Process.run(ffmpeg, [
    '-v',
    'error',
    '-noautorotate',
    // Keep presentation times as they are; ffmpeg otherwise shifts a clip
    // that starts late to begin at 0.
    '-copyts',
    '-i',
    file.path,
    '-vf',
    'select=gte(t\\,$at),'
        'scale=in_color_matrix=${hdr ? 'bt2020' : 'bt709'}:in_range=tv',
    '-frames:v',
    '1',
    '-f',
    'rawvideo',
    '-pix_fmt',
    'rgb48le',
    '-',
  ], stdoutEncoding: null);
  expect(result.exitCode, 0, reason: 'frame read: ${result.stderr}');
  final bytes = result.stdout as List<int>;
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  final width = bytes.length ~/ (6 * _height);
  return [
    for (final x in bandCentres)
      [
        for (var ch = 0; ch < 3; ch++)
          data.getUint16(
                ((_height ~/ 2) * width + x) * 6 + ch * 2,
                Endian.little,
              ) /
              65535,
      ],
  ];
}
