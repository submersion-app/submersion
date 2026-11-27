import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/services/backups_directory_access.dart';
import 'package:submersion/features/backup/data/services/orphaned_backup_scan.dart';
import 'package:submersion/features/backup/data/services/unrecognized_backup_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Scan and reclaim over the active backups directory.
final unrecognizedBackupServiceProvider = Provider<UnrecognizedBackupService>((
  ref,
) {
  final preferences = ref.watch(backupPreferencesProvider);
  final syncRepository = ref.watch(syncRepositoryProvider);

  return UnrecognizedBackupService(
    access: BackupsDirectoryAccess.live(preferences),
    knownPaths: () => knownPathsFromPreferences(preferences),
    thisDeviceId: syncRepository.getDeviceId,
  );
});

/// Backup files on disk that this device's history does not account for, or
/// null when the configured location cannot be enumerated.
///
/// Re-runs when the backup location changes. Each entry carries whether its
/// folder was private to the app, and a listing cached from the default folder
/// would otherwise keep offering another device's files after the diver
/// points backups at a shared one: every delete would be refused, after a
/// confirmation that called it safe.
final unrecognizedBackupsProvider = FutureProvider<List<UnrecognizedBackup>?>((
  ref,
) {
  ref.watch(backupSettingsProvider.select((s) => s.backupLocation));
  return ref.watch(unrecognizedBackupServiceProvider).find();
});
