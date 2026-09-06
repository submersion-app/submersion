import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// LinkDelegate is the one member of the interface not exported from its
// main library, and it is abstract, so a fake has to pull in link.dart too.
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/presentation/widgets/startup_failure_view.dart';
import 'package:submersion/core/presentation/widgets/version_mismatch_view.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';

/// Which address each terminal startup screen actually hands to the browser.
///
/// The whole point of #1588 was that the schema-mismatch screen opened the
/// wrong one: a stable build was sent to the stable releases page, which is
/// by definition the build that had just refused to open the file. Asserting
/// the rendered URL text is not enough, because the button launches a
/// separately-held Uri; only the launch itself proves they agree.
class _RecordingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _RecordingUrlLauncher({this.result = true});

  /// What the platform reports back. `false` is the refused hand-off that
  /// url_launcher signals without throwing (sandboxed builds, headless
  /// Linux, kiosk mode).
  final bool result;

  final List<String> launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return result;
  }
}

/// Throws on every launch, the other failure mode url_launcher has.
class _ThrowingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    throw Exception('no handler registered');
  }
}

/// Skips all file I/O so the migration-failure path can be reached without
/// touching the disk.
class _NoOpBackupService extends PreMigrationBackupService {
  _NoOpBackupService({required super.preferences})
    : super(
        livePathProvider: () async => '/tmp/test.db',
        backupsDirProvider: () async => '/tmp/test-backups',
      );

  @override
  Future<void> backupIfMigrationPending({
    required int stored,
    required int target,
    required String appVersion,
  }) async {}
}

PreMigrationBackupService _noOpBackupFactory({
  required String livePath,
  required BackupPreferences preferences,
}) => _NoOpBackupService(preferences: preferences);

class _FakeLocationService extends DatabaseLocationService {
  _FakeLocationService(super.prefs);

  @override
  Future<String> getDatabasePath() async => '/tmp/test.db';
}

void main() {
  late SharedPreferences prefs;
  late LogFileService logFileService;
  late DatabaseLocationService locationService;
  late UrlLauncherPlatform originalLauncher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    logFileService = LogFileService(logDirectory: '/tmp/test-logs');
    locationService = _FakeLocationService(prefs);
    originalLauncher = UrlLauncherPlatform.instance;
  });

  tearDown(() => UrlLauncherPlatform.instance = originalLauncher);

  /// Drives StartupWrapper into the schema-mismatch screen the same way a
  /// real newer-on-disk database does, then settles it.
  Future<void> pumpMismatchScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      StartupWrapper(
        prefs: prefs,
        logFileService: logFileService,
        locationService: locationService,
        schemaVersionProbeOverride: (_) =>
            (needsMigration: false, totalSteps: 0),
        // A no-op preflight keeps the test off the host runner's linked
        // SQLite; the mismatch is raised by the initializer instead.
        enginePreflightOverride: () {},
        initializerOverride: (_) async {
          throw const DatabaseVersionMismatchException(
            storedSchemaVersion: 191,
            supportedSchemaVersion: 175,
          );
        },
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('the primary action opens the stable releases page', (
    tester,
  ) async {
    final launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;

    await pumpMismatchScreen(tester);
    await tapAndSettle(tester, find.byType(FilledButton));

    expect(launcher.launched, [VersionMismatchView.latestReleaseUrl]);
  });

  testWidgets('the secondary action opens the beta-builds page (#1588)', (
    tester,
  ) async {
    final launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;

    await pumpMismatchScreen(tester);
    await tapAndSettle(tester, find.byType(OutlinedButton));

    // The regression this issue is about: before the fix, every route off
    // this screen led to the stable build that had just refused the file.
    expect(launcher.launched, [VersionMismatchView.betaReleasesUrl]);
    expect(
      launcher.launched.single,
      isNot(VersionMismatchView.latestReleaseUrl),
    );
  });

  testWidgets('the two actions do not share a destination', (tester) async {
    final launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;

    await pumpMismatchScreen(tester);
    await tapAndSettle(tester, find.byType(FilledButton));
    await tapAndSettle(tester, find.byType(OutlinedButton));

    expect(launcher.launched, [
      VersionMismatchView.latestReleaseUrl,
      VersionMismatchView.betaReleasesUrl,
    ]);
    expect(
      VersionMismatchView.betaReleasesUrl,
      isNot(StartupFailureView.previousReleasesUrl),
    );
  });

  testWidgets('a refused hand-off is survived, not swallowed into a crash', (
    tester,
  ) async {
    // launchUrl reports a refusal by returning false rather than throwing.
    // The diver must stay on the screen either way: the database is untouched
    // and the addresses are still rendered beneath the buttons.
    UrlLauncherPlatform.instance = _RecordingUrlLauncher(result: false);

    await pumpMismatchScreen(tester);
    await tapAndSettle(tester, find.byType(FilledButton));
    await tapAndSettle(tester, find.byType(OutlinedButton));

    expect(tester.takeException(), isNull);
    expect(find.text(VersionMismatchView.latestReleaseUrl), findsOneWidget);
    expect(find.text(VersionMismatchView.betaReleasesUrl), findsOneWidget);
  });

  testWidgets('the failed-upgrade screen opens the releases index instead', (
    tester,
  ) async {
    // The third caller of the shared launcher, and deliberately a different
    // destination: this screen's question is "which build was I on before?",
    // so it wants the index rather than /latest.
    final launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;

    await tester.pumpWidget(
      StartupWrapper(
        prefs: prefs,
        logFileService: logFileService,
        locationService: locationService,
        schemaVersionProbeOverride: (_) =>
            (needsMigration: true, totalSteps: 3),
        enginePreflightOverride: () {},
        preMigrationBackupFactory: _noOpBackupFactory,
        initializerOverride: (_) async {
          throw Exception('migration step 2 blew up');
        },
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('View previous releases'));

    expect(launcher.launched, [StartupFailureView.previousReleasesUrl]);
  });

  testWidgets('a thrown hand-off is survived too', (tester) async {
    UrlLauncherPlatform.instance = _ThrowingUrlLauncher();

    await pumpMismatchScreen(tester);
    await tapAndSettle(tester, find.byType(FilledButton));
    await tapAndSettle(tester, find.byType(OutlinedButton));

    expect(tester.takeException(), isNull);
    expect(find.text(VersionMismatchView.betaReleasesUrl), findsOneWidget);
  });
}
