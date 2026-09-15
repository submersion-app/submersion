import 'package:submersion/core/utils/number_utils.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

/// Reads the dive-level tissue state a Suunto SML header carries under
/// `Header.Diving` (`StartTissue`, `EndTissue`, `Algorithm`) into a
/// [ComputerTissueSnapshot].
///
/// Suunto reports per-compartment tensions in Pascal (9 compartments on the
/// HelO2 / D-series RGBM, 15 on the EON Fused2 RGBM); they come out in bar
/// with five decimals. `CNS` (and its `OLF` stand-in on older models) is a
/// 0-1 fraction and comes out in percent; `OTU` and the two RGBM factors are
/// kept as reported.
///
/// Two encodings of the compartment arrays exist and both are accepted: a
/// plain numeric list (the app's DeviceLog JSON export), or -- in JSON
/// derived from the SML XML -- a `{"Pressure": [...]}` object or a list of
/// `{"Pressure": n}` maps.
///
/// A state with no numeric content is skipped; the result is null when
/// neither state has anything, even if `Algorithm` is present. Never throws.
ComputerTissueSnapshot? parseSuuntoTissue(Map<String, dynamic> diving) {
  final start = _stateOf(diving['StartTissue']);
  final end = _stateOf(diving['EndTissue']);
  if (start == null && end == null) return null;

  final algorithm = diving['Algorithm'];
  return ComputerTissueSnapshot(
    algorithm: algorithm is String && algorithm.isNotEmpty ? algorithm : null,
    start: start,
    end: end,
  );
}

const double _pascalPerBar = 100000;

ComputerTissueState? _stateOf(Object? value) {
  if (value is! Map) return null;
  final tissue = Map<String, dynamic>.from(value);

  final cns = asDoubleOrNull(tissue['CNS']) ?? asDoubleOrNull(tissue['OLF']);
  final state = ComputerTissueState(
    n2Bar: _tensionsBar(tissue['Nitrogen']),
    heBar: _tensionsBar(tissue['Helium']),
    cnsPercent: cns == null ? null : cns * 100,
    otu: asDoubleOrNull(tissue['OTU']),
    rgbmNitrogen: asDoubleOrNull(tissue['RgbmNitrogen']),
    rgbmHelium: asDoubleOrNull(tissue['RgbmHelium']),
  );

  final hasContent =
      state.n2Bar != null ||
      state.heBar != null ||
      state.cnsPercent != null ||
      state.otu != null ||
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
