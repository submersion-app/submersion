import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/change_log/domain/change_log_entities.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String changeLogSourceLabel(AppLocalizations l, ChangeLogSource source) =>
    switch (source) {
      ChangeLogSource.manual => l.changeLog_source_manual,
      ChangeLogSource.import => l.changeLog_source_import,
      ChangeLogSource.download => l.changeLog_source_download,
      ChangeLogSource.rule => l.changeLog_source_rule,
      ChangeLogSource.sync => l.changeLog_source_sync,
      ChangeLogSource.automatic => l.changeLog_source_automatic,
      ChangeLogSource.revert => l.changeLog_source_revert,
      ChangeLogSource.system => l.changeLog_source_system,
      ChangeLogSource.agent => l.changeLog_source_agent,
    };

IconData changeLogSourceIcon(ChangeLogSource source) => switch (source) {
  ChangeLogSource.manual => Icons.edit_outlined,
  ChangeLogSource.import => Icons.file_download_outlined,
  ChangeLogSource.download => Icons.watch_outlined,
  ChangeLogSource.rule => Icons.rule,
  ChangeLogSource.sync => Icons.sync,
  ChangeLogSource.automatic => Icons.auto_mode,
  ChangeLogSource.revert => Icons.undo,
  ChangeLogSource.system => Icons.settings_backup_restore,
  ChangeLogSource.agent => Icons.smart_toy_outlined,
};

/// A label the app stored by key, translated; any other is shown as written.
String changeLogStoredLabel(AppLocalizations l, String label) =>
    _recordEditLabel(l, label) ??
    switch (label) {
      ChangeLogLabels.bulkEdit => l.changeLog_label_bulkEdit,
      ChangeLogLabels.bulkDelete => l.changeLog_label_bulkDelete,
      ChangeLogLabels.deletedRecord => l.changeLog_label_deletedRecord,
      ChangeLogLabels.merge => l.changeLog_label_merge,
      ChangeLogLabels.undoMerge => l.changeLog_label_undoMerge,
      ChangeLogLabels.undoRule => l.changeLog_label_undoRule,
      ChangeLogLabels.qualityRepair => l.changeLog_label_qualityRepair,
      ChangeLogLabels.libraryAdopted => l.changeLog_label_libraryAdopted,
      ChangeLogLabels.libraryReplaced => l.changeLog_label_libraryReplaced,
      ChangeLogLabels.libraryRestored => l.changeLog_label_libraryRestored,
      ChangeLogLabels.reparse => l.changeLog_label_reparse,
      ChangeLogLabels.splitDive => l.changeLog_label_splitDive,
      ChangeLogLabels.gearTransfer => l.changeLog_label_gearTransfer,
      ChangeLogLabels.mediaRepair => l.changeLog_label_mediaRepair,
      ChangeLogLabels.gearFileConversion =>
        l.changeLog_label_gearFileConversion,
      ChangeLogLabels.galleryBackfill => l.changeLog_label_galleryBackfill,
      ChangeLogLabels.mediaCleanup => l.changeLog_label_mediaCleanup,
      ChangeLogLabels.accountMigration => l.changeLog_label_accountMigration,
      ChangeLogLabels.tableEditor => l.changeLog_label_tableEditor,
      ChangeLogLabels.removeSource => l.changeLog_label_removeSource,
      ChangeLogLabels.removeDuplicateCylinders =>
        l.changeLog_label_removeDuplicateCylinders,
      ChangeLogLabels.updatePlannedDives =>
        l.changeLog_label_updatePlannedDives,
      _ => label,
    };

/// The dive page's cards by id, which is the section's name. Built once:
/// the History list asks for a label for every row it draws.
final _diveSectionsByName = DiveDetailSectionId.values.asNameMap();

/// The site page's cards by id, as [_diveSectionsByName] is for a dive's.
final _siteSectionsByName = SiteDetailSectionId.values.asNameMap();

/// The title of the card [id] of a sitting on a record of [table], or [id]
/// as written when this version of the app has no title for it.
String _recordCardName(AppLocalizations l, String table, String id) =>
    switch (table) {
      // The dive page's header block is a card but not a section.
      'dives' when id == diveHeaderCardId => l.diveLog_detail_section_header,
      'dives' => _diveSectionsByName[id]?.localizedDisplayName(l) ?? id,
      // The site page's header block is a card but not a section too.
      'dive_sites' when id == siteHeaderCardId =>
        l.diveSites_detail_section_header,
      'dive_sites' => _siteSectionsByName[id]?.localizedDisplayName(l) ?? id,
      _ => id,
    };

