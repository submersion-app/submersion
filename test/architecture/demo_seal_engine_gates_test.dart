import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Demo mode seals every way data could come in or go out (issue #3708).
///
/// The seal lives in the engine, not only the UI: each method below must
/// check `DemoModeGate.instance` before it does any work, so a timer, a
/// background task or a screen nobody thought of still cannot reach it.
/// `ensure` methods throw [DemoModeSealedException]; `quiet` ones are timer
/// or automatic paths that simply return.
///
/// A new import, export, backup, restore, sync or database-file entry point
/// belongs in this list.
enum _Kind { ensure, quiet }

const _gates = <(String, String, String, _Kind)>[
  // Cloud sync.
  (
    'lib/core/services/sync/sync_service.dart',
    'Future<SyncResult> performSync(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/features/settings/presentation/providers/sync_providers.dart',
    'Future<void> performSync(',
    'sync',
    _Kind.quiet,
  ),
  (
    'lib/core/services/sync/sync_service_replace_join.dart',
    'Future<ReplaceJoinResult> applyReplaceJoin(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/sync/replace_and_join_service.dart',
    'Future<ReplaceJoinResult> run(',
    'sync',
    _Kind.ensure,
  ),
  // Nearby sync (issue #3731): the radio, and the two applies a peer drives.
  (
    'lib/core/services/nearby/nearby_link_manager.dart',
    'Future<void> _refresh(',
    'sync',
    _Kind.quiet,
  ),
  (
    'lib/core/services/sync/sync_service.dart',
    'Future<NearbyApplyResult> applyNearbyPayload(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/sync/sync_service.dart',
    'Future<NearbyApplyResult> applyNearbyBaseFile(',
    'sync',
    _Kind.ensure,
  ),
  // Shared dive-site libraries.
  (
    'lib/core/services/shared_library/shared_library_service.dart',
    ' sync(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/core/services/shared_library/shared_site_publisher.dart',
    ' push(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/core/services/shared_library/shared_site_publisher.dart',
    ' deleteFromLibrary(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/core/services/shared_library/shared_site_publisher.dart',
    ' undelete(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/core/services/shared_library/suggestion_service.dart',
    ' propose(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/core/services/shared_library/suggestion_service.dart',
    ' accept(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/core/services/shared_library/suggestion_service.dart',
    ' dismiss(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/features/shared_library/presentation/providers/shared_library_sync_notifier.dart',
    ' syncAll(',
    'sharedLibrary',
    _Kind.quiet,
  ),
  (
    'lib/features/shared_library/presentation/providers/shared_library_sync_notifier.dart',
    ' syncOne(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/core/services/shared_library/backup/library_backup_service.dart',
    ' backUp(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/core/services/shared_library/backup/library_backup_service.dart',
    ' backUpIfDue(',
    'sharedLibrary',
    _Kind.quiet,
  ),
  (
    'lib/core/services/shared_library/backup/library_restore_service.dart',
    ' restore(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  (
    'lib/core/services/shared_library/backup/library_restore_service.dart',
    ' restoreInto(',
    'sharedLibrary',
    _Kind.ensure,
  ),
  // Backup.
  (
    'lib/features/backup/data/services/backup_service.dart',
    'Future<BackupRecord> performBackup(',
    'backup',
    _Kind.ensure,
  ),
  (
    'lib/features/backup/data/services/backup_service.dart',
    ' exportBackupToPath(',
    'backup',
    _Kind.ensure,
  ),
  (
    'lib/features/backup/data/services/backup_service.dart',
    ' exportBackupToTemp(',
    'backup',
    _Kind.ensure,
  ),
  (
    'lib/features/backup/presentation/providers/backup_providers.dart',
    'Future<void> _checkDesktopBackup(',
    'backup',
    _Kind.quiet,
  ),
  // Restore.
  (
    'lib/features/backup/data/services/backup_service.dart',
    ' restoreFromBackup(',
    'restore',
    _Kind.ensure,
  ),
  (
    'lib/features/backup/data/services/backup_service.dart',
    ' restoreFromFile(',
    'restore',
    _Kind.ensure,
  ),
  (
    'lib/features/backup/data/services/backup_service.dart',
    ' restoreFromDatabaseCopy(',
    'restore',
    _Kind.ensure,
  ),
  (
    'lib/core/services/database_service.dart',
    'Future<void> restore(',
    'restore',
    _Kind.ensure,
  ),
  // Imports and dive computer downloads.
  // Buddy cards received by any route (issue #3728).
  (
    'lib/features/buddies/data/services/buddy_card_importer.dart',
    'Future<Buddy> addNew(',
    'fileImport',
    _Kind.ensure,
  ),
  (
    'lib/features/buddies/data/services/buddy_card_importer.dart',
    'Future<Buddy> update(',
    'fileImport',
    _Kind.ensure,
  ),
  (
    'lib/features/import_wizard/presentation/providers/import_wizard_providers.dart',
    'Future<void> performImport(',
    'fileImport',
    _Kind.ensure,
  ),
  (
    'lib/features/universal_import/presentation/providers/universal_import_providers.dart',
    ' importFromGarminDevice(',
    'cloudImport',
    _Kind.ensure,
  ),
  (
    'lib/features/ocr_import/presentation/controllers/scan_flow_controller.dart',
    ' process(',
    'fileImport',
    _Kind.ensure,
  ),
  (
    'lib/features/dive_import/data/services/dive_resync_orchestrator.dart',
    ' resync(',
    'diveComputerDownload',
    _Kind.ensure,
  ),
  (
    'lib/features/dive_computer/presentation/providers/download_providers.dart',
    'Future<void> startDownload(',
    'diveComputerDownload',
    _Kind.ensure,
  ),
  // Media coming in or going to a store.
  (
    'lib/features/media/data/services/media_import_service.dart',
    ' importLocalFileForDive(',
    'mediaImport',
    _Kind.ensure,
  ),
  (
    'lib/features/media/data/services/media_import_service.dart',
    ' importPhotosForDive(',
    'mediaImport',
    _Kind.ensure,
  ),
  (
    'lib/features/media/data/services/media_import_service.dart',
    ' importPhotosForSite(',
    'mediaImport',
    _Kind.ensure,
  ),
  (
    'lib/features/media/data/services/local_file_link_service.dart',
    ' linkFileForDive(',
    'mediaImport',
    _Kind.ensure,
  ),
  // Exports and shares.
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' saveAndShareFile(',
    'share',
    _Kind.ensure,
  ),
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' saveAndShareFileBytes(',
    'share',
    _Kind.ensure,
  ),
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' shareFileAtPath(',
    'share',
    _Kind.ensure,
  ),
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' exportImageAsPng(',
    'export',
    _Kind.ensure,
  ),
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' sharePdfBytes(',
    'share',
    _Kind.ensure,
  ),
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' saveImageToPhotos(',
    'export',
    _Kind.ensure,
  ),
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' saveImageToFile(',
    'export',
    _Kind.ensure,
  ),
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' saveTextToFile(',
    'export',
    _Kind.ensure,
  ),
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' saveBytesToFile(',
    'export',
    _Kind.ensure,
  ),
  (
    'lib/core/services/export/shared/file_export_utils.dart',
    ' savePdfToFile(',
    'export',
    _Kind.ensure,
  ),
  // Device notifications: sample gear and documents never raise real
  // reminders.
  (
    'lib/features/notifications/data/services/notification_scheduler.dart',
    'Future<void> scheduleAll(',
    'notifications',
    _Kind.quiet,
  ),
  (
    'lib/features/notifications/data/services/notification_scheduler.dart',
    'Future<void> rescheduleAll(',
    'notifications',
    _Kind.quiet,
  ),
  (
    'lib/features/notifications/data/services/notification_scheduler.dart',
    'Future<void> updateForEquipment(',
    'notifications',
    _Kind.quiet,
  ),
  (
    'lib/features/notifications/data/services/notification_scheduler.dart',
    'Future<void> updateForDocument(',
    'notifications',
    _Kind.quiet,
  ),
  // Operations on the database file itself.
  (
    'lib/core/services/database_migration_service.dart',
    ' migrateToCustomFolder(',
    'databaseFile',
    _Kind.ensure,
  ),
  (
    'lib/core/services/database_migration_service.dart',
    ' migrateToDefault(',
    'databaseFile',
    _Kind.ensure,
  ),
  (
    'lib/core/services/database_migration_service.dart',
    ' switchToExistingDatabase(',
    'databaseFile',
    _Kind.ensure,
  ),
  (
    'lib/core/services/database_migration_service.dart',
    ' replaceExistingDatabase(',
    'databaseFile',
    _Kind.ensure,
  ),
  (
    'lib/core/services/database_service.dart',
    'Future<void> resetDatabase(',
    'databaseFile',
    _Kind.ensure,
  ),
  (
    'lib/core/services/security/database_security_service.dart',
    ' enableSecurity(',
    'databaseFile',
    _Kind.ensure,
  ),
  (
    'lib/core/services/security/database_security_service.dart',
    ' disableSecurity(',
    'databaseFile',
    _Kind.ensure,
  ),
  (
    'lib/core/services/security/database_security_service.dart',
    ' enableEncryption(',
    'databaseFile',
    _Kind.ensure,
  ),
  (
    'lib/core/services/security/database_security_service.dart',
    ' disableEncryption(',
    'databaseFile',
    _Kind.ensure,
  ),
  // Cloud storage backends: the backstop under every sync, backup and
  // shared-library path, for a caller nobody traced. Writes only; reads
  // cannot carry demo data out, and the Dropbox and Git createFolder only
  // compute a path.
  (
    'lib/core/services/cloud_storage/dropbox_storage_provider.dart',
    'Future<UploadResult> uploadFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/dropbox_storage_provider.dart',
    'Future<UploadResult> uploadFileFromPath(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/dropbox_storage_provider.dart',
    'Future<void> deleteFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/google_drive_storage_provider.dart',
    'Future<UploadResult> uploadFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/google_drive_storage_provider.dart',
    'Future<UploadResult> uploadFileFromPath(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/google_drive_storage_provider.dart',
    'Future<void> deleteFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/google_drive_storage_provider.dart',
    'Future<String> createFolder(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/s3_storage_provider.dart',
    'Future<UploadResult> uploadFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/s3_storage_provider.dart',
    'Future<UploadResult> uploadFileFromPath(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/s3_storage_provider.dart',
    'Future<void> deleteFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/s3_storage_provider.dart',
    'Future<String> createFolder(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/git_storage_provider.dart',
    'Future<UploadResult> uploadFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/git_storage_provider.dart',
    'Future<UploadResult> uploadFileFromPath(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/git_storage_provider.dart',
    'Future<void> deleteFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/icloud_storage_provider.dart',
    'Future<UploadResult> uploadFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/icloud_storage_provider.dart',
    'Future<UploadResult> uploadFileFromPath(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/icloud_storage_provider.dart',
    'Future<void> deleteFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/icloud_storage_provider.dart',
    'Future<String> createFolder(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/webdav_storage_provider.dart',
    'Future<UploadResult> uploadFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/webdav_storage_provider.dart',
    'Future<UploadResult> uploadFileFromPath(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/webdav_storage_provider.dart',
    'Future<void> deleteFile(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/webdav_storage_provider.dart',
    'Future<String> createFolder(',
    'sync',
    _Kind.ensure,
  ),
  (
    'lib/core/services/cloud_storage/git_storage_provider.dart',
    'Future<void> flush(',
    'sync',
    _Kind.ensure,
  ),
];

