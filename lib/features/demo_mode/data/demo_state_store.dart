import 'dart:convert';
import 'dart:io';

import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

/// Reads and writes the persisted [DemoState].
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
}
