import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

extension DiveRoleDisplay on DiveRole {
  /// Localized name for built-in roles; stored name for custom/synthetic.
  String localizedName(AppLocalizations l10n) {
    if (!isBuiltIn) return name;
    return switch (id) {
      DiveRole.buddyId => l10n.diveRole_builtin_buddy,
      DiveRole.diveGuideId => l10n.diveRole_builtin_diveGuide,
      DiveRole.instructorId => l10n.diveRole_builtin_instructor,
      DiveRole.studentId => l10n.diveRole_builtin_student,
      DiveRole.diveMasterId => l10n.diveRole_builtin_diveMaster,
      DiveRole.soloId => l10n.diveRole_builtin_solo,
      DiveRole.rearGuardId => l10n.diveRole_builtin_rearGuard,
      DiveRole.supportDiverId => l10n.diveRole_builtin_supportDiver,
      DiveRole.safetyDiverId => l10n.diveRole_builtin_safetyDiver,
      _ => name,
    };
  }
}
