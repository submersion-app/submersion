import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The default equipment view's statuses as one line (issue #2628), in enum
/// order so it reads the same as the checklist that edits it.
String equipmentDefaultStatusesLabel(
  Set<EquipmentStatus> statuses,
  AppLocalizations l10n,
) => [
  for (final s in EquipmentStatus.values)
    if (statuses.contains(s)) s.localizedName(l10n),
].join(l10n.settings_equipmentDefaultView_listSeparator);
