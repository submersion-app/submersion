import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:photo_manager/photo_manager.dart';

/// PhotoKit's cloud identifiers for local gallery asset ids (media sync
/// program spec 6.2). A cloud identifier names the same photo on every
/// device sharing an iCloud Photos library, where local ids differ.
abstract interface class CloudIdentifierSource {
  /// Whether this platform can answer at all: false where there are no
  /// iCloud identifiers (Android, Windows, Linux), so callers skip the work
  /// of asking instead of asking and hearing nothing.
  bool get isSupported;

  /// The cloud identifier of each of [localIds] that has one. An id with
  /// none (iCloud Photos off, an OS before iOS 15 or macOS 12, an asset
  /// that is not in the library) is absent from the result.
  Future<Map<String, String>> cloudIdentifiers(List<String> localIds);
}

/// [CloudIdentifierSource] over `PhotoManager.plugin.getCloudIdentifiers`,
/// one platform call per chunk. Not `AssetEntity.darwin.cloudIdentifier`:
/// that is a one-id wrapper over the same call, and it throws off Apple
/// platforms, where this answers nothing instead.
class PhotoManagerCloudIdentifierSource implements CloudIdentifierSource {
  const PhotoManagerCloudIdentifierSource()
    : _supported = null,
      _fetch = null,
      _chunkSize = 500;

  @visibleForTesting
  const PhotoManagerCloudIdentifierSource.withFetch({
    required bool supported,
    required Future<Map<String, String?>> Function(List<String> ids) fetch,
    int chunkSize = 500,
  }) : _supported = supported,
       _fetch = fetch,
       _chunkSize = chunkSize;

  final bool? _supported;
  final Future<Map<String, String?>> Function(List<String> ids)? _fetch;
  final int _chunkSize;

  @override
  bool get isSupported => _supported ?? (Platform.isIOS || Platform.isMacOS);

  Future<Map<String, String?>> _call(List<String> ids) =>
      (_fetch ?? PhotoManager.plugin.getCloudIdentifiers)(ids);

  @override
  Future<Map<String, String>> cloudIdentifiers(List<String> localIds) async {
    if (localIds.isEmpty || !isSupported) return const {};
    final found = <String, String>{};
    for (var i = 0; i < localIds.length; i += _chunkSize) {
      final end = i + _chunkSize < localIds.length
          ? i + _chunkSize
          : localIds.length;
      final answer = await _call(localIds.sublist(i, end));
      for (final entry in answer.entries) {
        final cloudId = entry.value;
        if (cloudId != null && cloudId.isNotEmpty) found[entry.key] = cloudId;
      }
    }
    return found;
  }
}