/// "Edited: Notes, Tags" for the label of an editing sitting, naming each
/// card by its title, or "Edited" when it named none; null for any other
/// label. A card id with no title in this version of the app is shown as
/// written.
///
/// A sitting that [created] its record (a new dive, issue #4527) is already
/// read as Added: its cards are named alone, and none named reads as nothing.
String? _recordEditLabel(
  AppLocalizations l,
  String label, {
  bool created = false,
}) {
  final edit = RecordEditLabel.decode(label);
  if (edit == null) return null;
  if (edit.cardIds.isEmpty) return created ? null : l.changeLog_action_edited;
  // A photo's sitting reads apart from the dive's own cards: its entry sits
  // in the dive's History, where "Species" alone would read as the dive's.
  if (edit.table == 'media') {
    return l.changeLog_label_photoEdit(
      [
        for (final id in edit.cardIds) _photoChangeName(l, id),
      ].join(l.changeLog_label_recordEditSeparator),
    );
  }
  final cards = [
    for (final id in edit.cardIds) _recordCardName(l, edit.table, id),
  ];
  final named = cards.join(l.changeLog_label_recordEditSeparator);
  return created ? named : l.changeLog_label_recordEdit(named);
}

/// What a photo's sitting changed, by the id it is stored under; an id
/// this version of the app has no name for is shown as written.
String _photoChangeName(AppLocalizations l, String id) => switch (id) {
  photoSpeciesCardId => l.media_species_actionTooltip,
  photoPeopleCardId => l.media_editCard_people,
  photoTimeCardId => l.media_editCard_timeInDive,
  photoColorCardId => l.media_editCard_color,
  photoDetailsCardId => l.media_editCard_details,
  photoTagsCardId => l.media_info_tags,
  photoFileCardId => l.media_info_fileSection,
  _ => id,
};

/// What to call a kind of record when it has no name of its own.
String changeLogTableLabel(AppLocalizations l, String table) => switch (table) {
  'dives' => l.changeLog_dive,
  'settings' => l.changeLog_table_settings,
  'diver_settings' => l.changeLog_table_diverSettings,
  // Listed under a dive by its editing sitting (issue #4527), and with no
  // name of their own among the sync references.
  'dive_safety_findings' => l.changeLog_table_safetyFinding,
  'tank_pressure_series' => l.changeLog_table_pressureSeries,
  'nav_tracks' => l.changeLog_table_navTrack,
  // A dive's link to one of its types, named as the type it links.
  'dive_dive_types' => l.settings_conflict_ref_diveType,
  _ => conflictReferenceLabel(
    l,
    ConflictReference(
      field: '',
      targetType: changeLogEntityType(table),
      recordId: '',
    ),
  ),
};

/// The name of the one record an entry is about.
String changeLogRecordTitle(AppLocalizations l, ChangeLogOperation operation) {
  final table = operation.rootTable;
  if (table == null) return l.changeLog_title_changes;
  if (table == 'dives') {
    final number = operation.rootOrdinal?.toString();
    final site = operation.rootLabel;
    if (number != null && site != null) {
      return l.changeLog_dive_numberSite(number, site);
    }
    if (number != null) return l.changeLog_dive_number(number);
    return site ?? l.changeLog_dive;
  }
  return operation.rootLabel ?? changeLogTableLabel(l, table);
}

/// An entry's headline: its record, or for a bulk action what happened.
String changeLogTitle(AppLocalizations l, ChangeLogOperation operation) {
  final label = operation.label;
  if (operation.isSummary) {
    return label == null
        ? l.changeLog_title_changes
        : changeLogStoredLabel(l, label);
  }
  if (!operation.isBulk) return changeLogRecordTitle(l, operation);
  return switch (operation.source) {
    ChangeLogSource.import when label != null => l.changeLog_title_import(
      label,
    ),
    ChangeLogSource.download when label != null => l.changeLog_title_download(
      label,
    ),
    ChangeLogSource.sync => l.changeLog_title_sync,
    ChangeLogSource.rule => l.changeLog_title_rule,
    ChangeLogSource.revert => l.changeLog_title_revert,
    _ when label != null => changeLogStoredLabel(l, label),
    _ => l.changeLog_title_changes,
  };
}

/// When it happened and where it came from. [rootAction] is what the entry
/// did to the record it is titled with, when the caller knows it: a sitting
/// that inserted it names its cards without "Edited:".
String changeLogSubtitle(
  AppLocalizations l,
  UnitFormatter units,
  ChangeLogOperation operation,
  Map<String, String> peerNames, {
  ChangeLogAction? rootAction,
}) {
  final deviceId = operation.deviceId;
  final origin = switch (operation.source) {
    ChangeLogSource.sync => l.changeLog_syncedFrom(
      (deviceId == null ? null : peerNames[deviceId]) ??
          l.changeLog_anotherDevice,
    ),
    ChangeLogSource.manual => l.changeLog_thisDevice,
    ChangeLogSource.import || ChangeLogSource.download =>
      operation.label == null
          ? changeLogSourceLabel(l, operation.source)
          : changeLogStoredLabel(l, operation.label!),
    _ => changeLogSourceLabel(l, operation.source),
  };
  final label = operation.label;
  // A sitting on one record is titled by the record, so its label, which
  // names the cards it changed, is read here. A diver who sees only part of
  // it ([ChangeLogOperation.shownRoots]) is not told: the cards are about a
  // record they cannot open.
  final edited = label == null || operation.shownRoots != null
      ? null
      : _recordEditLabel(
          l,
          label,
          created: rootAction == ChangeLogAction.insert,
        );
  return [units.formatTime(operation.endedAt), origin, ?edited].join(' · ');
}
