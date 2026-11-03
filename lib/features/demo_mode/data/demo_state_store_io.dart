import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/prefs_snapshot.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

/// Reads and writes the persisted [DemoState], and everything else demo mode
/// keeps: the preferences snapshot, the sample logbook and its photos, all
/// under [DemoPaths.root].
///
/// A write goes to a temporary file that is renamed into place, so a crash
/// mid-write leaves either the old state or the new one, never half of one.
class DemoStateStore {
  const DemoStateStore(this.paths);

  final DemoPaths paths;

  /// The current state, or null when demo mode is off or the file cannot be
  /// read as a state.
  Future<DemoState?> read() async {
    final file = File(paths.stateFile);
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) return null;
      return DemoState.fromJson(json);
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> write(DemoState state) async {
    await Directory(paths.root).create(recursive: true);
    final tmp = File('${paths.stateFile}.tmp');
    await tmp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await tmp.rename(paths.stateFile);
  }

  /// Removes the whole demo directory: state, database, download and photos.
  Future<void> deleteAll() async {
    final root = Directory(paths.root);
    if (await root.exists()) await root.delete(recursive: true);
  }

  /// Whether demo mode left anything here. A synchronous stat, so a launch
  /// (and every startup widget test, whose zone never completes `dart:io`
  /// futures) does no async file work when demo mode was never used.
  bool get hasAnything => Directory(paths.root).existsSync();

  /// Whether the sample logbook is there to reopen.
  Future<bool> hasDatabase() => File(paths.databaseFile).exists();

  /// Saves every app-wide preference before demo mode changes any.
  Future<void> capturePrefs(SharedPreferences prefs) =>
      PrefsSnapshot.capture(prefs, File(paths.prefsSnapshotFile));

  /// Puts the saved preferences back; false when none were saved. Throws
  /// [StateError] for a snapshot that cannot be read, changing nothing.
  Future<bool> restorePrefs(SharedPreferences prefs) async {
    final snapshot = File(paths.prefsSnapshotFile);
    if (!await snapshot.exists()) return false;
    await PrefsSnapshot.restore(prefs, snapshot);
    return true;
  }

  /// A browser's Forget this device clears what demo mode keeps in local
  /// storage; natively demo mode keeps nothing there.
  static void clearBrowserState() {}

  /// The sample photos on disk, in name order, for their caches to clear.
  Future<List<String>> photoPaths() async {
    final dir = Directory(paths.photosDir);
    if (!await dir.exists()) return const [];
    return [
      await for (final entry in dir.list())
        if (entry is File) entry.path,
    ]..sort();
  }
}
