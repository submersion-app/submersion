import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// [phase] as the gas consumption card names it, shared by everything that
/// names a phase of the dive (the card's rows, the pinned profile strip's
/// tooltip) so the two never disagree.
String divePhaseLabel(DivePhase phase, AppLocalizations l10n) =>
    switch (phase) {
      DivePhase.descent => l10n.diveLog_detail_sacSegments_phaseDescent,
      DivePhase.bottom => l10n.diveLog_detail_sacSegments_phaseBottom,
      DivePhase.ascent => l10n.diveLog_detail_sacSegments_phaseAscent,
      DivePhase.safetyStop => l10n.diveLog_detail_sacSegments_phaseSafetyStop,
      DivePhase.deco => l10n.diveLog_detail_sacSegments_phaseDeco,
    };
