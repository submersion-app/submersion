import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart'
    show MacDiveUnitSystem;

/// Works out which unit system a MacDive Core Data store was written under.
///
/// MacDive records the preference in `ZMETADATA.ZALL` where
/// `ZIDENTIFIER = 'SystemOfUnits'`, but real libraries are routinely missing
/// that row - the 540-dive reference database has a `ZMETADATA` table whose
/// only row carries a UUID and a null value. Treating that as "unknown" and
/// passing values through unconverted is what made imported tank pressures
/// nonsensical (#912): 3118 psi arrived as 3118 bar.
///
/// The magnitudes involved are far apart, so the data itself is a reliable
/// witness. Working pressures are ~200-300 bar or ~2400-3500 psi - more than
/// an order of magnitude apart, with nothing plausible in between.
class MacDiveUnitInference {
  const MacDiveUnitInference._();

  /// Above this, a pressure can only be psi: no cylinder is filled to 600 bar.
  static const _pressureBarCeiling = 600.0;

  /// Above this, a cylinder "size" can only be cubic feet: no single cylinder
  /// holds 40 litres of water.
  static const _tankSizeLitreCeiling = 40.0;

  /// Resolves the display unit for [logbook], preferring MacDive's own
  /// declaration and falling back to inference from the data.
  static MacDiveUnitSystem resolve(MacDiveRawLogbook logbook) {
    final declared = MacDiveUnitSystem.fromXml(logbook.unitsPreference);
    if (declared != MacDiveUnitSystem.unknown) return declared;
    return infer(logbook);
  }

  /// Infers the display unit purely from stored magnitudes. Returns
  /// [MacDiveUnitSystem.unknown] when the logbook carries no usable signal,
  /// so callers keep the conservative passthrough behaviour.
  static MacDiveUnitSystem infer(MacDiveRawLogbook logbook) {
    // Strongest signal: cylinder pressures.
    final pressures = <double>[
      for (final t in logbook.tanksByPk.values)
        if (t.workingPressure != null && t.workingPressure! > 0)
          t.workingPressure!,
      for (final tg in logbook.tankAndGases) ...[
        if (tg.airStart != null && tg.airStart! > 0) tg.airStart!,
        if (tg.airEnd != null && tg.airEnd! > 0) tg.airEnd!,
      ],
    ];
    if (pressures.isNotEmpty) {
      final max = pressures.reduce((a, b) => a > b ? a : b);
      return max > _pressureBarCeiling
          ? MacDiveUnitSystem.imperial
          : MacDiveUnitSystem.metric;
    }

    // Next best: cylinder size, cubic feet vs litres.
    final sizes = <double>[
      for (final t in logbook.tanksByPk.values)
        if (t.size != null && t.size! > 0) t.size!,
    ];
    if (sizes.isNotEmpty) {
      final max = sizes.reduce((a, b) => a > b ? a : b);
      return max > _tankSizeLitreCeiling
          ? MacDiveUnitSystem.imperial
          : MacDiveUnitSystem.metric;
    }

    // Nothing to go on. Passthrough is safer than a coin flip.
    return MacDiveUnitSystem.unknown;
  }
}
