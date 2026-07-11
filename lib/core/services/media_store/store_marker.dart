import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';

/// Identity marker at smv1/store.json (design spec sections 7 and 13).
class StoreMarker {
  final String storeId;
  final int formatVersion;
  final String createdAt;

  const StoreMarker({
    required this.storeId,
    required this.formatVersion,
    required this.createdAt,
  });

  Map<String, Object?> toJson() => {
    'storeId': storeId,
    'formatVersion': formatVersion,
    'createdAt': createdAt,
  };

  static StoreMarker? fromJson(Object? decoded) {
    if (decoded is! Map<String, Object?>) return null;
    final storeId = decoded['storeId'];
    if (storeId is! String || storeId.isEmpty) return null;
    return StoreMarker(
      storeId: storeId,
      formatVersion: (decoded['formatVersion'] as num?)?.toInt() ?? 1,
      createdAt: decoded['createdAt'] as String? ?? '',
    );
  }
}

/// Reads/creates the marker through a [MediaObjectStore].
class StoreMarkerStore {
  StoreMarkerStore({required MediaObjectStore store}) : _store = store;

  final MediaObjectStore _store;

  Future<StoreMarker?> read() async {
    // App-container temp dir: hardened-runtime macOS denies /tmp
    // (Directory.systemTemp), same constraint sync hit in issue #509.
    final tmpDir = await resolveSyncTempDir();
    final tmp = File(
      '${tmpDir.path}/'
      'submersion_marker_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    try {
      await _store.getFile(StoreKeys.markerKey, tmp);
      final decoded = jsonDecode(await tmp.readAsString());
      return StoreMarker.fromJson(decoded);
    } on MediaStoreException catch (e) {
      if (e.kind == MediaStoreErrorKind.notFound) return null;
      rethrow;
    } on FormatException {
      return null;
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  /// Reads the marker, writing a fresh one (new UUID) when absent.
  Future<({StoreMarker marker, bool created})> ensure() async {
    final existing = await read();
    if (existing != null) return (marker: existing, created: false);
    final marker = StoreMarker(
      storeId: const Uuid().v4(),
      formatVersion: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final tmpDir = await resolveSyncTempDir();
    final tmp = File(
      '${tmpDir.path}/'
      'submersion_marker_w_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    try {
      await tmp.writeAsString(jsonEncode(marker.toJson()), flush: true);
      await _store.putFile(
        StoreKeys.markerKey,
        tmp,
        contentType: 'application/json',
      );
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
    return (marker: marker, created: true);
  }
}
