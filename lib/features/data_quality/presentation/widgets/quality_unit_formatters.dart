import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';

/// Binds the finding renderer to a diver's units.
///
/// Takes an already-built [UnitFormatter] rather than a `WidgetRef` so any
/// caller that has one can reuse it, instead of watching the settings provider
/// a second time just to reach these five closures.
QualityUnitFormatters qualityUnitFormattersFor(
  UnitFormatter units,
) => QualityUnitFormatters(
  depth: (m) => units.formatDepth(m),
  pressure: (bar) => units.formatPressure(bar),
  temperature: (c) => units.formatTemperature(c),
  // Surface air consumption is a volume rate; honor the volume unit
  // preference (L/min vs cuft/min); this is an RMV, never a pressure rate.
  sac: (lpm) =>
      '${units.convertVolume(lpm).toStringAsFixed(1)} ${units.volumeSymbol}/min',
  date: (d) => units.formatDate(d),
);
