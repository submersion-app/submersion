import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/headless_cloud_provider.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

const String kNotificationRefreshTask = 'com.submersion.notificationRefresh';
const String kBackupTask = 'com.submersion.backup';

const _log = LoggerService('HeadlessDatabase');

/// Points the headless [DatabaseService] at the diver's ACTUAL database.
///
/// [DatabaseService] is a per-isolate singleton, so the Workmanager isolate
/// starts with no location service and `_resolveDatabasePath` falls back to
/// `<appDocuments>/Submersion/submersion.db`. For a diver who moved their
/// database, that fallback is not merely a wrong read: drift creates the file
/// on first statement, so a background run MANUFACTURES an empty database at
/// the default path, then backs it up and registers the artifact as a healthy
/// automatic backup (#1168).
///
/// The location is reconstructible here for the same reason
/// [resolveHeadlessCloudProvider] is: [DatabaseLocationService] is entirely
/// SharedPreferences-backed, and SharedPreferences crosses the isolate
/// boundary.
///
/// Returns false when the task must SKIP. A headless run never creates a
/// database and never falls back to the default path; falling back is what
/// produces the phantom. Two things make it skip:
///   * nothing at the resolved path (the diver has not launched the app at
///     this location yet), and
///   * a resolved path that cannot be opened for reading, above all a custom
///     folder behind a security-scoped bookmark (iOS/macOS) that a headless
///     isolate cannot re-acquire.
///
/// Note what it deliberately does NOT do: reset an unreachable custom location
/// to the default, which is the foreground's answer in
/// [DatabaseLocationService.validateCustomLocationAtStartup]. A background task
/// must not silently rewrite the diver's storage setting.
Future<bool> prepareHeadlessDatabaseLocation({
  required SharedPreferences prefs,
}) async {
  final location = DatabaseLocationService(prefs);
  final config = await location.getStorageConfig();

  // On iOS/macOS the custom folder is only reachable through the stored
  // bookmark. It may well fail to resolve headlessly; the readability probe
  // below is what decides, so a failure here is not fatal on its own.
  //
  // resolveStoredBookmark already swallows the native call, but its prefs read
  // sits outside that guard. Nothing in this function may escape: its contract
  // is to answer skip-or-proceed, and a throw would instead fail the task and
  // put it in Workmanager's retry queue.
  if (config.isCustomLocation) {
    try {
      await location.resolveStoredBookmark();
    } catch (e) {
      _log.info(
        'Headless bookmark resolution failed, letting the probe decide: $e',
      );
    }
  }

  final dbPath = await location.getDatabasePath();
  if (!await _isReadableDatabase(dbPath)) {
    _log.info(
      'Headless run skipped: no readable database at $dbPath '
      '(custom location: ${config.isCustomLocation}). Not creating one.',
    );
    return false;
  }

  DatabaseService.instance.adoptLocationService(location);
  return true;
}

/// Whether [dbPath] holds a file this isolate can actually read.
///
/// Existence alone is not enough: a security-scoped folder can be listed and
/// still refuse the open. This is the same probe
/// [DatabaseLocationService.validateCustomLocationAtStartup] uses.
Future<bool> _isReadableDatabase(String dbPath) async {
  RandomAccessFile? handle;
  try {
    handle = await File(dbPath).open(mode: FileMode.read);
    await handle.read(16);
    return true;
  } catch (_) {
    return false;
  } finally {
    // Close even when the read throws, or the handle leaks on every
    // background run that hits a revoked-permission folder. The close is
    // itself guarded because an exception raised in a finally block REPLACES
    // the value the try/catch settled on, which would turn "skip this run"
    // into "the task failed".
    try {
      await handle?.close();
    } catch (_) {
      // Nothing to do: the probe's answer is already decided.
    }
  }
}

/// Headless isolates have no unlock UI. Load the cached key (keychain) and
/// hand it to DatabaseService; when the database is encrypted and no cached
/// key exists (fresh device, keychain wipe), the task must SKIP — never
/// prompt, never open, never corrupt.
Future<bool> prepareHeadlessDatabaseKey({
  required SharedPreferences prefs,
}) async {
  final security = DatabaseSecurityService.instance;
  await security.configure(prefs: prefs);
  if (!security.encryptionEnabled) return true;
  final loaded = await security.tryLoadCachedKey();
  if (!loaded || security.databaseKeyHex == null) return false;
  DatabaseService.instance.databaseKeyHex = security.databaseKeyHex;
  return true;
}

