import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/gas_exchange.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Label, icon and color the tissue views use for a [GasExchange], so the
/// compartment badge, the per-gas arrows and the tooltips all read the same.
extension GasExchangeStyle on GasExchange {
  String label(AppLocalizations l10n) => switch (this) {
    GasExchange.ongassing => l10n.diveLog_deco_gasOngassing,
    GasExchange.offgassing => l10n.diveLog_deco_gasOffgassing,
    GasExchange.equilibrium => l10n.diveLog_deco_gasEquilibrium,
  };

  IconData get icon => switch (this) {
    GasExchange.ongassing => Icons.arrow_downward,
    GasExchange.offgassing => Icons.arrow_upward,
    GasExchange.equilibrium => Icons.horizontal_rule,
  };

  Color color(ColorScheme colorScheme) => switch (this) {
    GasExchange.ongassing => Colors.blue.shade700,
    GasExchange.offgassing => Colors.green.shade700,
    GasExchange.equilibrium => colorScheme.onSurfaceVariant,
  };
}

/// Whether the tissue views show helium for [compartment]: when it still
/// holds some, or when the diver is breathing some ([inspiredHeBar]).
bool showsHelium(TissueCompartment compartment, double? inspiredHeBar) =>
    compartment.currentPHe > 0.001 || (inspiredHeBar ?? 0) > 0.001;

/// Half-time text for [compartment]: nitrogen alone, or "N2 / He" when
/// [withHelium], since helium moves on its own, much shorter half-time.
/// Decimals take the active locale's separator.
String halfTimeText(TissueCompartment compartment, {required bool withHelium}) {
  final n2 = formatFixedForDisplay(compartment.halfTimeN2, 0);
  if (!withHelium) return n2;
  final he = formatFixedForDisplay(
    compartment.halfTimeHe,
    compartment.halfTimeHe < 10 ? 1 : 0,
  );
  return '$n2 / $he';
}
