import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _kDebugModeKey = 'debug_mode_enabled';

/// Notifier that manages the debug mode toggle state.
/// Persists to SharedPreferences so debug mode survives app restarts.
/// Also toggles file logging on [LoggerService] when debug mode changes.
class DebugModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  final LogFileService _logFileService;

  DebugModeNotifier(this._prefs, this._logFileService)
    : super(_prefs.getBool(_kDebugModeKey) ?? false);

  Future<void> enable() async {
    state = true;
    await _prefs.setBool(_kDebugModeKey, true);
    LoggerService.setFileService(_logFileService);
    // Deliberately no session-environment line here, unlike main.dart. It
    // would have to be fire-and-forget (a settings toggle must not wait on a
    // platform channel), and a background version lookup plus a file write
    // outliving the toggle is a timer and a real-IO future escaping whatever
    // widget test flipped it. The export header in debug_log_providers.dart
    // already names the build on every copy, share and save, which is the
    // path a bug report actually travels (issue #1246).
  }

  Future<void> disable() async {
    state = false;
    await _prefs.setBool(_kDebugModeKey, false);
    LoggerService.setFileService(null);
  }
}

/// Provider for the debug mode state.
final debugModeNotifierProvider =
    StateNotifierProvider<DebugModeNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final logFileService = ref.watch(logFileServiceProvider);
      return DebugModeNotifier(prefs, logFileService);
    });
