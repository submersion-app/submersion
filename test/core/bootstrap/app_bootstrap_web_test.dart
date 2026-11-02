import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/bootstrap/app_bootstrap_web.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/services/logger_service.dart';

/// The browser bootstrap, imported directly and run on the VM with its side
/// effects injected: no real `runApp`, no platform directory, no platform
/// channel for the session environment line.
void main() {
  testWidgets('bootstrapWeb hands runApp a StartupWrapper', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('bootstrap_web_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    // installGlobalErrorHandlers and configureFileLogging replace
    // process-wide state; put it all back for the files bundled after this.
    final originalFlutterOnError = FlutterError.onError;
    final originalPlatformOnError = PlatformDispatcher.instance.onError;
    final imageCache = PaintingBinding.instance.imageCache;
    final originalCacheBytes = imageCache.maximumSizeBytes;
    addTearDown(() {
      FlutterError.onError = originalFlutterOnError;
      PlatformDispatcher.instance.onError = originalPlatformOnError;
      imageCache.maximumSizeBytes = originalCacheBytes;
      LoggerService.setFileService(null);
    });

    Widget? handed;
    var environmentLogged = 0;
    // Real I/O (the log directory, the first log line) never completes in
    // the fake-async zone a widget test runs in; runAsync lets it finish.
    await tester.runAsync(() async {
      await bootstrapWeb(
        run: (app) => handed = app,
        supportDirectory: () async => dir.path,
        logEnvironment: () async => environmentLogged++,
      );
      await LoggerService.flushPendingWrites();
    });

    final wrapper = handed;
    expect(wrapper, isA<StartupWrapper>());
    wrapper as StartupWrapper;
    expect(
      wrapper.logFileService.logFilePath,
      p.join(dir.path, 'logs', 'submersion.log'),
    );
    expect(Directory(p.join(dir.path, 'logs')).existsSync(), isTrue);
    expect(wrapper.demoPaths?.supportDir, dir.path);
    expect(environmentLogged, 1);
  });
}
