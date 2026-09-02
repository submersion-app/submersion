import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A labeled, formatted tooltip row for the profile chart's consumption
/// curve.
///
/// The curve is computed in bar/min. The tooltip shows RMV only when the
/// diver displays the volume lane alone and [tankVolume] exists to convert
/// with; under Both the native SAC lane wins, because one curve carries one
/// lane and the axis stays in pressure units.
({String label, String value}) gasConsumptionTooltipRow({
  required AppLocalizations l10n,
  required UnitFormatter units,
  required GasConsumptionDisplay display,
  required double sacBarPerMin,
  required double? tankVolume,
}) {
  if (display == GasConsumptionDisplay.rmv && tankVolume != null) {
    return (
      label: l10n.gasConsumption_rmv,
      value: units.formatRmv(sacBarPerMin * tankVolume),
    );
  }
  return (label: l10n.gasConsumption_sac, value: units.formatSac(sacBarPerMin));
}
