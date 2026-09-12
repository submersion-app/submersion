import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

extension ObservationTagDisplay on ObservationTag {
  String localizedName(AppLocalizations l10n) => switch (this) {
    ObservationTag.freeFlow => l10n.equipmentObservation_tag_freeFlow,
    ObservationTag.hardBreathing => l10n.equipmentObservation_tag_hardBreathing,
    ObservationTag.wetBreathing => l10n.equipmentObservation_tag_wetBreathing,
    ObservationTag.leak => l10n.equipmentObservation_tag_leak,
    ObservationTag.hoseDamage => l10n.equipmentObservation_tag_hoseDamage,
    ObservationTag.inflatorStuck => l10n.equipmentObservation_tag_inflatorStuck,
    ObservationTag.inflatorSlow => l10n.equipmentObservation_tag_inflatorSlow,
    ObservationTag.bladderLeak => l10n.equipmentObservation_tag_bladderLeak,
    ObservationTag.dumpLeak => l10n.equipmentObservation_tag_dumpLeak,
    ObservationTag.leakNeck => l10n.equipmentObservation_tag_leakNeck,
    ObservationTag.leakWrist => l10n.equipmentObservation_tag_leakWrist,
    ObservationTag.leakZip => l10n.equipmentObservation_tag_leakZip,
    ObservationTag.leakBoot => l10n.equipmentObservation_tag_leakBoot,
    ObservationTag.leakValve => l10n.equipmentObservation_tag_leakValve,
    ObservationTag.leakSeam => l10n.equipmentObservation_tag_leakSeam,
    ObservationTag.tear => l10n.equipmentObservation_tag_tear,
    ObservationTag.seamFailure => l10n.equipmentObservation_tag_seamFailure,
    ObservationTag.dim => l10n.equipmentObservation_tag_dim,
    ObservationTag.died => l10n.equipmentObservation_tag_died,
    ObservationTag.flooded => l10n.equipmentObservation_tag_flooded,
    ObservationTag.switchFault => l10n.equipmentObservation_tag_switchFault,
    ObservationTag.batteryLow => l10n.equipmentObservation_tag_batteryLow,
    ObservationTag.screenFault => l10n.equipmentObservation_tag_screenFault,
    ObservationTag.connectionFault =>
      l10n.equipmentObservation_tag_connectionFault,
    ObservationTag.dropout => l10n.equipmentObservation_tag_dropout,
    ObservationTag.cellWarning => l10n.equipmentObservation_tag_cellWarning,
    ObservationTag.loopLeak => l10n.equipmentObservation_tag_loopLeak,
    ObservationTag.solenoidFault => l10n.equipmentObservation_tag_solenoidFault,
    ObservationTag.scrubberBreakthrough =>
      l10n.equipmentObservation_tag_scrubberBreakthrough,
    ObservationTag.slowResponse => l10n.equipmentObservation_tag_slowResponse,
    ObservationTag.erratic => l10n.equipmentObservation_tag_erratic,
    ObservationTag.lowCapacity => l10n.equipmentObservation_tag_lowCapacity,
    ObservationTag.propFault => l10n.equipmentObservation_tag_propFault,
    ObservationTag.strapBroke => l10n.equipmentObservation_tag_strapBroke,
    ObservationTag.other => l10n.equipmentObservation_tag_other,
  };
}

extension ObservationDisplay on EquipmentObservation {
  /// A row title: the issue tags, or the status when there are none. An
  /// issue can arrive with no tags, because tag names written by a newer
  /// build are dropped on read, and a blank title would hide the row.
  String displayTitle(AppLocalizations l10n) => isIssue && issueTags.isNotEmpty
      ? issueTags.map((t) => t.localizedName(l10n)).join(', ')
      : status.localizedName(l10n);

  /// The note on a single line, for a summary row. Empty when there is no
  /// note.
  String get noteSummary => note.trim().split(RegExp(r'\s+')).join(' ');
}

extension ObservationStatusDisplay on ObservationStatus {
  String localizedName(AppLocalizations l10n) => switch (this) {
    ObservationStatus.ok => l10n.equipmentObservation_status_ok,
    ObservationStatus.issue => l10n.equipmentObservation_status_issue,
  };
}
