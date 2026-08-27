import 'dart:async' show Completer, unawaited;
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/app.dart' show resolveAppLocale;
import 'package:submersion/app.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_engine_preflight.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/domain/entities/migration_progress.dart';
import 'package:submersion/core/presentation/pages/lock_escape_dialogs.dart';
import 'package:submersion/core/presentation/pages/lock_screen_view.dart';
import 'package:submersion/core/presentation/startup_brightness.dart';
import 'package:submersion/core/presentation/startup_failure.dart';
import 'package:submersion/core/presentation/widgets/backup_status_views.dart';
import 'package:submersion/core/presentation/widgets/ocean_background.dart';
import 'package:submersion/core/presentation/widgets/startup_failure_view.dart';
import 'package:submersion/core/presentation/widgets/version_mismatch_view.dart';
import 'package:submersion/core/services/accounts/account_deduplicator.dart';
import 'package:submersion/core/services/accounts/account_startup_migration.dart';
import 'package:submersion/core/services/background_service.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/security/biometric_service.dart';
import 'package:submersion/core/services/security/database_locked_exception.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/security/locked_database_escape.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/core/utils/app_version.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backup_target.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_orphan_backlog_sweep.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/main.dart' show SubmersionRestart;

/// Callback signature for the service initializer used by [StartupWrapper].
///
/// Receives a migration-progress callback so the initializer can report
/// step-by-step progress to the UI.
typedef ServiceInitializer =
    Future<void> Function(
      void Function(int currentStep, int totalSteps) onMigrationProgress,
    );

/// Callback signature for the schema-version probe used by [StartupWrapper]
/// to decide whether to show a migration progress bar before opening the DB.
typedef SchemaVersionProbe =
    ({bool needsMigration, int totalSteps}) Function(String dbPath);

/// Runs [step], measuring its wall time, and prints a
/// `[startup] <name>: <ms>ms` attribution line in debug/profile builds.
///
/// A top-level function (rather than a private closure) so the real startup
/// call sites in [StartupWrapper] and unit tests can both reach it; at those
/// call sites it wraps platform singletons that only run during app launch.
/// [log] defaults to `!kReleaseMode` and is injectable so tests can exercise
/// both branches.
Future<void> timeStartupStep(
  String name,
  Future<void> Function() step, {
  bool log = !kReleaseMode,
}) async {
  final sw = Stopwatch()..start();
  await step();
  sw.stop();
  if (log) {
    debugPrint('[startup] $name: ${sw.elapsedMilliseconds}ms');
  }
}

enum _StartupState {
  initializing,
  locked,
  backingUp,
  migrating,
  backupFailed,
  recoveryRequired,
  recovering,
  recoveryFailed,
  ready,
  error,
}

class StartupWrapper extends StatefulWidget {
  final SharedPreferences prefs;
  final LogFileService logFileService;
  final DatabaseLocationService locationService;

  /// Optional override for the service initializer (used in tests).
  @visibleForTesting
  final ServiceInitializer? initializerOverride;

  /// Optional override for the schema-version probe (used in tests).
  @visibleForTesting
  final SchemaVersionProbe? schemaVersionProbeOverride;

  /// Optional override for the app-close callback (used in tests).
  @visibleForTesting
  final VoidCallback? closeAppOverride;

  /// Optional override for the pre-migration backup service factory (tests).
  @visibleForTesting
  final PreMigrationBackupService Function({
    required String livePath,
    required BackupPreferences preferences,
  })?
  preMigrationBackupFactory;

  /// Optional override for the database engine preflight (used in tests to
  /// simulate a build whose native library does not resolve).
  @visibleForTesting
  final void Function()? enginePreflightOverride;

  /// Optional override for the in-place restore offered by the failure screen
  /// (used in tests, which must not swap real database files).
  @visibleForTesting
  final Future<void> Function(
    String backupPath,
    void Function(int currentStep, int totalSteps) onMigrationProgress,
  )?
  restoreOverride;

  const StartupWrapper({
    super.key,
    required this.prefs,
    required this.logFileService,
    required this.locationService,
    this.initializerOverride,
    this.schemaVersionProbeOverride,
    this.closeAppOverride,
    this.preMigrationBackupFactory,
    this.enginePreflightOverride,
    this.restoreOverride,
  });

