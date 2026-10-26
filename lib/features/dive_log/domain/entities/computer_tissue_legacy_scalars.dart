import 'package:submersion/core/utils/number_utils.dart';

/// The dive-level values a computer tissue snapshot held before issue
/// #2555: the deco model, the CNS at dive start and end, and the OTU.
///
/// Each has a dive column of its own (`deco_algorithm`, `cns_start`,
/// `cns_end`, `otu`), so the snapshot no longer carries them. This reads
/// them out of snapshot JSON written before that, wherever such JSON still
/// turns up: the v318 rung, which moves the stored ones into their columns,
/// the same move after sync applies a dive from a peer below v318, and the
/// UDDF import of a backup made before it. Start OTU
/// is not read: no column holds it, and a computer's OTU at dive start is
/// what earlier dives left, not this dive's.
///
/// Works on the raw JSON map, never on `ComputerTissueSnapshot`, whose
/// reader drops these keys.
class LegacyTissueScalars {
  const LegacyTissueScalars({
    this.cnsStart,
    this.cnsEnd,
    this.otu,
    this.algorithm,
  });

  /// Reads the values from snapshot [json]. A missing or malformed value
  /// reads as null; never throws.
  factory LegacyTissueScalars.of(Map<String, dynamic> json) {
    final start = json['start'];
    final end = json['end'];
    final algorithm = json['algorithm'];
    final name = algorithm is String ? algorithm.trim() : '';
    return LegacyTissueScalars(
      cnsStart: start is Map ? asDoubleOrNull(start[_cnsKey]) : null,
      cnsEnd: end is Map ? asDoubleOrNull(end[_cnsKey]) : null,
      otu: end is Map ? asDoubleOrNull(end[_otuKey]) : null,
      algorithm: name.isEmpty ? null : name,
    );
  }

  static const _algorithmKey = 'algorithm';
  static const _cnsKey = 'cns_percent';
  static const _otuKey = 'otu';

  final double? cnsStart;
  final double? cnsEnd;
  final double? otu;

  /// The model name as the source wrote it ('Suunto Fused2 RGBM',
  /// 'zhl_16c'), not normalised.
  final String? algorithm;

  bool get isEmpty =>
      cnsStart == null && cnsEnd == null && otu == null && algorithm == null;

  /// A copy of snapshot [json] without the dive-level keys, start OTU
  /// included. A state left with no key is dropped, as the snapshot never
  /// writes an empty one. Keys it does not know are kept.
  static Map<String, dynamic> strip(Map<String, dynamic> json) {
    final stripped = <String, dynamic>{};
    for (final MapEntry(:key, :value) in json.entries) {
      if (key == _algorithmKey) continue;
      if (!_stateKeys.contains(key)) {
        stripped[key] = value;
      } else if (_stateWithout(value) case final state?) {
        stripped[key] = state;
      }
    }
    return stripped;
  }

  static const _stateKeys = {'start', 'end'};

  /// [value] without CNS and OTU when it is a state map, or null when that
  /// leaves it empty. Anything else is kept as it is.
  static Object? _stateWithout(Object? value) {
    if (value is! Map) return value;
    final kept = {
      for (final entry in value.entries)
        if (entry.key != _cnsKey && entry.key != _otuKey)
          entry.key as String: entry.value,
    };
    return kept.isEmpty ? null : kept;
  }
}
