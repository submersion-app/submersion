import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Saves every app-wide preference on entering demo mode and puts them back
/// on exit.
///
/// About 185 settings live in SharedPreferences rather than the database
/// (the selected diver, sync and backup settings, storage location and many
/// display choices), and demo mode would otherwise change some of them, for
/// example when the selected diver is repaired to the demo diver. Restoring
/// the whole set is simpler and safer than tracking which keys demo mode
/// touched: after exit every preference reads exactly as it did before entry.
class PrefsSnapshot {
  PrefsSnapshot._();

  static const _version = 1;

  static Future<void> capture(SharedPreferences prefs, File file) async {
    final values = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      final type = switch (value) {
        bool() => 'bool',
        int() => 'int',
        double() => 'double',
        String() => 'string',
        List() => 'stringList',
        _ => null,
      };
      if (type != null) values[key] = {'t': type, 'v': value};
    }
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({'version': _version, 'values': values}),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  /// Replaces every preference with the snapshot in [file].
  ///
  /// Throws [StateError] without changing anything when the snapshot is
  /// missing or unreadable: wiping the user's settings because a snapshot
  /// went astray would be worse than leaving demo values behind.
  static Future<void> restore(SharedPreferences prefs, File file) async {
    final entries = await _read(file);
    for (final key in prefs.getKeys().toList()) {
      if (!entries.containsKey(key)) await prefs.remove(key);
    }
    for (final MapEntry(:key, :value) in entries.entries) {
      switch (value) {
        case final bool v:
          await prefs.setBool(key, v);
        case final int v:
          await prefs.setInt(key, v);
        case final double v:
          await prefs.setDouble(key, v);
        case final String v:
          await prefs.setString(key, v);
        case final List<String> v:
          await prefs.setStringList(key, v);
      }
    }
  }

  static Future<Map<String, Object>> _read(File file) async {
    if (!await file.exists()) {
      throw StateError('No preferences snapshot at ${file.path}');
    }
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map || json['version'] != _version) {
        throw const FormatException('unknown snapshot version');
      }
      final values = json['values'] as Map;
      return {
        for (final MapEntry(:key, :value) in values.entries)
          key as String: _typed(value as Map),
      };
    } on FormatException catch (e) {
      throw StateError('Unreadable preferences snapshot: $e');
    } on TypeError catch (e) {
      throw StateError('Unreadable preferences snapshot: $e');
    }
  }

  static Object _typed(Map entry) {
    final v = entry['v'];
    return switch (entry['t']) {
      'bool' => v as bool,
      'int' => v as int,
      'double' => (v as num).toDouble(),
      'string' => v as String,
      'stringList' => (v as List).cast<String>().toList(),
      _ => throw FormatException('unknown preference type ${entry['t']}'),
    };
  }
}
