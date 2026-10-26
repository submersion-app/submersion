import 'package:submersion_transcoder/submersion_transcoder.dart';

/// The colour-encode integration cases (issue #3521), shared by the in-app
/// encode test and the host-side tools that make its inputs and check its
/// outputs (tool/color_encode_it, scripts/run_color_encode_it.sh).

/// The folder, in the app's temp directory, holding `in/` and `out/`.
const colorItFolder = 'color_it';

/// A long clip for the cancel test.
const longCase = ColorCase('long', codec: 'h264', transfer: SignalTransfer.sdr);

/// A clip to synthesize, and what the encode must keep.
class ColorCase {
  const ColorCase(
    this.name, {
    required this.codec,
    required this.transfer,
    this.rotation = 0,
    this.startOffsetSeconds = 0,
    this.tenBitSdr = false,
  });

  final String name;

  /// The clip's file name, the same for input and output.
  String get fileName => '${name.replaceAll(' ', '_')}.mp4';

  /// ffprobe codec_name of source and copy: 'h264' or 'hevc'.
  final String codec;
  final SignalTransfer transfer;
  final int rotation;
  final double startOffsetSeconds;

  /// A 10-bit clip without HDR (GoPro and some Android phones).
  final bool tenBitSdr;

  bool get tenBit => tenBitSdr || transfer != SignalTransfer.sdr;
}

const colorCases = [
  ColorCase('h264 sdr', codec: 'h264', transfer: SignalTransfer.sdr),
  ColorCase('hevc sdr', codec: 'hevc', transfer: SignalTransfer.sdr),
  ColorCase(
    'hevc sdr 10-bit',
    codec: 'hevc',
    transfer: SignalTransfer.sdr,
    tenBitSdr: true,
  ),
  ColorCase('hevc hlg 10-bit', codec: 'hevc', transfer: SignalTransfer.hlg),
  ColorCase('hevc pq 10-bit', codec: 'hevc', transfer: SignalTransfer.pq),
  ColorCase(
    'rotated 90 h264',
    codec: 'h264',
    transfer: SignalTransfer.sdr,
    rotation: 90,
  ),
  ColorCase(
    'h264 with a start offset',
    codec: 'h264',
    transfer: SignalTransfer.sdr,
    startOffsetSeconds: 1.5,
  ),
];

/// Identity at the start, warm with a brightness offset at 2 s.
final testTimeline = ColorTimeline([
  ColorTimelineKey(
    timeMs: 0,
    matrix: const [
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0, //
    ],
  ),
  ColorTimelineKey(
    timeMs: 2000,
    matrix: const [
      1.3, 0, 0, 0, 10, //
      0, 1, 0, 0, 10, //
      0, 0, 0.7, 0, 10, //
      0, 0, 0, 1, 0, //
    ],
  ),
]);
