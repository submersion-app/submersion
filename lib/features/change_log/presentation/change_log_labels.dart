import 'package:flutter/material.dart';

import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/domain/change_log_entities.dart';
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
};

/// A label the app stored by key, translated; any other is shown as written.
String changeLogStoredLabel(AppLocalizations l, String label) =>
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
      _ => label,
    };

/// What to call a kind of record when it has no name of its own.
String changeLogTableLabel(AppLocalizations l, String table) => switch (table) {
  'dives' => l.changeLog_dive,
  'settings' => l.changeLog_table_settings,
  'diver_settings' => l.changeLog_table_diverSettings,
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

/// When it happened and where it came from.
String changeLogSubtitle(
  AppLocalizations l,
  UnitFormatter units,
  ChangeLogOperation operation,
  Map<String, String> peerNames,
) {
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
  return '${units.formatTime(operation.endedAt)} · $origin';
}
