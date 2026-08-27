import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized display name for a [DiveMode] (e.g. "Open Circuit", "Gauge").
///
/// The exhaustive switch is compiler-checked, so a new [DiveMode] value forces
/// a corresponding localized string here.
String diveModeLabel(AppLocalizations l10n, DiveMode mode) => switch (mode) {
  DiveMode.oc => l10n.enum_diveMode_oc,
  DiveMode.ccr => l10n.enum_diveMode_ccr,
  DiveMode.scr => l10n.enum_diveMode_scr,
  DiveMode.gauge => l10n.enum_diveMode_gauge,
};
