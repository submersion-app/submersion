import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Decodes Diving Log's packed sample columns.
///
/// Samples are fixed-width ASCII, one stride per sample, spread across five
/// parallel columns. Each column is consumed with its own cursor because
/// they are independently optional and can run out at different points: a
/// dive logged without air integration has `Profile` but no `Profile2`.
///
/// Field layouts, with the divisors these strides imply:
///
/// - [profile], stride 12, `DDDDDCRASWEE`: depth in centimetres (5), deco
///   flag (1), RBT warning, ascent warning, decostop ignored, work warning,
///   two characters of computer-specific extra.
/// - [profile2], stride 11, `TTTFFFFIRRR`: temperature in tenths of a
///   degree Celsius (3), tank pressure in tenths of a bar (4), tank id (1),
///   remaining bottom time in minutes (3).
/// - [profile3], stride 14: heart rate at offset 8, width 3.
/// - [profile4], stride 9: no-decompression limit in minutes, or time to
///   surface when in deco (3), stop time in minutes (3), stop depth in
///   metres (3).
/// - [profile5], stride 19, `AAABBBCCCOOOONNNNSS`: three measured ppO2
///   cells in hundredths of a bar, OTU in tenths, CNS in tenths of a
///   percent, setpoint in tenths of a bar.
///
/// Sample timestamps are the sample index times the recording interval.
class DivingLogProfileCodec {
  static const _strideProfile = 12;
  static const _strideProfile2 = 11;
  static const _strideProfile3 = 14;
  static const _strideProfile4 = 9;
  static const _strideProfile5 = 19;

  const DivingLogProfileCodec._();

  static List<DivingLogRawSample> decode({
    required int intervalSeconds,
    String? profile,
    String? profile2,
    String? profile3,
    String? profile4,
    String? profile5,
  }) {
    final p1 = profile ?? '';
    if (p1.length < _strideProfile) return const [];

    // A logbook row with a zero or negative interval still has ordered
    // samples; one second keeps them distinct and monotonic.
    final interval = intervalSeconds > 0 ? intervalSeconds : 1;

    final p2 = profile2 ?? '';
    final p3 = profile3 ?? '';
    final p4 = profile4 ?? '';
    final p5 = profile5 ?? '';

    final samples = <DivingLogRawSample>[];
    var index = 0;
    var o1 = 0;

    while (o1 + _strideProfile <= p1.length) {
      final o2 = index * _strideProfile2;
      final o3 = index * _strideProfile3;
      final o4 = index * _strideProfile4;
      final o5 = index * _strideProfile5;

      final hasP2 = o2 + _strideProfile2 <= p2.length;
      final hasP3 = o3 + _strideProfile3 <= p3.length;
      final hasP4 = o4 + _strideProfile4 <= p4.length;
      final hasP5 = o5 + _strideProfile5 <= p5.length;

      final inDeco = _digit(p1, o1 + 5) == 1;
      final ndlOrTts = hasP4 ? _int(p4, o4, 3) : null;

      // An unreadable depth is not a surface sample. Substituting 0 would
      // draw a spike to the surface mid-dive and skew average depth and
      // ascent-rate analysis, so the sample is dropped instead. The index
      // still advances, so the remaining samples keep their timestamps.
      final depthRaw = _int(p1, o1, 5);
      if (depthRaw == null) {
        index++;
        o1 += _strideProfile;
        continue;
      }

      samples.add(
        DivingLogRawSample(
          timeSeconds: index * interval,
          depthMeters: depthRaw / 100.0,
          inDeco: inDeco,
          ascentWarning: _digit(p1, o1 + 7) == 1,
          temperatureCelsius: hasP2 ? _scaled(p2, o2, 3, 10.0) : null,
          pressureBar: hasP2 ? _scaled(p2, o2 + 3, 4, 10.0) : null,
          tankId: hasP2 ? _int(p2, o2 + 7, 1) : null,
          rbtSeconds: hasP2 ? _minutes(_int(p2, o2 + 8, 3)) : null,
          heartRate: hasP3 ? _int(p3, o3 + 8, 3) : null,
          ndlSeconds: inDeco ? null : _minutes(ndlOrTts),
          ttsSeconds: inDeco ? _minutes(ndlOrTts) : null,
          stopDepthMeters: hasP4
              ? _nonZero(_int(p4, o4 + 6, 3))?.toDouble()
              : null,
          ppO2Cell1: hasP5 ? _scaledNonZero(p5, o5, 3, 100.0) : null,
          ppO2Cell2: hasP5 ? _scaledNonZero(p5, o5 + 3, 3, 100.0) : null,
          ppO2Cell3: hasP5 ? _scaledNonZero(p5, o5 + 6, 3, 100.0) : null,
          otu: hasP5 ? _scaledNonZero(p5, o5 + 9, 4, 10.0) : null,
          cns: hasP5 ? _scaledNonZero(p5, o5 + 13, 4, 10.0) : null,
          setpoint: hasP5 ? _scaledNonZero(p5, o5 + 17, 2, 10.0) : null,
        ),
      );

      index++;
      o1 += _strideProfile;
    }
    return samples;
  }

  /// Reads [width] characters at [offset] as an integer, or null when the
  /// span is not entirely digits (real files pad with spaces).
  static int? _int(String s, int offset, int width) {
    if (offset + width > s.length) return null;
    return int.tryParse(s.substring(offset, offset + width).trim());
  }

  static double? _scaled(String s, int offset, int width, double divisor) {
    final raw = _int(s, offset, width);
    return raw == null ? null : raw / divisor;
  }

  /// Like [_scaled], but a zero reads as absent rather than as a measurement.
  ///
  /// Every stride carries all of its fields whether the computer recorded
  /// them or not, and the unused ones are written as zeros. Emitting those
  /// as values is not a harmless default: a 0.00 bar O2 cell asserts that a
  /// sensor was fitted and read zero, which turns an open-circuit dive into
  /// a rebreather one, and a 0 m stop depth asserts a deco ceiling at the
  /// surface.
  static double? _scaledNonZero(
    String s,
    int offset,
    int width,
    double divisor,
  ) {
    final raw = _nonZero(_int(s, offset, width));
    return raw == null ? null : raw / divisor;
  }

  static int? _nonZero(int? value) =>
      value == null || value == 0 ? null : value;

  static int? _digit(String s, int offset) => _int(s, offset, 1);

  /// A zero here means "not recorded" rather than "zero minutes", which is
  /// why it collapses to null instead of Duration.zero.
  ///
  /// The format cannot distinguish the two, so this is a judgement call, but
  /// the reference logbook settles it: `000` appears in the RBT and NDL
  /// fields of the very first stride of a dive, alongside the sentinel
  /// `255`. A dive whose surface sample genuinely had zero remaining bottom
  /// time and zero no-decompression time is not a real reading, so treating
  /// these zeros as data would raise a false alarm on the opening sample of
  /// almost every dive.
  static int? _minutes(int? value) =>
      value == null || value == 0 ? null : value * 60;
}
