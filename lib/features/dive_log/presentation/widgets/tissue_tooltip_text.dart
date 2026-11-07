import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_exchange_style.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The tooltips built for each status, per compartment index, with the
/// localizations they were built for. The bar chart rebuilds on every hover
/// with the same status, so all 16 tooltips are reused instead of
/// re-derived; a new status (another sample, a profile scrub, a copyWith)
/// starts its own entry, and another locale rebuilds them. Held by an
/// [Expando] on the status, so the entries go away with it.
final Expando<(AppLocalizations, Map<int, String>)> _cache = Expando();

/// The tooltip text for one compartment in [status], shared by the tissue
/// bar chart, heat map, area chart and the deco calculator's panel so all of
/// them read the same.
String tissueCompartmentTooltip(
  AppLocalizations l10n,
  DecoStatus status,
  TissueCompartment comp,
) {
  var entry = _cache[status];
  if (entry == null || !identical(entry.$1, l10n)) {
    entry = (l10n, <int, String>{});
    _cache[status] = entry;
  }
  return entry.$2[comp.compartmentNumber] ??= _buildTooltip(l10n, status, comp);
}

String _buildTooltip(
  AppLocalizations l10n,
  DecoStatus status,
  TissueCompartment comp,
) {
  final gf = comp.gradientFactor(status.ambientPressureBar) * 100;
  final withHelium = showsHelium(comp, status.inspiredHeBar);
  // Each direction once: the net one is combined from the per-gas results.
  final n2 = status.n2Exchange(comp);
  final he = status.heExchange(comp);
  final net = status.combineExchanges(comp, n2: n2, he: he);
  final surfaceLevel = comp.equilibriumLoadingPercent(
    status.surfaceEquilibriumN2Bar,
  );

  String gasLine(String symbol, double tension, String? direction) =>
      '$symbol: ${tension.toStringAsFixed(2)} bar'
      '${direction != null ? ' ($direction)' : ''}';

  return [
    l10n.diveLog_deco_tooltipCompartment(comp.compartmentNumber),
    l10n.diveLog_deco_tooltipLoaded(comp.percentLoading.toStringAsFixed(1)),
    'GF: ${l10n.diveLog_deco_percentValue(gf.clamp(0.0, double.infinity).toStringAsFixed(0))}',
    gasLine('N₂', comp.currentPN2, withHelium ? n2?.label(l10n) : null),
    if (withHelium) gasLine('He', comp.currentPHe, he?.label(l10n)),
    l10n.diveLog_deco_tooltipHalfTime(
      halfTimeText(comp, withHelium: withHelium),
    ),
    l10n.diveLog_deco_tooltipSurfaceLevel(surfaceLevel.toStringAsFixed(0)),
    if (net != null) net.label(l10n),
  ].join('\n');
}
