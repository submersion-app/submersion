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
    // Confirm the absence before minting, because [read] cannot tell "this
    // store has no marker" from "this device cannot see it yet". On iCloud a
    // marker another device wrote has no local entry at all until the
    // container's metadata reaches this device, and the native download
    // check answers "nothing to do" for a path it has never heard of - so
    // the read fails as absent and minting overwrites the other device's
    // marker, splitting one store into two (issue #1356).
    //
    // A listing is the one call that makes an adapter go and look: the
    // iCloud adapter refreshes the container folder before enumerating it.
    // It costs one request, on the mint path only.
    if (await _markerVisibleInListing()) {
      final afterListing = await read();
      if (afterListing != null) {
        return (marker: afterListing, created: false);
      }
    }
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

  /// Whether a listing can see the marker this device failed to read.
  ///
  /// Never blocks a first connect: a store that cannot serve the listing
  /// answers the same as one that has no marker, which is the state a first
  /// connect is entitled to assume.
  Future<bool> _markerVisibleInListing() async {
    try {
      return await _store
          .list(StoreKeys.markerKey)
          .any((object) => object.key == StoreKeys.markerKey);
    } on Object {
      return false;
    }
  }
}
