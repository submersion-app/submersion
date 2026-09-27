import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/presentation/widgets/dive_log_unavailable_view.dart';
import 'package:submersion/core/presentation/widgets/interrupted_restore_view.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/dive_log_availability.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/restore_journal.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/core/services/security/security_preferences.dart';
import 'package:submersion/core/services/startup_recovery_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

/// Answers the startup gate from a script instead of the filesystem, so a
/// widget test never waits on real I/O. The last answer repeats once the
/// script runs out.
class _ScriptedAvailability extends DiveLogAvailabilityService {
  _ScriptedAvailability(
    super.location, {
    required List<DiveLogAvailability> checks,
    Future<bool> Function()? download,
  }) : _checks = [...checks],
       _download = download ?? (() async => false);

  final List<DiveLogAvailability> _checks;
  final Future<bool> Function() _download;
  int checkCalls = 0;
  int downloadCalls = 0;

  @override
  Future<DiveLogAvailability> check() async {
    checkCalls++;
    return _checks.length > 1 ? _checks.removeAt(0) : _checks.single;
  }

  @override
  Future<bool> downloadFromICloud() {
    downloadCalls++;
    return _download();
  }
}

/// Records folder picks instead of opening a platform picker. Returns null,
/// which is a cancel: these tests prove the route is wired, and the adoption
/// behind it has its own tests.
class _Location extends DatabaseLocationService {
  _Location(super.prefs);

  int pickCalls = 0;
  int markCalls = 0;

  /// When set, the stamp waits on it, so a test can observe the stamp was
  /// asked for without startup going on to mount the real app.
  Completer<void>? holdMark;

  @override
  Future<FolderPickResultWithBookmark?> pickCustomFolder() async {
    pickCalls++;
    return null;
  }

  @override
  Future<void> markCustomLocationVerified() {
    markCalls++;
    return holdMark?.future ?? super.markCustomLocationVerified();
  }
}

/// Classifies any picked file as a restorable backup, so the failure
/// screen's restore route can be driven without a real backup file.
class _AcceptingRecovery extends StartupRecoveryService {
  _AcceptingRecovery(super.locationService);

  @override
  Future<BackupFileChoice> classifyBackupFile(
    String path,
    SharedPreferences prefs, {
    Future<BackupValidationResult> Function(String path)? validate,
  }) async => RestorableBackupFile(path);
}

/// Fails the first pre-migration backup and succeeds after, like a disk that
/// was briefly full.
class _FlakyBackup extends PreMigrationBackupService {
  _FlakyBackup({required super.preferences, required this.fail})
    : super(
        livePathProvider: () async => 'unused.db',
        backupsDirProvider: () async => 'unused-backups',
      );

  final bool fail;

  @override
  Future<void> backupIfMigrationPending({
    required int stored,
    required int target,
    required String appVersion,
  }) async {
    if (fail) {
      throw const BackupFailedException(
        cause: BackupFailureCause.unknown,
        userMessage: 'Backup failed once.',
        technicalDetails: 'flaky',
      );
    }
  }
}

/// A restore journal that touches no files.
class _Journal extends RestoreJournal {
  _Journal({this.aside, this.interrupted})
    : super(p.join('unused', 'submersion.db'), readSchemaVersion: _noVersion);

  static int? _noVersion(String _) => null;

  final String? aside;
  final InterruptedRestore? interrupted;

  @override
  String? get pendingAsidePath => aside;