/// Opens the database for a headless task, or reports that the task must skip.
///
/// The headless isolate is barred from running the schema upgrade ladder. It
/// has no progress UI, writes no pre-migration safety copy, and cannot report
/// a failure to the diver -- and worse, it would be running that ladder
/// against the same file as the foreground launch that is very probably
/// running it too, since Android reschedules overdue periodic work exactly
/// when the app is updated and reopened. Two isolates upgrading one file is
/// how a launch ends on "database is locked".
///
/// Skipping costs nothing: the task runs on its next turn, after a foreground
/// launch has done the upgrade properly.
Future<bool> openHeadlessDatabase({LoggerService? log}) async {
  try {
    await DatabaseService.instance.initialize(allowSchemaUpgrade: false);
    return true;
  } on SchemaUpgradePendingException catch (e) {
    (log ?? const LoggerService('BackgroundService')).info(
      'Background task skipped: the database needs a schema upgrade, which '
      'only a foreground launch may run ($e).',
    );
    return false;
  }
}

/// Callback for Workmanager background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    const log = LoggerService('BackgroundService');
    log.info('Background task started: $task');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Resolve WHICH database before unlocking one: a diver with a custom
      // location has no database at the default path, and opening there would
      // create one (#1168).
      final located = await prepareHeadlessDatabaseLocation(prefs: prefs);
      if (!located) {
        log.info(
          'Background task skipped: the configured database is not readable '
          'from this headless context.',
        );
        // "succeeded": a missing database is not a retryable error.
        return true;
      }

      final ready = await prepareHeadlessDatabaseKey(prefs: prefs);
      if (!ready) {
        log.info(
          'Background task skipped: database is encrypted and no cached '
          'key is available in this headless context.',
        );
        return true; // "succeeded" — do not retry-loop a locked database
      }

      // Opens the location adopted above, NOT the default path. The schema
      // version this reads has to come from the diver's own file, which is why
      // the location gate runs first.
      if (!await openHeadlessDatabase(log: log)) {
        return true; // "succeeded" — do not retry-loop a pending upgrade
      }

      // Initialize notification service
      await NotificationService.instance.initialize();

      if (task == kNotificationRefreshTask) {
        await _refreshNotifications(log);
      } else if (task == kBackupTask) {
        await runScheduledBackup(
          prefs: prefs,
          dbAdapter: DefaultBackupDatabaseAdapter(DatabaseService.instance),
          log: log,
        );
      }

      log.info('Background task completed: $task');
      return true;
    } catch (e, stackTrace) {
      log.error(
        'Background task failed: $task',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  });
}

Future<void> _refreshNotifications(LoggerService log) async {
  log.info('Refreshing notification schedule');

  final settingsRepository = DiverSettingsRepository();
  final equipmentRepository = EquipmentRepository();
  final scheduledNotificationRepository = ScheduledNotificationRepository();

  // Get the default diver's settings
  // In background, we use the most recently active diver
  final settings = await settingsRepository.getSettingsForDiver('default');
  if (settings == null || !settings.notificationsEnabled) {
    log.info('Notifications disabled, skipping refresh');
    return;
  }

  final scheduler = NotificationScheduler(
    notificationService: NotificationService.instance,
    equipmentRepository: equipmentRepository,
    scheduledNotificationRepository: scheduledNotificationRepository,
  );

  await scheduler.scheduleAll(settings: settings);
}

