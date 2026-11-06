import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_exchange_style.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The tooltip text for one compartment in [status], shared by the tissue
/// bar chart, heat map and area chart so all three read the same.
String tissueCompartmentTooltip(
  AppLocalizations l10n,
  DecoStatus status,
  TissueCompartment comp,
) {
  final gf = comp.gradientFactor(status.ambientPressureBar) * 100;
  final withHelium = showsHelium(comp, status.inspiredHeBar);
  final n2 = status.n2Exchange(comp);
  final he = status.heExchange(comp);
  final net = status.netExchange(comp);
  final surfaceLevel = comp.equilibriumLoadingPercent(
    status.surfaceEquilibriumN2Bar,
  );

  String gasLine(String symbol, double tension, String? direction) =>
      '$symbol: ${tension.toStringAsFixed(2)} bar'
      '${direction != null ? ' ($direction)' : ''}';

  return [
    l10n.diveLog_deco_tooltipCompartment(comp.compartmentNumber),
    l10n.diveLog_deco_tooltipLoaded(comp.percentLoading.toStringAsFixed(1)),
    'GF: ${gf.clamp(0.0, double.infinity).toStringAsFixed(0)}%',
    gasLine('N₂', comp.currentPN2, withHelium ? n2?.label(l10n) : null),
    if (withHelium) gasLine('He', comp.currentPHe, he?.label(l10n)),
    l10n.diveLog_deco_tooltipHalfTime(
      halfTimeText(comp, withHelium: withHelium),
    ),
    l10n.diveLog_deco_tooltipSurfaceLevel(surfaceLevel.toStringAsFixed(0)),
    if (net != null) net.label(l10n),
  ].join('\n');
}