  @override
  InterruptedRestore? findInterrupted() => interrupted;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  late SharedPreferences prefs;
  late _Location location;
  late LogFileService logFileService;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('startup_availability');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    location = _Location(prefs);
    await location.saveStorageConfig(
      StorageConfig(
        mode: StorageLocationMode.customFolder,
        customFolderPath: folder.path,
        lastVerified: DateTime(2026, 9, 1),
      ),
    );
    logFileService = LogFileService(logDirectory: p.join(folder.path, 'logs'));
    DatabaseSecurityService.instance.resetForTesting();
  });

  tearDown(() async {
    DatabaseSecurityService.instance.resetForTesting();
    await folder.delete(recursive: true);
  });

  _ScriptedAvailability scripted(
    List<DiveLogAvailability> checks, {
    Future<bool> Function()? download,
  }) => _ScriptedAvailability(location, checks: checks, download: download);

  // The initializer records that it STARTED but never completes, mirroring
  // the other startup tests: ready is never reached, so the real app (which
  // needs a live database) never mounts.
  Widget wrapper(
    DiveLogAvailabilityService availability, {
    void Function()? onStarted,
    RestoreJournal? journal,
    Future<String?> Function()? pickBackupFile,
  }) {
    return StartupWrapper(
      prefs: prefs,
      logFileService: logFileService,
      locationService: location,
      initializerOverride: (_) {
        onStarted?.call();
        return Completer<void>().future;
      },
      schemaVersionProbeOverride: (_) => (needsMigration: false, totalSteps: 0),
      enginePreflightOverride: () {},
      restoreJournalFactory: (_) => journal ?? _Journal(),
      availabilityServiceOverride: availability,
      pickBackupFileOverride: pickBackupFile,
    );
  }

  /// Every step of the gate is a microtask, so a few frames settle it.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  /// Expires the one-second minimum splash so no timer outlives a test.
  Future<void> finish(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 2));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  const tryAgain = ValueKey('diveLogUnavailable_tryAgain');

  testWidgets('an evicted dive log is fetched under the splash, then opens '
      'as usual', (tester) async {
    final download = Completer<bool>();
    final availability = scripted([
      DiveLogAvailability.inICloudOnly,
      DiveLogAvailability.ready,
    ], download: () => download.future);
    var started = false;

    await tester.pumpWidget(
      wrapper(availability, onStarted: () => started = true),
    );
    await settle(tester);

    expect(find.text('Downloading your dive log from iCloud'), findsOneWidget);
    expect(started, isFalse, reason: 'nothing opens before the file is here');

    download.complete(true);
    await settle(tester);

    expect(started, isTrue);
    expect(find.text('Downloading your dive log from iCloud'), findsNothing);
    expect(find.byType(DiveLogUnavailableView), findsNothing);
    expect(
      availability.checkCalls,
      2,
      reason: 'a finished download is trusted only once the file is there',
    );
    await finish(tester);
  });

  testWidgets('an evicted dive log that will not download stops startup and '
      'explains', (tester) async {
    final availability = scripted([DiveLogAvailability.inICloudOnly]);
    var started = false;

    await tester.pumpWidget(
      wrapper(availability, onStarted: () => started = true),
    );
    await settle(tester);

    final view = tester.widget<DiveLogUnavailableView>(
      find.byType(DiveLogUnavailableView),
    );
    expect(view.availability, DiveLogAvailability.inICloudOnly);
    expect(view.folderPath, folder.path);
    expect(started, isFalse, reason: 'opening would create an empty dive log');
    expect(availability.downloadCalls, 1);
  });

  testWidgets('a dive log missing from its folder stops startup without '
      'asking iCloud', (tester) async {
    final availability = scripted([DiveLogAvailability.missing]);
    var started = false;

    await tester.pumpWidget(
      wrapper(availability, onStarted: () => started = true),
    );
    await settle(tester);

    final view = tester.widget<DiveLogUnavailableView>(
      find.byType(DiveLogUnavailableView),
    );
    expect(view.availability, DiveLogAvailability.missing);
    expect(started, isFalse);
    expect(availability.downloadCalls, 0);
  });

  testWidgets('Try again checks again and carries on once the dive log is '
      'back', (tester) async {
    final availability = scripted([
      DiveLogAvailability.missing,
      DiveLogAvailability.ready,
    ]);
    var started = false;

    await tester.pumpWidget(
      wrapper(availability, onStarted: () => started = true),
    );
    await settle(tester);
    await tap(tester, find.byKey(tryAgain));

    expect(started, isTrue);
    expect(availability.checkCalls, 2);
    await finish(tester);
  });

  testWidgets('Try again on an evicted dive log asks iCloud again', (
    tester,
  ) async {
    final availability = scripted([DiveLogAvailability.inICloudOnly]);

    await tester.pumpWidget(wrapper(availability));
    await settle(tester);
    await tap(tester, find.byKey(tryAgain));

    expect(availability.downloadCalls, 2);
    expect(find.byType(DiveLogUnavailableView), findsOneWidget);
  });

  testWidgets('a new dive log is created only once the diver confirms', (
    tester,
  ) async {
    final availability = scripted([DiveLogAvailability.missing]);
    var started = false;

    await tester.pumpWidget(
      wrapper(availability, onStarted: () => started = true),
    );
    await settle(tester);
    await tap(tester, find.text('Start a new dive log in this folder'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Start a new dive log here?'), findsOneWidget);
    expect(find.textContaining(folder.path), findsWidgets);
    expect(started, isFalse);

    await tester.tap(find.text('Start new dive log'));
    await settle(tester);

    expect(started, isTrue);
    expect(
      availability.checkCalls,
      1,
      reason: 'asking again would stop on the same screen the diver just left',
    );
    await finish(tester);
  });

  testWidgets('cancelling the new dive log leaves startup where it was', (
    tester,
  ) async {
    final availability = scripted([DiveLogAvailability.missing]);
    var started = false;

    await tester.pumpWidget(
      wrapper(availability, onStarted: () => started = true),
    );
    await settle(tester);
    await tap(tester, find.text('Start a new dive log in this folder'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(started, isFalse);
    expect(find.byType(DiveLogUnavailableView), findsOneWidget);
  });

  testWidgets('Use another folder runs the existing folder route', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapper(scripted([DiveLogAvailability.inICloudOnly])),
    );
    await settle(tester);
    await tap(tester, find.text('Use a dive log in another folder'));

    expect(location.pickCalls, 1);
  });

  testWidgets('Restore from a backup file runs the existing restore route', (
    tester,
  ) async {
    var picks = 0;
    await tester.pumpWidget(
      wrapper(
        scripted([DiveLogAvailability.missing]),
        pickBackupFile: () async {
          picks++;
          return null;
        },
      ),
    );
    await settle(tester);
    await tap(tester, find.text('Restore from a backup file'));

    expect(picks, 1);
  });

  testWidgets('an unsettled restore is left to the restore screen: the live '
      'path may be empty on purpose', (tester) async {
    final availability = scripted([DiveLogAvailability.missing]);

    await tester.pumpWidget(
      wrapper(
        availability,
        journal: _Journal(
          aside: p.join(folder.path, 'submersion.db.pre-restore'),
          interrupted: const InterruptedRestore(
            startedAt: null,
            liveExists: false,
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.byType(InterruptedRestoreView), findsOneWidget);
    expect(find.byType(DiveLogUnavailableView), findsNothing);
    expect(availability.checkCalls, 0);
  });

  group('stamping a location that has held a dive log', () {
    setUp(() async {
      // A custom location saved before the stamp existed.
      await location.saveStorageConfig(
        StorageConfig(
          mode: StorageLocationMode.customFolder,
          customFolderPath: folder.path,
        ),
      );
    });

    testWidgets('a successful open stamps an unstamped custom location', (
      tester,
    ) async {
      await tester.pumpWidget(
        StartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: location,
          initializerOverride: (_) async {},
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          enginePreflightOverride: () {},
          restoreJournalFactory: (_) => _Journal(),
          availabilityServiceOverride: scripted([DiveLogAvailability.ready]),
        ),
      );
      await settle(tester);

      // Observed inside the one-second minimum splash: past it the real app
      // mounts, which a unit test cannot host, so the tree is torn down
      // before the timer fires.
      expect((await location.getStorageConfig()).lastVerified, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await finish(tester);
    });

    testWidgets('a failed open leaves it unstamped', (tester) async {
      await tester.pumpWidget(
        StartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: location,
          initializerOverride: (_) async => throw StateError('open failed'),
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          enginePreflightOverride: () {},
          restoreJournalFactory: (_) => _Journal(),
          availabilityServiceOverride: scripted([DiveLogAvailability.ready]),
        ),
      );
      await settle(tester);
      await finish(tester);

      expect((await location.getStorageConfig()).lastVerified, isNull);
    });
  });

  testWidgets('after a new dive log fails to open, the next attempt checks '
      'again: the choice covers one launch, not the rest of the process', (
    tester,
  ) async {
    final availability = scripted([DiveLogAvailability.missing]);
    var opens = 0;

    await tester.pumpWidget(
      StartupWrapper(
        prefs: prefs,
        logFileService: logFileService,
        locationService: location,
        initializerOverride: (_) {
          opens++;
          if (opens == 1) throw StateError('folder is not writable');
          return Completer<void>().future;
        },
        schemaVersionProbeOverride: (_) =>
            (needsMigration: false, totalSteps: 0),
        enginePreflightOverride: () {},
        restoreJournalFactory: (_) => _Journal(),
        availabilityServiceOverride: availability,
        recoveryServiceOverride: _AcceptingRecovery(location),
        pickBackupFileOverride: () async => p.join(folder.path, 'backup.db'),
        restoreOverride: (_, _) async {},
      ),
    );
    await settle(tester);
    await tap(tester, find.text('Start a new dive log in this folder'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start new dive log'));
    await settle(tester);
    await finish(tester);
    expect(opens, 1, reason: 'the new dive log was tried and failed');

    // The failure screen's restore reruns startup from the top.
    await tap(tester, find.text('Restore from a backup file'));

    expect(availability.checkCalls, 2);
    expect(find.byType(DiveLogUnavailableView), findsOneWidget);
  });

  testWidgets('the retry after a failed pre-upgrade backup also stamps the '
      'location', (tester) async {
    location.holdMark = Completer<void>();
    var backups = 0;

    await tester.pumpWidget(
      StartupWrapper(
        prefs: prefs,
        logFileService: logFileService,
        locationService: location,
        initializerOverride: (_) async {},
        schemaVersionProbeOverride: (_) =>
            (needsMigration: true, totalSteps: 1),
        preMigrationBackupFactory:
            ({
              required String livePath,
              required BackupPreferences preferences,
            }) => _FlakyBackup(preferences: preferences, fail: backups++ == 0),
        enginePreflightOverride: () {},
        restoreJournalFactory: (_) => _Journal(),
        availabilityServiceOverride: scripted([DiveLogAvailability.ready]),
      ),
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await settle(tester);

    expect(location.markCalls, 1);
    await finish(tester);
  });

  testWidgets('the check runs before the security gate, so an evicted '
      'encrypted dive log keeps its encryption setting', (tester) async {
    // The security gate reads a missing file as plaintext and switches
    // encryption off to match, dropping the key the real file needs. The
    // same trap as #1901, one step earlier.
    await SecurityPreferences(prefs).setDbEncryptionEnabled(true);

    await tester.pumpWidget(
      wrapper(scripted([DiveLogAvailability.inICloudOnly])),
    );
    await settle(tester);

    expect(find.byType(DiveLogUnavailableView), findsOneWidget);
    expect(SecurityPreferences(prefs).dbEncryptionEnabled, isTrue);
  });
}
