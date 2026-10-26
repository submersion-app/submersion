import 'package:submersion/core/utils/number_utils.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

/// Reads the dive-level tissue state a Suunto SML header carries under
/// `Header.Diving` (`StartTissue`, `EndTissue`) into a
/// [ComputerTissueSnapshot].
///
/// Suunto reports per-compartment tensions in Pascal (9 compartments on the
/// HelO2 / D-series RGBM, 15 on the EON Fused2 RGBM); they come out in bar
/// with five decimals. The two RGBM factors are kept as reported. The
/// entries' `CNS` and `OTU` are the dive's own columns, read by
/// [parseSuuntoExposure], and `Algorithm` is the dive's deco model; neither
/// goes in the snapshot (issue #2555).
///
/// Two encodings of the compartment arrays exist and both are accepted: a
/// plain numeric list (the app's DeviceLog JSON export), or -- in JSON
/// derived from the SML XML -- a `{"Pressure": [...]}` object or a list of
/// `{"Pressure": n}` maps.
///
/// A state with no tensions or RGBM factors is skipped; the result is null
/// when neither state has any. Never throws.
ComputerTissueSnapshot? parseSuuntoTissue(Map<String, dynamic> diving) {
  final start = _stateOf(diving['StartTissue']);
  final end = _stateOf(diving['EndTissue']);
  if (start == null && end == null) return null;
  return ComputerTissueSnapshot(start: start, end: end);
}

/// The oxygen exposure the same header reports: `StartTissue.CNS` and
/// `EndTissue.CNS`, a 0-1 fraction, in percent, and `EndTissue.OTU` as
/// reported. These are the dive's `cns_start`, `cns_end` and `otu`.
///
/// `OLF` is never read as CNS: it is the higher of CNS% and OTU%, so it
/// overstates CNS whenever OTU is the binding limit. The start OTU is not
/// read: it is what earlier dives left, and no dive column holds it. A
/// missing or malformed value is null; never throws.
({double? cnsStart, double? cnsEnd, double? otu}) parseSuuntoExposure(
  Map<String, dynamic> diving,
) {
  final start = diving['StartTissue'];
  final end = diving['EndTissue'];
  return (
    cnsStart: start is Map ? _cnsPercent(start['CNS']) : null,
    cnsEnd: end is Map ? _cnsPercent(end['CNS']) : null,
    otu: end is Map ? asDoubleOrNull(end['OTU']) : null,
  );
}

double? _cnsPercent(Object? fraction) {
  final cns = asDoubleOrNull(fraction);
  return cns == null ? null : cns * 100;
}

const double _pascalPerBar = 100000;

ComputerTissueState? _stateOf(Object? value) {
  if (value is! Map) return null;
  final tissue = Map<String, dynamic>.from(value);

  final state = ComputerTissueState(
    n2Bar: _tensionsBar(tissue['Nitrogen']),
    heBar: _tensionsBar(tissue['Helium']),
    rgbmNitrogen: asDoubleOrNull(tissue['RgbmNitrogen']),
    rgbmHelium: asDoubleOrNull(tissue['RgbmHelium']),
  );

  final hasContent =
      state.n2Bar != null ||
      state.heBar != null ||
      state.rgbmNitrogen != null ||
      state.rgbmHelium != null;
  return hasContent ? state : null;
}

/// Per-compartment tensions in bar, or null when [value] holds none.
///
/// Compartment order is positional, so a list with any non-numeric element
/// reads as null as a whole rather than as a shorter list.
List<double>? _tensionsBar(Object? value) {
  if (value is Map) return _tensionsBar(value['Pressure']);
  if (value is! List || value.isEmpty) return null;

  final bars = <double>[];
  for (final element in value) {
    final pascal = asDoubleOrNull(
      element is Map ? element['Pressure'] : element,
    );
    if (pascal == null) return null;
    bars.add(_pascalToBar(pascal));
  }
  return List.unmodifiable(bars);
}

/// Pascal to bar, kept to five decimals (whole-Pascal precision).
double _pascalToBar(double pascal) => pascal.round() / _pascalPerBar;