/// The [BackupService] the scheduled backup runs on.
///
/// Every store this reaches for is isolate-safe: SharedPreferences and secure
/// storage (credentials, both encryption keys). That is what lets a scheduled
/// backup honour the user's "Cloud Backup" switch -- for a long time this
/// isolate built a cloud-less service, so automatic backups silently stayed on
/// the device while the UI advertised cloud uploads (issue #969).
///
/// The two key stores are separately load-bearing:
///   * backup encryption -- when the flag is on, the artifact MUST be written
///     as an encrypted `.sbe`, otherwise `_activeBackupKey` fails closed and
///     the whole scheduled backup throws.
///   * sync encryption -- the cloud copy of an otherwise-plaintext backup is
///     framed before upload, exactly as the foreground path frames it, so
///     restore sees one artifact format regardless of who wrote it.
///
/// [instanceFor] is a test seam for the cloud-provider singletons.
Future<BackupService> buildScheduledBackupService({
  required SharedPreferences prefs,
  required BackupDatabaseAdapter dbAdapter,
  CloudStorageProvider Function(CloudProviderType type)? instanceFor,
}) async {
  // One store for both the provider wrap and the upload's framing, mirroring
  // the foreground's single encryptionKeyStoreProvider.
  final encryptionKeyStore = EncryptionKeyStore();
  return BackupService(
    dbAdapter: dbAdapter,
    preferences: BackupPreferences(prefs),
    cloudProvider: await resolveHeadlessCloudProvider(
      prefs: prefs,
      encryptionKeyStore: encryptionKeyStore,
      instanceFor: instanceFor,
    ),
    encryptionKeyStore: encryptionKeyStore,
    syncPreferences: SyncPreferences(prefs),
    backupEncryptionKeyStore: BackupEncryptionKeyStore(),
  );
}

/// How the scheduled backup reports its outcome. A seam over
/// [NotificationService.showBackupNotification] so the flow's decisions --
/// above all whether the cloud copy is missing -- are assertable without a
/// platform channel.
typedef BackupNotifier =
    Future<void> Function({
      required bool success,
      String? error,
      bool cloudCopyMissing,
    });

/// Run the scheduled backup if one is due, then report the outcome.
///
/// [notify] and [instanceFor] are seams for tests; production passes neither.
Future<void> runScheduledBackup({
  required SharedPreferences prefs,
  required BackupDatabaseAdapter dbAdapter,
  required LoggerService log,
  BackupNotifier? notify,
  CloudStorageProvider Function(CloudProviderType type)? instanceFor,
}) async {
  log.info('Checking if scheduled backup is due');

  final notifier =
      notify ?? NotificationService.instance.showBackupNotification;
  final settings = BackupPreferences(prefs).getSettings();

  if (!settings.enabled) {
    log.info('Automatic backups disabled, skipping');
    return;
  }

  if (!settings.isBackupDue) {
    log.info('Backup not yet due, skipping');
    return;
  }

  log.info('Backup is due, starting automatic backup');

  final service = await buildScheduledBackupService(
    prefs: prefs,
    dbAdapter: dbAdapter,
    instanceFor: instanceFor,
  );

  try {
    final record = await service.performBackup(isAutomatic: true);
    // The record's location is the only honest signal: the upload swallows
    // its own failures to protect the local artifact, so a cloud copy the
    // user asked for can be missing from an otherwise successful backup.
    final cloudCopyMissing =
        settings.cloudBackupEnabled && record.location == BackupLocation.local;
    log.info(
      'Automatic backup completed: ${record.filename} '
      '(location: ${record.location.name})',
    );
    await notifier(success: true, cloudCopyMissing: cloudCopyMissing);
  } catch (e, stack) {
    log.error('Automatic backup failed', error: e, stackTrace: stack);
    await notifier(success: false, error: e.toString());
  }
}

/// Initialize background task registration
Future<void> initializeBackgroundService() async {
  // Background service is mobile-only (iOS/Android)
  if (!Platform.isIOS && !Platform.isAndroid) {
    return;
  }

  await Workmanager().initialize(callbackDispatcher);

  // Register periodic task for notification refresh
  await Workmanager().registerPeriodicTask(
    'notification-refresh',
    kNotificationRefreshTask,
    frequency: const Duration(hours: 6), // Refresh every 6 hours
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
  );

  // Register periodic task for automatic backups
  // Checks every 12 hours; actual frequency managed by BackupSettings.isBackupDue
  await Workmanager().registerPeriodicTask(
    'backup-task',
    kBackupTask,
    frequency: const Duration(hours: 12),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: true,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: true,
    ),
  );
}
