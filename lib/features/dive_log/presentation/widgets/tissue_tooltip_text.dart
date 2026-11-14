import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compartment_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_exchange_style.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The tooltip text for one compartment in [status], shared by the tissue
/// bar chart, heat map, area chart and the deco calculator's panel so all of
/// them read the same.
///
/// Pure: the bar chart, which builds all 16 on every hover, memoizes them
/// for its current status itself (see `TissuePressureBarChart`), so nothing
/// here outlives the widget that shows it. Decimals follow the active
/// locale's separator, like every other value the app displays.
String tissueCompartmentTooltip(
  AppLocalizations l10n,
  DecoStatus status,
  TissueCompartment comp,
) {
  final gf = comp.gradientFactor(status.ambientPressureBar) * 100;
  final withHelium = showsHelium(comp, status.inspiredHeBar);
  final exchanges = status.gasExchanges(comp);
  final surfaceLevel = comp.equilibriumLoadingPercent(
    status.surfaceEquilibriumN2Bar,
  );

  String gasLine(String symbol, double tension, String? direction) =>
      '$symbol: ${formatFixedForDisplay(tension, 2)} bar'
      '${direction != null ? ' ($direction)' : ''}';

  final net = exchanges.net;
  return [
    l10n.diveLog_deco_tooltipCompartment(comp.compartmentNumber),
    CompartmentGroup.ofNumber(comp.compartmentNumber).label(l10n),
    l10n.diveLog_deco_tooltipLoaded(
      formatFixedForDisplay(comp.percentLoading, 1),
    ),
    'GF: ${l10n.diveLog_deco_percentValue(formatFixedForDisplay(gf.clamp(0.0, double.infinity), 0))}',
    gasLine(
      'N₂',
      comp.currentPN2,
      withHelium ? exchanges.n2?.label(l10n) : null,
    ),
    if (withHelium) gasLine('He', comp.currentPHe, exchanges.he?.label(l10n)),
    l10n.diveLog_deco_tooltipHalfTime(
      halfTimeText(comp, withHelium: withHelium),
    ),
    l10n.diveLog_deco_tooltipSurfaceLevel(
      formatFixedForDisplay(surfaceLevel, 0),
    ),
    if (net != null) net.label(l10n),
  ].join('\n');
}
