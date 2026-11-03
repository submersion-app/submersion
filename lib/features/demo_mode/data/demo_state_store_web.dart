import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/prefs_snapshot.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

/// Browser variant (issue #4121): the state and the preferences snapshot
/// live in local storage, under keys the preferences themselves never use,
/// and the sample logbook is one of drift's databases. The photos are links
/// to the site, so none are kept here.
class DemoStateStore {
  const DemoStateStore(this.paths);

  final DemoPaths paths;

  static const _stateKey = 'submersion.demo.state';
  static const _prefsKey = 'submersion.demo.prefs';
  static const _log = LoggerService('DemoStateStore');

  static web.Storage get _storage => web.window.localStorage;

  Future<DemoState?> read() async {
    final raw = _storage.getItem(_stateKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      return DemoState.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  /// One `setItem`, so a closed tab leaves the old state or the new one.
  Future<void> write(DemoState state) async =>
      _storage.setItem(_stateKey, jsonEncode(state.toJson()));

  /// Removes the state, the snapshot and the sample logbook. Best effort
  /// for the logbook: a tab still holding it keeps it until a later entry
  /// replaces it or Forget this device removes it.
  Future<void> deleteAll() async {
    clearBrowserState();
    try {
      await BackgroundDatabaseConnection.deleteStoredDatabases(
        paths.databaseFile,
      ).timeout(const Duration(seconds: 5));
    } catch (e, stackTrace) {
      _log.warning(
        'Could not delete the sample logbook yet',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  bool get hasAnything =>
      _storage.getItem(_stateKey) != null ||
      _storage.getItem(_prefsKey) != null;

  Future<bool> hasDatabase() =>
      BackgroundDatabaseConnection.storedDatabaseExists(paths.databaseFile);

  Future<void> capturePrefs(SharedPreferences prefs) async =>
      _storage.setItem(_prefsKey, PrefsSnapshot.encode(prefs));

  Future<bool> restorePrefs(SharedPreferences prefs) async {
    final encoded = _storage.getItem(_prefsKey);
    if (encoded == null) return false;
    await PrefsSnapshot.restoreEncoded(prefs, encoded);
    return true;
  }

  /// Sample photos are links to the site in a browser; none are stored.
  Future<List<String>> photoPaths() async => const [];

  /// Forget this device clears what demo mode keeps in local storage.
  static void clearBrowserState() {
    _storage.removeItem(_stateKey);
    _storage.removeItem(_prefsKey);
  }
}
