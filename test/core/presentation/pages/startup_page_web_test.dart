import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/log_file_service.dart';

class _WebLocationService extends DatabaseLocationService {
  _WebLocationService(super.prefs);

  @override
  Future<String> getDatabasePath() async => kWebDatabasePath;
}

/// The startup page's browser branches, driven on the VM: no restore
/// journal, no dive-log availability check, no security gate, no synchronous
/// schema probe and no background service, and the page still reaches the
/// service initializer. The page is taken down before its splash ends, since
/// the stubbed initializer opens no database for the app to build on.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('the browser branches reach the initializer without a probe', (
    tester,
  ) async {
    var initializerCalls = 0;
    var preflightCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupWrapper(
          prefs: prefs,
          logFileService: LogFileService(logDirectory: '/opfs/support/logs'),
          locationService: _WebLocationService(prefs),
          isWebOverride: true,
          enginePreflightOverride: () => preflightCalls++,
          initializerOverride: (_) async => initializerCalls++,
          closeAppOverride: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(preflightCalls, 1);
    expect(initializerCalls, 1);
    expect(find.text('Database upgrade failed'), findsNothing);

    // Unmount before the one second splash ends and the app is built.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