/// Providers that seal a whole subsystem by yielding nothing in demo mode:
/// the media store (its drain, verify and sweep would otherwise compare the
/// user's real store with the sample logbook).
const _providerGates = <(String, String)>[
  (
    'lib/features/media_store/presentation/providers/media_store_providers.dart',
    'attachedMediaObjectStoreProvider =',
  ),
];

/// The source of the method declared by [signature] in [code], from the
/// signature to the end of its body, or null when it is not declared there.
String? _methodSource(String code, String signature) {
  var from = 0;
  while (true) {
    final at = code.indexOf(signature, from);
    if (at < 0) return null;
    // A declaration, not a call: the text before it on its line is a return
    // type or modifiers, never an expression ending in `.`, `(`, `=` or
    // `await`.
    final lineStart = code.lastIndexOf('\n', at) + 1;
    final before = code.substring(lineStart, at).trim();
    final isCall =
        before.startsWith('//') ||
        before.endsWith('.') ||
        before.endsWith('(') ||
        before.endsWith('=') ||
        before.endsWith('await') ||
        before.endsWith('return') ||
        before.isEmpty && signature.startsWith(' ');
    if (!isCall) {
      final body = code.indexOf(RegExp(r'\{|=>'), _paramsEnd(code, at));
      final end = code.indexOf('\n  }\n', body);
      return code.substring(at, end < 0 ? code.length : end);
    }
    from = at + signature.length;
  }
}