  @override
  State<StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends State<StartupWrapper>
    with SingleTickerProviderStateMixin {
  _StartupState _state = _StartupState.initializing;
  MigrationProgress _progress = const MigrationProgress(
    currentStep: 0,
    totalSteps: 0,
  );
  String _errorMessage = '';
  bool _isVersionMismatch = false;
  int _dbVersion = 0;
  int _appVersion = 0;
  BackupFailedException? _backupError;
  sqlite3.SqliteException? _readonlyError;

  /// How far startup had got. Drives [classifyStartupFailure]: the same
  /// exception means different things depending on what was running.
  StartupPhase _phase = StartupPhase.preflight;

  /// Which class of failure the terminal error screen is reporting.
  StartupFailureKind _failureKind = StartupFailureKind.unknown;

  /// A backup the diver could swap in, discovered after the failure. Null
  /// until [_loadRecoveryOptions] finds one (and never loaded at all for an
  /// engine failure, where no restore can help).
  BackupRecord? _recoveryBackup;

  /// Directory holding [_recoveryBackup], shown so the diver can reach their
  /// backups by hand. Backup *settings* are unreachable from the splash: it
  /// runs before the router and the database exist.
  String? _backupsDirectory;

  StartupRestoreStatus _restoreStatus = StartupRestoreStatus.idle;
  String? _restoreError;

  /// Completed by the unlock handlers to resume [_runInitialization] past
  /// the lock gate.
  Completer<void>? _unlockCompleter;
  bool _biometricAvailable = false;

  /// Navigator key for the splash MaterialApp, so the escape-hatch dialogs
  /// (Task: recovery code / start fresh) have a dialog-capable context.
  final GlobalKey<NavigatorState> _splashNavigatorKey =
      GlobalKey<NavigatorState>();

  /// Drives the dissolve of the splash layer over the mounted app beneath.
  /// Forward-only; starts when _state first reaches ready.
  late final AnimationController _splashFadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  /// True once the fade completes, at which point the splash widget is
  /// dropped from the tree entirely.
  bool _splashRemoved = false;

  @override
  void initState() {
    super.initState();
    _splashFadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // coverage:ignore-start
        if (!kReleaseMode) {
          debugPrint('[startup] splash fade complete');
        }
        // coverage:ignore-end
        setState(() => _splashRemoved = true);
      }
    });
    _runInitialization();
  }

  @override
  void dispose() {
    _splashFadeController.dispose();
    super.dispose();
  }

  Future<void> _runInitialization() async {
    try {
      _phase = StartupPhase.preflight;

      // Prove the database engine works before ANY user file is touched.
      // In-memory only, so a failure here provably left the diver's data
      // alone and can say so, instead of being misattributed to whichever
      // step happened to be running (issue #1129: a Windows build shipped
      // without sqlcipher.dll and the app reported a failed upgrade).
      (widget.enginePreflightOverride ?? assertDatabaseEngineAvailable)();

      // Determine if migration is needed before opening the database
      final dbPath = await widget.locationService.getDatabasePath();

      // App Security gate: must resolve BEFORE the schema probe below, which
      // needs the cipher key to read an encrypted file.
      await _resolveSecurityGate(dbPath);

      final int? storedVersion;
      final bool needsMigration;
      final int totalSteps;

      if (widget.schemaVersionProbeOverride != null) {
        final probe = widget.schemaVersionProbeOverride!(dbPath);
        needsMigration = probe.needsMigration;
        totalSteps = probe.totalSteps;
        storedVersion =
            null; // probe path doesn't expose storedVersion; backup uses 0 default
      } else {
        storedVersion = DatabaseService.getStoredSchemaVersion(
          dbPath,
          keyHex: DatabaseService.instance.databaseKeyHex,
        );
        final sv = storedVersion;
        needsMigration =
            sv != null && sv > 0 && sv < AppDatabase.currentSchemaVersion;
        totalSteps = needsMigration ? AppDatabase.migrationStepCount(sv) : 0;
      }

      if (needsMigration) {
        if (mounted) {
          setState(() => _state = _StartupState.backingUp);
        }
        try {
          await _runPreMigrationBackup(
            dbPath: dbPath,
            stored: storedVersion ?? 0,
          );
        } on BackupFailedException catch (e) {
          if (mounted) {
            setState(() {
              _state = _StartupState.backupFailed;
              _backupError = e;
            });
          }
          return;
        }
        _phase = StartupPhase.upgrading;
        if (mounted) {
          setState(() {
            _state = _StartupState.migrating;
            _progress = MigrationProgress(
              currentStep: 0,
              totalSteps: totalSteps,
            );
          });
        }
      } else {
        _phase = StartupPhase.opening;
      }

      // Run DB init and minimum splash duration in parallel
      await Future.wait([
        _initializeServices(),
        Future.delayed(const Duration(seconds: 1)),
      ]);

      if (mounted) {
        // coverage:ignore-start
        final readyAt = Stopwatch()..start();
        if (!kReleaseMode) {
          debugPrint('[startup] ready; building app under splash');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint(
              '[startup] first frame after ready: '
              '${readyAt.elapsedMilliseconds}ms',
            );
          });
        }
        // coverage:ignore-end
        setState(() => _state = _StartupState.ready);
        _splashFadeController.forward();
      }
    } on DatabaseVersionMismatchException catch (e) {
      if (mounted) {
        setState(() {
          _state = _StartupState.error;
          _isVersionMismatch = true;
          _dbVersion = e.storedSchemaVersion;
          _appVersion = e.supportedSchemaVersion;
        });
      }
    } on DatabaseLockedException {
      // The cached/typed key did not open the file (e.g. a keychain restored
      // from another device). Fall back to the password prompt — the sidecar
      // is authoritative and unlockWithSecret re-derives from it — then
      // retry initialization from the top.
      _unlockCompleter = Completer<void>();
      if (mounted) setState(() => _state = _StartupState.locked);
      await _unlockCompleter!.future;
      if (mounted) {
        setState(() => _state = _StartupState.initializing);
        await _runInitialization();
      }
    } on sqlite3.SqliteException catch (e) {
      if (DatabaseService.isRecoverableReadonlyError(e)) {
        debugPrint(
          'Startup hit SQLITE_READONLY (code ${e.extendedResultCode}); '
          'offering hot-journal recovery.',
        );
        if (mounted) {
          setState(() {
            _state = _StartupState.recoveryRequired;
            _readonlyError = e;
          });
        }
      } else {
        _enterFailureState(e);
      }
    } catch (e) {
      _enterFailureState(e);
    }
  }

  /// Routes a terminal startup failure to the error screen under the class it
  /// actually belongs to, and starts looking for a way out.
  ///
  /// Before issue #1134 every failure landed here under the fixed title
  /// "Database upgrade failed", which was wrong in both directions: it told
  /// divers their upgrade failed when the database had never been opened, and
  /// it pointed diagnosis at migration code.
  void _enterFailureState(Object error) {
    final kind = classifyStartupFailure(error, _phase);
    debugPrint('FATAL: App initialization failed (${kind.name}): $error');
    if (!mounted) return;
    setState(() {
      _state = _StartupState.error;
      _failureKind = kind;
      _errorMessage = '$error';
    });
    unawaited(_loadRecoveryOptions());
  }

  /// Resolves the App Security gate before any database access.
  ///
  /// - App Lock on: show the lock screen and wait for a successful unlock.
  /// - Encryption on, App Lock off: load the cached key silently; only a
  ///   missing cached key (new device, keychain wipe) shows the prompt —
  ///   the database is physically unopenable without it.
  /// - Both off: no-op.
  ///
  /// Also self-heals a flag/file mismatch: the file header is the truth
  /// (an interrupted enable/disable or restored prefs can disagree).
  Future<void> _resolveSecurityGate(String dbPath) async {
    final security = DatabaseSecurityService.instance;
    await security.configure(prefs: widget.prefs);

    final fileEncrypted = isEncryptedDatabaseFile(dbPath);
    if (!fileEncrypted && security.encryptionEnabled) {
      // Interrupted disable-encryption run: the file is plaintext, the flag
      // is stale. The file wins.
      await security.preferences.setDbEncryptionEnabled(false);
      await security.refreshDerivedKey();
    } else if (fileEncrypted && !security.encryptionEnabled) {
      // Encrypted-LOOKING file with the flag off. A corrupt plaintext
      // database has the same non-SQLite header, so only conclude
      // "interrupted enable-encryption" when the keyslot sidecar is present
      // to corroborate it (enableSecurity always writes one and it travels
      // with the database); otherwise leave the file to the existing
      // corruption-recovery flow.
      if (DatabaseSecuritySidecar.existsFor(dbPath)) {
        await security.preferences.setDbEncryptionEnabled(true);
        await security.refreshDerivedKey();
      }
    }

    if (security.appLockEnabled || security.encryptionEnabled) {
      final cached = await security.tryLoadCachedKey();
      final mustPrompt =
          security.appLockEnabled || (security.encryptionEnabled && !cached);
      if (mustPrompt) {
        _biometricAvailable =
            cached &&
            security.preferences.appLockBiometricsEnabled &&
            await BiometricService().isAvailable();
        _unlockCompleter = Completer<void>();
        if (mounted) setState(() => _state = _StartupState.locked);
        await _unlockCompleter!.future;
        if (mounted) setState(() => _state = _StartupState.initializing);
      }
    }

    // Sidecar self-heal: unlocked via the cached key but the durable wrapped
    // copy is gone (deleted, excluded from a folder sync, ...). Rebuild it
    // now — the cached key is the only unlock left, and losing it too would
    // strand the database permanently. Declining just reoffers next launch.
    if ((security.appLockEnabled || security.encryptionEnabled) &&
        security.isUnlocked &&
        !DatabaseSecuritySidecar.existsFor(dbPath)) {
      final ctx = _splashNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        String? newCode;
        final repaired = await showSidecarRepairDialog(
          ctx,
          onSubmit: (password) async {
            try {
              newCode = await security.rebuildSidecar(
                password: password,
                dbPath: dbPath,
              );
              return true;
            } catch (_) {
              return false;
            }
          },
        );
        final codeCtx = _splashNavigatorKey.currentContext;
        if (repaired == true &&
            newCode != null &&
            codeCtx != null &&
            codeCtx.mounted) {
          await showNewRecoveryCodeDialog(codeCtx, newCode!);
        }
      }
    }

    DatabaseService.instance.databaseKeyHex = security.databaseKeyHex;
  }

  /// The last secret (password OR recovery code) that successfully unwrapped
  /// the Master Key this session. Needed by the forced password reset after
  /// a recovery-code unlock (changePassword requires the current secret).
  String? _lastAcceptedSecret;

  /// Unlocks without completing the gate — the recovery-code dialog uses
  /// this so the forced password reset can finish BEFORE startup proceeds
  /// (the splash layer, and any dialog on it, is torn down at ready).
  Future<bool> _unlockSecretOnly(String secret) async {
    final security = DatabaseSecurityService.instance;
    final dbPath = await widget.locationService.getDatabasePath();
    final ok = await security.unlockWithSecret(secret, dbPath: dbPath);
    if (ok) _lastAcceptedSecret = secret;
    return ok;
  }

  Future<bool> _unlockWithPassword(String secret) async {
    final ok = await _unlockSecretOnly(secret);
    if (ok) _unlockCompleter?.complete();
    return ok;
  }

  Future<void> _handleRecoveryUnlock() async {
    final ctx = _splashNavigatorKey.currentContext;
    if (ctx == null) return;
    final ok = await showRecoveryCodeUnlockDialog(
      ctx,
      onSubmit: _unlockSecretOnly,
    );
    if (ok != true) return;
    // Recovery implies the password is lost: force a new one before
    // continuing (per spec), while the splash layer is still mounted.
    final resetCtx = _splashNavigatorKey.currentContext;
    final currentSecret = _lastAcceptedSecret;
    if (resetCtx != null && resetCtx.mounted && currentSecret != null) {
      await showForcedPasswordResetDialog(
        resetCtx,
        onSubmit: (newPassword) async {
          final dbPath = await widget.locationService.getDatabasePath();
          await DatabaseSecurityService.instance.changePassword(
            currentSecret: currentSecret,
            newPassword: newPassword,
            dbPath: dbPath,
          );
        },
      );
    }
    _unlockCompleter?.complete();
  }

  Future<void> _handleStartFresh() async {
    final ctx = _splashNavigatorKey.currentContext;
    if (ctx == null) return;
    final confirmed = await showStartFreshConfirmDialog(ctx);
    if (confirmed != true) return;
    final dbPath = await widget.locationService.getDatabasePath();
    await setAsideLockedDatabase(dbPath: dbPath, prefs: widget.prefs);
    await DatabaseSecurityService.instance.clearInMemoryState();
    DatabaseService.instance.databaseKeyHex = null;
    // Resume initialization: the database file is gone, so a fresh empty
    // database is created and the first-run wizard takes over.
    _unlockCompleter?.complete();
  }

  Future<bool> _unlockWithBiometric() async {
    // The lock screen lives inside the splash MaterialApp, so the splash
    // navigator's context is the one carrying Localizations here; this
    // State's own context sits above that MaterialApp and has none.
    final promptCtx = _splashNavigatorKey.currentContext;
    final ok = await BiometricService().authenticate(
      reason: promptCtx == null
          ? 'Unlock your dive log'
          : AppLocalizations.of(promptCtx).lock_biometric_reason,
    );
    if (ok) _unlockCompleter?.complete();
    return ok;
  }

  /// Attempt to recover the database from a hot-journal-readonly error by
  /// reopening in read-write mode (which forces SQLite to finish the
  /// rollback), then retry initialization from the top.
  Future<void> _runRecovery() async {
    if (!mounted) return;
    setState(() {
      _state = _StartupState.recovering;
      // Clear any stale text from a prior failed attempt so the
      // recoveryFailed UI reflects only the current reason.
      _errorMessage = '';
    });
    try {
      final dbPath = await widget.locationService.getDatabasePath();
      final recovered = DatabaseService.recoverHotJournal(
        dbPath,
        keyHex: DatabaseService.instance.databaseKeyHex,
      );
      if (!recovered) {
        if (mounted) {
          setState(() {
            _state = _StartupState.recoveryFailed;
            _errorMessage =
                'SQLite could not reopen the database to roll back the '
                'interrupted transaction.';
          });
        }
        return;
      }
      await _runInitialization();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _StartupState.recoveryFailed;
          _errorMessage = '$e';
        });
      }
    }
  }

  /// Leaves [StartupPhase.upgrading] now that the schema ladder is no longer
  /// in flight.
  ///
  /// Everything after the ladder is ordinary service startup, so a failure
  /// there must not be reported as a failed database upgrade. Observed at two
  /// points because neither alone is sufficient: the ladder's final progress
  /// report is the precise instant it finishes and is the one a test can
  /// drive, while the return of `initialize()` is the backstop that still
  /// holds if the reported step count ever drifts from the ladder's real one.
  void _markUpgradeFinished() {
    _phase = StartupPhase.opening;
  }

  Future<void> _initializeServices() async {
    void onProgress(int currentStep, int totalSteps) {
      // reportProgress() in the migration ladder increments BEFORE it calls
      // back, so the final report means the last step already completed.
      if (totalSteps > 0 && currentStep >= totalSteps) {
        _markUpgradeFinished();
      }
      if (mounted) {
        setState(() {
          _progress = MigrationProgress(
            currentStep: currentStep,
            totalSteps: totalSteps,
          );
        });
      }
    }

    if (widget.initializerOverride != null) {
      await widget.initializerOverride!(onProgress);
      return;
    }

    // Real service bootstrap. Each step wraps a platform singleton or a real
    // database, so this block runs during app launch rather than unit tests
    // (cf. the coverage-ignored bootstrap in lib/main.dart). The wall-time
    // attribution itself lives in the unit-tested [timeStartupStep].
    // coverage:ignore-start
    await timeStartupStep(
      'database',
      () => DatabaseService.instance.initialize(
        locationService: widget.locationService,
        onMigrationProgress: onProgress,
      ),
    );

    // Backstop for the same rule the final progress report already applies:
    // whatever the ladder reported, it is finished once initialize() returns.
    _markUpgradeFinished();

    await timeStartupStep(
      'localCache',
      LocalCacheDatabaseService.instance.initialize,
    );
    await timeStartupStep('accountMigration', () async {
      final prefs = await SharedPreferences.getInstance();
      await AccountStartupMigration(prefs: prefs).run();
      // After the migration, so rows it seeds are already at their
      // deterministic ids and the pass finds nothing to do on a fresh
      // install. Both swallow their own errors: neither can block startup.
      await AccountDeduplicator(prefs: prefs).run();
    });
    await timeStartupStep(
      'notifications',
      NotificationService.instance.initialize,
    );
    await timeStartupStep('backgroundService', initializeBackgroundService);

    await timeStartupStep('tileCache', () async {
      try {
        await TileCacheService.instance.initialize();
      } catch (e) {
        debugPrint('Warning: Tile cache initialization failed: $e');
      }
    });

    await timeStartupStep('speciesSeed', () async {
      final speciesRepository = SpeciesRepository();
      await speciesRepository.seedBuiltInSpecies();
    });

    // Unlinked-media sweep, every launch. Fire-and-forget: it must not delay
    // first frame and runs against the now-open databases. Empty on a
    // healthy library; catches anything a not-yet-upgraded peer syncs in.
    final mediaRepository = MediaRepository();
    final sweep = MediaOrphanBacklogSweep(
      mediaRepository: mediaRepository,
      coordinator: MediaDeletionCoordinator(
        mediaRepository: mediaRepository,
        queue: () => MediaTransferQueueRepository(),
      ),
    );
    // An async closure rather than `.catchError` on the Future<int>: it
    // hands `unawaited` a genuine Future<void> instead of a swept-row count
    // nobody reads, and it keeps the stack trace. Nothing surfaces this
    // failure to the user and the retry is a whole launch away, so the
    // trace is the only diagnostic there will be. Untyped catch on purpose:
    // an uninitialized local cache database throws StateError, not
    // Exception, and a failed sweep must never take down startup.
    unawaited(() async {
      try {
        await sweep.run();
      } catch (e, stackTrace) {
        debugPrint(
          'Orphaned-media backlog sweep failed (will retry): $e\n$stackTrace',
        );
      }
    }());
    // coverage:ignore-end
  }

  Future<void> _runPreMigrationBackup({
    required String dbPath,
    required int stored,
  }) async {
    assert(
      widget.schemaVersionProbeOverride == null ||
          widget.preMigrationBackupFactory != null,
      'When schemaVersionProbeOverride is set in tests, you must also supply '
      'preMigrationBackupFactory — otherwise the pre-migration backup will '
      'run with stored=0 and attempt a real file copy against the production '
      'database path.',
    );

    final prefs = BackupPreferences(widget.prefs);

    final PreMigrationBackupService service;
    final String appVersion;
    BackupDirLease? lease;
    if (widget.preMigrationBackupFactory != null) {
      service = widget.preMigrationBackupFactory!(
        livePath: dbPath,
        preferences: prefs,
      );
      appVersion = '0.0.0.0';
    } else {
      final info = await PackageInfo.fromPlatform();
      appVersion = formatAppVersion(info);
      service = PreMigrationBackupService(
        livePathProvider: () async => dbPath,
        // Resolve LAZILY, inside the provider. Resolution arms any
        // security-scoped bookmark for the custom location and self-heals a
        // dead one to the sandbox default, but it also touches the filesystem
        // and can throw (an ejected volume, or a location that is no longer
        // creatable). PreMigrationBackupService calls this provider inside the
        // region guarded by fallbackBackupsDirProvider, so resolving here keeps
        // any failure recoverable. Resolving eagerly instead would move the
        // throw outside that guard, where it escapes as a bare
        // FileSystemException rather than a BackupFailedException and strands
        // startup on the terminal "Database upgrade failed" screen. Keeping it
        // lazy is what makes "a pre-migration backup can never brick startup"
        // actually hold.
        backupsDirProvider: () async {
          lease = await BackupService.resolveBackupsDirectoryLeased(prefs);
          return lease!.path;
        },
        fallbackBackupsDirProvider:
            BackupService.resolveDefaultBackupsDirectory,
        preferences: prefs,
        // The security gate has already run, so this is the live key when
        // protection is on. Needed only to open the database for the
        // pre-copy WAL checkpoint.
        databaseKeyHexProvider: () => DatabaseService.instance.databaseKeyHex,
      );
    }

    try {
      await service.backupIfMigrationPending(
        stored: stored,
        target: AppDatabase.currentSchemaVersion,
        appVersion: appVersion,
      );
    } finally {
      await lease?.release();
    }
  }

  /// Re-runs backup → services → ready without the 1-second splash delay used
  /// on first launch; the user is already looking at the splash and tapped Retry
  /// themselves, so an enforced minimum delay would feel slow.
  Future<void> _retryPreMigrationBackup() async {
    if (!mounted) return;
    if (_state != _StartupState.backupFailed) {
      // Already retrying or moved on; ignore rapid taps.
      return;
    }
    setState(() {
      _state = _StartupState.backingUp;
      _backupError = null;
    });
    try {
      final dbPath = await widget.locationService.getDatabasePath();
      final stored =
          DatabaseService.getStoredSchemaVersion(
            dbPath,
            keyHex: DatabaseService.instance.databaseKeyHex,
          ) ??
          0;
      await _runPreMigrationBackup(dbPath: dbPath, stored: stored);
      if (!mounted) return;
      final totalSteps = AppDatabase.migrationStepCount(stored);
      _phase = StartupPhase.upgrading;
      setState(() {
        _state = _StartupState.migrating;
        _progress = MigrationProgress(currentStep: 0, totalSteps: totalSteps);
      });
      await _initializeServices();
      if (!mounted) return;
      setState(() => _state = _StartupState.ready);
      _splashFadeController.forward();
    } on BackupFailedException catch (e) {
      if (mounted) {
        setState(() {
          _state = _StartupState.backupFailed;
          _backupError = e;
        });
      }
    } catch (e) {
      _enterFailureState(e);
    }
  }

  /// Finds a backup the diver could swap in, plus the folder it lives in.
  ///
  /// Reads the backup registry straight from [SharedPreferences], which is the
  /// only reason this works at all: the database is closed and the router does
  /// not exist yet, so the normal backup UI is out of reach.
  ///
  /// Best-effort and silent on failure. This runs on a screen the diver has
  /// already reached because something went wrong; a second failure here must
  /// degrade to the plain error screen, not replace one terminal state with
  /// another.
  Future<void> _loadRecoveryOptions() async {
    // No restore can fix a build that cannot open a database at all, and
    // offering one would repeat exactly the misdirection #1134 is about.
    if (!_failureKind.dataIsAtRisk) return;

    try {
      final history = BackupPreferences(widget.prefs).getHistory();

      // Prefer the automatic pre-migration safety copy, the newest snapshot
      // of the database as it was before this launch touched it, then fall
      // back to the newest local backup of any kind.
      final candidates = [
        ...history.where((r) => r.type == BackupType.preMigration),
        ...history.where((r) => r.type != BackupType.preMigration),
      ];

      for (final record in candidates) {
        final path = record.localPath;
        // A SAF (content://) or cloud-only record cannot be swapped in by the
        // plain file copy DatabaseService.restore performs.
        if (path == null || isSafRef(path)) continue;
        // Synchronous stat on purpose. The set is bounded (a handful of
        // registry entries, read once, on a screen that is already terminal),
        // so async buys nothing here; and empirically the async form left the
        // widget tests covering this screen pumping until their timeout
        // instead of settling.
        if (!File(path).existsSync()) continue;
        if (!mounted) return;
        setState(() {
          _recoveryBackup = record;
          _backupsDirectory = p.dirname(path);
        });
        return;
      }

      // No usable backup, but the folder is still worth showing: the diver may
      // have moved their backups somewhere this registry no longer knows about.
      final fallbackDir = await BackupService.resolveDefaultBackupsDirectory();
      if (!mounted) return;
      setState(() => _backupsDirectory = fallbackDir);
    } catch (e) {
      debugPrint('Startup recovery options unavailable: $e');
    }
  }

  /// Swaps [_recoveryBackup] in for the live database, then resumes startup.
  ///
  /// Safe here precisely because startup failed: the database is closed, so
  /// [DatabaseService.restore] does its staged swap without contending with an
  /// open connection, and it rolls the original file back if the swap fails.
  Future<void> _restoreFromStartupBackup() async {
    final record = _recoveryBackup;
    final path = record?.localPath;
    if (path == null) return;
    if (_restoreStatus == StartupRestoreStatus.running) return;

    setState(() {
      _restoreStatus = StartupRestoreStatus.running;
      _restoreError = null;
    });

    void onProgress(int currentStep, int totalSteps) {
      if (mounted) {
        setState(() {
          _progress = MigrationProgress(
            currentStep: currentStep,
            totalSteps: totalSteps,
          );
        });
      }
    }

    try {
      if (widget.restoreOverride != null) {
        await widget.restoreOverride!(path, onProgress);
      } else {
        // [restore] resolves its destination through the location service,
        // which a failed launch may never have registered. Without this the
        // swap would target the DEFAULT path and miss a custom location.
        DatabaseService.instance.adoptLocationService(widget.locationService);
        await DatabaseService.instance.restore(
          path,
          onMigrationProgress: onProgress,
        );
      }
      if (!mounted) return;
      // The restored file carries an older schema, so the reopen inside
      // restore() has already run the ladder. Resume startup from the top so
      // the security gate and the remaining services run exactly as on a
      // normal launch.
      setState(() {
        _restoreStatus = StartupRestoreStatus.idle;
        _state = _StartupState.initializing;
        _errorMessage = '';
        _recoveryBackup = null;
      });
      await _runInitialization();
    } catch (e) {
      debugPrint('Startup restore failed: $e');
      if (!mounted) return;
      setState(() {
        _restoreStatus = StartupRestoreStatus.failed;
        _restoreError = '$e';
      });
    }
  }

  /// True where "show me that folder" means something. Mobile file managers
  /// have no addressable folder concept to hand off to.
  bool get _canRevealBackupsFolder =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Future<void> _showBackupsFolder() async {
    final dir = _backupsDirectory;
    if (dir == null) return;
    // launchUrl signals a refused hand-off by RETURNING false as often as by
    // throwing (no registered handler for a file:// directory is the common
    // case here), so both have to be logged or the button is a silent no-op.
    // Either way the path is on screen as selectable text, so the diver still
    // has something to paste into a file manager.
    try {
      final launched = await launchUrl(Uri.directory(dir));
      if (!launched) {
        debugPrint('Could not open backups folder: launchUrl returned false');
      }
    } catch (e) {
      debugPrint('Could not open backups folder: $e');
    }
  }

  static final Uri _previousReleasesUri = Uri.parse(
    StartupFailureView.previousReleasesUrl,
  );

  Future<void> _openPreviousReleases() async {
    // Same reasoning as _showBackupsFolder: a refused hand-off shows up as a
    // false return at least as often as an exception, and an unlogged one
    // makes the button look broken. The address is rendered beneath the
    // button either way, so the diver keeps a usable route.
    try {
      final launched = await launchUrl(
        _previousReleasesUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint(
          'Could not open the releases page: launchUrl returned false',
        );
      }
    } catch (e) {
      debugPrint('Could not open the releases page: $e');
    }
  }

  static final Uri _latestReleaseUri = Uri.parse(
    VersionMismatchView.latestReleaseUrl,
  );

  Future<void> _openLatestRelease() async {
    try {
      await launchUrl(_latestReleaseUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Leaving the user on this screen is the only safe fallback: the
      // database is untouched and must stay that way. VersionMismatchView
      // renders this same URL beneath the button, so a launch failure still
      // leaves the user an address they can type in manually.
    }
  }

  void _quitApp() {
    if (widget.closeAppOverride != null) {
      widget.closeAppOverride!();
      return;
    }
    if (Platform.isIOS || Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  Future<void> _closeApp() async {
    if (widget.closeAppOverride != null) {
      widget.closeAppOverride!();
      return;
    }

    // Best-effort: close any databases that may have been partially initialized
    // before exiting, to avoid FFI/isolate teardown crashes.
    try {
      await DatabaseService.instance.close();
    } catch (_) {}
    try {
      await LocalCacheDatabaseService.instance.close();
    } catch (_) {}

    if (Platform.isIOS || Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = resolveStartupBrightness(
      widget.prefs,
      MediaQuery.platformBrightnessOf(context),
    );
    final isDark = brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    final isReady = _state == _StartupState.ready;

    // Splash layer: stays at full opacity while initializing/migrating/error,
    // then dissolves to reveal SubmersionRestart beneath once state is ready.
    final Widget? splashLayer = _splashRemoved
        ? null
        : IgnorePointer(
            ignoring: isReady,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(
                CurvedAnimation(
                  parent: _splashFadeController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                navigatorKey: _splashNavigatorKey,
                // The splash runs before the database (and therefore the
                // diver's saved locale preference) is readable, so it can
                // only resolve the system locale. Without these delegates
                // the lock, migration and recovery screens would stay the
                // last English-only surfaces in the app, and they are
                // exactly the screens a diver meets when something is
                // already wrong.
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                localeListResolutionCallback: (preferred, supported) =>
                    resolveAppLocale(preferred, supported),
                home:
                    (_state == _StartupState.error ||
                        _state == _StartupState.backupFailed ||
                        _state == _StartupState.recoveryRequired ||
                        _state == _StartupState.recovering ||
                        _state == _StartupState.recoveryFailed)
                    ? Scaffold(
                        key: const ValueKey('error'),
                        backgroundColor: backgroundColor,
                        body: SafeArea(
                          child: Center(
                            child: Builder(
                              builder: (context) => _buildErrorContent(
                                context,
                                textColor,
                                subtitleColor,
                              ),
                            ),
                          ),
                        ),
                      )
                    : _state == _StartupState.locked
                    ? LockScreenView(
                        key: const ValueKey('locked'),
                        brightness: brightness,
                        onSubmitSecret: _unlockWithPassword,
                        onBiometric: _biometricAvailable
                            ? _unlockWithBiometric
                            : null,
                        onUseRecoveryCode: _handleRecoveryUnlock,
                        onStartFresh: _handleStartFresh,
                      )
                    : Scaffold(
                        // Use 'splash' key for both initializing and migrating
                        // so AnimatedSize handles the progress bar transition
                        // instead of AnimatedSwitcher triggering a full
                        // Scaffold crossfade.
                        key: const ValueKey('splash'),
                        body: OceanBackground(
                          brightness: brightness,
                          child: SafeArea(
                            child: Center(
                              child: Builder(
                                builder: (context) =>
                                    _buildSplashContent(context, isDark),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        if (isReady)
          SubmersionRestart(
            prefs: widget.prefs,
            logFileService: widget.logFileService,
          ),
        ?splashLayer,
      ],
    );
  }

  Widget _buildSplashContent(BuildContext context, bool isDark) {
    if (_state == _StartupState.backingUp) {
      return const BackingUpView();
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/icon/icon.png', width: 120, height: 120),
          ),
          const SizedBox(height: 24),
          const Text(
            'Submersion',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 240,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _state == _StartupState.migrating
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: _progress.fraction,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.startup_migrating_progress(
                            _progress.currentStep,
                            _progress.totalSteps,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(
    BuildContext context,
    Color textColor,
    Color subtitleColor,
  ) {
    if (_state == _StartupState.backupFailed && _backupError != null) {
      return BackupFailedView(
        error: _backupError!,
        onRetry: _retryPreMigrationBackup,
        onQuit: _quitApp,
      );
    }

    if (_state == _StartupState.recoveryRequired ||
        _state == _StartupState.recovering ||
        _state == _StartupState.recoveryFailed) {
      return _buildRecoveryContent(context, textColor, subtitleColor);
    }

    if (_isVersionMismatch) {
      return VersionMismatchView(
        databaseVersion: _dbVersion,
        appVersion: _appVersion,
        textColor: textColor,
        subtitleColor: subtitleColor,
        onDownloadLatest: _openLatestRelease,
        onClose: _closeApp,
      );
    }

    return StartupFailureView(
      kind: _failureKind,
      details: _errorMessage,
      textColor: textColor,
      subtitleColor: subtitleColor,
      recoveryBackup: _recoveryBackup,
      onRestoreBackup: _recoveryBackup == null
          ? null
          : _restoreFromStartupBackup,
      restoreStatus: _restoreStatus,
      restoreError: _restoreError,
      backupsDirectory: _backupsDirectory,
      onShowBackupsFolder: _backupsDirectory != null && _canRevealBackupsFolder
          ? _showBackupsFolder
          : null,
      onViewPreviousReleases: _openPreviousReleases,
      onClose: _closeApp,
    );
  }

  Widget _buildRecoveryContent(
    BuildContext context,
    Color textColor,
    Color subtitleColor,
  ) {
    if (_state == _StartupState.recovering) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.startup_recovering_title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.startup_recovering_body,
              style: TextStyle(fontSize: 14, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_state == _StartupState.recoveryFailed) {
      final details = _errorMessage.isNotEmpty
          ? _errorMessage
          : (_readonlyError?.toString() ?? '');
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              context.l10n.startup_recoveryFailed_title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.startup_recoveryFailed_body,
              style: TextStyle(fontSize: 14, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                details,
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _runRecovery,
                  child: Text(context.l10n.common_action_tryAgain),
                ),
                FilledButton(
                  onPressed: _closeApp,
                  child: Text(context.l10n.common_action_close),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // recoveryRequired
    final code = _readonlyError?.extendedResultCode;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.build_circle_outlined, size: 64, color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            context.l10n.startup_recoveryRequired_title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.startup_recoveryRequired_body,
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          if (code != null) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.startup_recovery_sqliteCode(code),
              style: TextStyle(
                fontSize: 12,
                color: subtitleColor,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _runRecovery,
            child: Text(context.l10n.startup_recovery_action),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _closeApp,
            child: Text(context.l10n.startup_recovery_closeWithoutRecovering),
          ),
        ],
      ),
    );
  }
}
