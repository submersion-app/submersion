@TestOn('browser')
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/platform/compute/compute_worker_client.dart';
import 'package:submersion/core/platform/web_database_status.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/log_file_service.dart';

import '../web_test_assets.dart';

/// The web start-up in Chrome, through the real startup page: the engine
/// preflight, the path, the security gate's browser branch, the skipped
/// schema probe and the database open on the wasm worker. The initializer
/// is narrowed to the database step and the page is taken down before its
/// splash ends, so the app and its router are never built in this harness
/// (a router rewriting the page URL unseats it); the Playwright smoke test
/// drives the wizard against the built bundle. Every worker-bound await,
/// the close included, runs inside runAsync, where real replies arrive.
void main() {
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
    ComputeWorkerClient.assetBase = kWebTestAssetBase;
  });

  testWidgets('the startup page opens the browser database', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final logFileService = LogFileService(logDirectory: '/opfs/support/logs');
    await logFileService.initialize();
    final locationService = DatabaseLocationService(prefs);

    var opened = false;
    var userVersion = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        StartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          initializerOverride: (onProgress) =>
              DatabaseService.instance.initialize(
                locationService: locationService,
                onMigrationProgress: onProgress,
              ),
        ),
      );
      for (var i = 0; i < 300 && !opened; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          DatabaseService.instance.database;
          opened = true;
        } catch (_) {
          await tester.pump();
        }
      }
      // Down before the one second splash ends and the app is built.
      await tester.pumpWidget(const SizedBox.shrink());
      if (opened) {
        final row = await DatabaseService.instance.database
            .customSelect('PRAGMA user_version')
            .getSingle();
        userVersion = row.read<int>('user_version');
        await DatabaseService.instance.close();
      }
    });
    await tester.pump(const Duration(seconds: 2));

    expect(
      opened,
      isTrue,
      reason: 'the startup page never opened the database',
    );
    expect(userVersion, AppDatabase.currentSchemaVersion);
    final status = WebDatabaseStatusHolder.current;
    expect(status, isNotNull);
    expect(status!.persists, isTrue, reason: '$status');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