int _paramsEnd(String code, int at) {
  var depth = 0;
  for (var i = code.indexOf('(', at); i < code.length; i++) {
    if (code[i] == '(') depth++;
    if (code[i] == ')' && --depth == 0) return i;
  }
  return code.length;
}

void main() {
  for (final (path, declaration) in _providerGates) {
    test('$path $declaration yields nothing in demo mode', () {
      final code = File(path).readAsStringSync();
      final at = code.indexOf(declaration);
      expect(at, isNonNegative, reason: 'declaration not found');
      final body = code.substring(at, at + 600);
      final gateAt = body.indexOf('if (DemoModeGate.instance.isActive) return');
      final firstAwait = body.indexOf(RegExp(r'\bawait\b'));
      expect(gateAt, isNonNegative);
      expect(gateAt < firstAwait, isTrue);
    });
  }

  for (final (path, signature, feature, kind) in _gates) {
    test('$path$signature is gated for $feature', () {
      final source = _methodSource(File(path).readAsStringSync(), signature);
      expect(source, isNotNull, reason: 'declaration not found');

      final gate = kind == _Kind.ensure
          ? 'DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.$feature)'
          : 'DemoModeGate.instance.isActive';
      final gateAt = source!.indexOf(gate);
      final firstAwait = source.indexOf(RegExp(r'\bawait\b'));
      expect(gateAt, isNonNegative, reason: 'no `$gate` in the method');
      expect(
        firstAwait < 0 || gateAt < firstAwait,
        isTrue,
        reason: 'the gate must come before the method does any work',
      );
    });
  }
}
