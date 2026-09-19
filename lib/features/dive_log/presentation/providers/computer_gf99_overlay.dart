import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Series built from the tissue values a dive computer logs per sample:
/// GF99 ([DiveProfilePoint.gf99]) and aggregate N2 loading
/// ([DiveProfilePoint.n2Load]).
///
/// Nothing imported carries per-sample per-compartment tensions, so these
/// only ever replace or sit beside the app's own Buhlmann curves; the
/// 16-compartment recompute keeps running underneath.

/// Whether any sample carries a computer-reported GF99.
///
/// Unlike NDL/ceiling/TTS a zero is a real reading here (fresh tissues at
/// the start of a dive read 0), so presence is null-based, as for CNS.
bool hasComputerGf99(List<DiveProfilePoint> profile) =>
    profile.any((p) => p.gf99 != null);

/// The GF99 curve with the computer's value wherever it reported one and the
/// calculated value where it did not, one entry per sample. Mirrors the NDL
/// overlay's fallback: a sample past the end of [calculated] reads as 0.
List<double> buildComputerGf99Curve(
  List<DiveProfilePoint> profile,
  List<double>? calculated,
) {
  return List<double>.generate(profile.length, (i) {
    final computer = profile[i].gf99;
    if (computer != null) return computer.toDouble();
    if (calculated != null && i < calculated.length) return calculated[i];
    return 0.0;
  });
}

/// Whether any sample carries a computer-reported aggregate N2 loading.
bool hasComputerN2Load(List<DiveProfilePoint> profile) =>
    profile.any((p) => p.n2Load != null);

/// The computer's aggregate N2 loading verbatim, one entry per sample with
/// null where it reported nothing. Null when no sample carries it. This is
/// a computer-only metric with no calculated counterpart, so gaps stay gaps
/// rather than borrowing a value from elsewhere.
List<int?>? buildComputerN2LoadCurve(List<DiveProfilePoint> profile) {
  if (!hasComputerN2Load(profile)) return null;
  return List<int?>.generate(profile.length, (i) => profile[i].n2Load);
}
