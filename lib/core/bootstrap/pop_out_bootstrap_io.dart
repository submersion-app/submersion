import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/database/read_only_query_interceptor.dart';
import 'package:submersion/core/database/shared_database_ports.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/pop_out/data/pop_out_channel.dart';
import 'package:submersion/features/pop_out/data/pop_out_windows.dart';
import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/pop_out_app.dart';
import 'package:submersion/features/pop_out/presentation/pop_out_overrides.dart';

// Startup wiring that only runs in a real second window's engine; the parts
// it puts together are tested on their own.
// coverage:ignore-start

const _log = LoggerService('PopOutBootstrap');

/// What this engine was launched with, when it is a pop-out window; null for
/// the main window and on phones and tablets.
Future<PopOutLaunch?> readPopOutLaunch() async {
  if (!HostPlatform.isDesktop) return null;
  WidgetsFlutterBinding.ensureInitialized();
  return createPopOutWindows().currentLaunch();
}

/// Runs the profile pop-out window: in-memory prefs copied from the main
/// window, the main window's databases joined read-only, the window placed,
/// then the viewer. Nothing the main window's startup does (setup, sync,
/// backups, update checks, file logging) runs here.
Future<void> runPopOutApp(PopOutLaunch launch) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Writes stay in this window's memory: only the main window writes the
  // prefs file.
  SharedPreferencesStorePlatform.instance =
      InMemorySharedPreferencesStore.withData({
        for (final MapEntry(:key, :value) in launch.prefs.entries)
          'flutter.$key': value,
      });
  final prefs = await SharedPreferences.getInstance();
  final windows = createPopOutWindows();
  await windowManager.ensureInitialized();

  final connected = await _joinDatabases();
  await _placeWindow(launch);
  await windowManager.setPreventClose(true);
  windowManager.addListener(_PopOutWindowEvents(windows.channel));

  runApp(
    connected
        ? ProviderScope(
            overrides: popOutProviderOverrides(
              prefs: prefs,
              // Never initialized: the pop-out writes no log file.
              logFileService: LogFileService(
                logDirectory: p.join(Directory.systemTemp.path, 'pop_out'),
              ),
              channel: windows.channel,
              launch: launch,
            ).cast(),
            child: const PopOutApp(),
          )
        : const PopOutConnectFailedApp(),
  );
  await windowManager.show();
  await windowManager.focus();
}

/// Connects to the main window's database and local cache, both refusing
/// writes. False when the main window has no database published.
Future<bool> _joinDatabases() async {
  final main = await connectToPublishedDatabase(
    kMainDatabasePortName,
    interceptor: ReadOnlyQueryInterceptor(),
  );
  if (main == null) return false;
  DatabaseService.instance.attachSharedDatabase(AppDatabase(main));
  final cache = await connectToPublishedDatabase(
    kLocalCacheDatabasePortName,
    interceptor: ReadOnlyQueryInterceptor(),
  );
  if (cache != null) {
    LocalCacheDatabaseService.instance.attachSharedDatabase(
      LocalCacheDatabase(cache),
    );
  }
  return true;
}

Future<void> _placeWindow(PopOutLaunch launch) async {
  List<PopOutFrame> displays;
  try {
    displays = [
      for (final display in await ScreenRetriever.instance.getAllDisplays())
        PopOutFrame(
          x: display.visiblePosition?.dx ?? 0,
          y: display.visiblePosition?.dy ?? 0,
          width: display.visibleSize?.width ?? display.size.width,
          height: display.visibleSize?.height ?? display.size.height,
        ),
    ];
  } catch (_) {
    displays = const [];
  }
  final frame = resolvePopOutFrame(
    saved: launch.savedFrame,
    displays: displays,
    mainWindow: launch.mainFrame,
  );
  _log.info(
    'Pop-out frame $frame from saved ${launch.savedFrame}, '
    'main ${launch.mainFrame}, displays $displays',
  );
  await windowManager.setMinimumSize(const Size(480, 320));
  await windowManager.setBounds(
    Rect.fromLTWH(frame.x, frame.y, frame.width, frame.height),
  );
}

/// Tells the main window when this window takes or loses focus, moves or
/// resizes, and closes.
class _PopOutWindowEvents with WindowListener {
  _PopOutWindowEvents(this._channel);

  final PopOutChannel _channel;
  Timer? _frameReport;

  @override
  void onWindowFocus() =>
      unawaited(_channel.send(const FocusReportMessage(true)));

  @override
  void onWindowBlur() =>
      unawaited(_channel.send(const FocusReportMessage(false)));

  @override
  void onWindowMoved() => _reportFrameSoon();

  @override
  void onWindowResized() => _reportFrameSoon();

  void _reportFrameSoon() {
    _frameReport?.cancel();
    _frameReport = Timer(const Duration(milliseconds: 500), () async {
      final bounds = await windowManager.getBounds();
      await _channel.send(
        FrameMessage(
          PopOutFrame(
            x: bounds.left,
            y: bounds.top,
            width: bounds.width,
            height: bounds.height,
          ),
        ),
      );
    });
  }

  /// The diver closed the window: tell the main window, then close.
  /// A close the main window asked for has already dropped the hold, and
  /// needs no report.
  @override
  Future<void> onWindowClose() async {
    if (!await windowManager.isPreventClose()) return;
    _frameReport?.cancel();
    final bounds = await windowManager.getBounds();
    await _channel.send(
      FrameMessage(
        PopOutFrame(
          x: bounds.left,
          y: bounds.top,
          width: bounds.width,
          height: bounds.height,
        ),
      ),
    );
    await _channel.send(const ClosedMessage());
    // Never windowManager.destroy(): on macOS it terminates the whole app.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}

// coverage:ignore-end
