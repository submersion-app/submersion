import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for [ServiceCategory].
///
/// [ServiceCategory.displayName] stays hardcoded English on purpose: it is the
/// value written to spreadsheet exports, which are analysis targets rather
/// than UI surfaces. Only screens use this extension.
///
/// The switch is exhaustive rather than map-backed so that adding an enum
/// value is a compile error instead of a silent English fallback.
extension ServiceCategoryL10n on ServiceCategory {
  String label(AppLocalizations l10n) => switch (this) {
    ServiceCategory.annual => l10n.equipment_serviceCategory_annual,
    ServiceCategory.repair => l10n.equipment_serviceCategory_repair,
    ServiceCategory.inspection => l10n.equipment_serviceCategory_inspection,
    ServiceCategory.overhaul => l10n.equipment_serviceCategory_overhaul,
    ServiceCategory.replacement => l10n.equipment_serviceCategory_replacement,
    ServiceCategory.cleaning => l10n.equipment_serviceCategory_cleaning,
    ServiceCategory.calibration => l10n.equipment_serviceCategory_calibration,
    ServiceCategory.warranty => l10n.equipment_serviceCategory_warranty,
    ServiceCategory.recall => l10n.equipment_serviceCategory_recall,
    ServiceCategory.other => l10n.equipment_serviceCategory_other,
  };
}
