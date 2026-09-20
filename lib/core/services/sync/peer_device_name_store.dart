import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The display names peers published on their sync manifests, keyed by
/// device id, so the app can say "From Eric's MacBook" without a cloud read.
///
/// Manifests are the only place a peer's name lives; the sync layer keeps
/// this map current on every pull and every adopt. A device that never
/// published a name has no entry, and callers fall back to a generic label.
/// This device's own name is not here either: a pull excludes its own
/// manifest, and the device identity service already knows it.
class PeerDeviceNameStore {
  PeerDeviceNameStore(this._prefs);

  static const prefsKey = 'sync_peer_device_names';

  final SharedPreferences _prefs;
  final _changes = StreamController<Map<String, String>>.broadcast();

  /// Every known peer name. A corrupt or missing preference reads as empty.
  Map<String, String> all() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return const {};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const {};
    }
    if (decoded is! Map) return const {};
    return {
      for (final e in decoded.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
  }

  String? nameFor(String deviceId) => all()[deviceId];

  /// Remembers [name] for [deviceId], or forgets the peer when [name] is
  /// null or empty. An unchanged entry is a no-op, so a sync that sees the
  /// same manifests emits nothing.
  ///
  /// A nameless manifest is not missing information: the manifest is the
  /// only place a peer's name lives, so a peer that clears its name, or
  /// downgrades to a version that publishes none, must stop being labelled
  /// with the name it used to publish. Callers pass whatever the manifest
  /// carried, including null, and only skip the call when they could not
  /// read the manifest at all.
  Future<void> record(String deviceId, String? name) async {
    final current = all();
    if (name == null || name.isEmpty) {
      if (!current.containsKey(deviceId)) return;
      await _write({...current}..remove(deviceId));
      return;
    }
    if (current[deviceId] == name) return;
    await _write({...current, deviceId: name});
  }

  Future<void> _write(Map<String, String> next) async {
    await _prefs.setString(prefsKey, jsonEncode(next));
    _changes.add(next);
  }

  /// The full map after every change, so a label built before a sync
  /// learned a name updates without being recreated.
  Stream<Map<String, String>> get changes => _changes.stream;

  void dispose() => _changes.close();
}
