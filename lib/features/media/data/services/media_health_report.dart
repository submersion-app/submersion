import 'package:submersion/core/services/log_redactor.dart';

/// One media row as the health report sees it: the synced facts, this
/// device's local cache and resolver verdicts, the store verdict and the
/// transfer queue entry, side by side. Every field is plain data so the
/// report can be rendered as text for a clipboard or serialised as JSON.
class MediaHealthRow {
  const MediaHealthRow({
    required this.mediaId,
    required this.sourceType,
    this.originalFilename,
    this.filePath,
    this.localPath,
    this.platformAssetId,
    this.pointer,
    required this.takenAt,
    this.diveId,
    this.siteId,
    this.originDeviceId,
    this.originDeviceName,
    this.linkedHere,
    this.contentHash,
    this.contentSizeBytes,
    this.remoteUploadedAt,
    this.remoteThumbUploadedAt,
    this.remoteCompressedUploadedAt,
    required this.isOrphaned,
    this.lastVerifiedAt,
    this.hlc,
    required this.pending,
    this.cachedAssetId,
    this.cacheMethod,
    this.cacheAttempts,
    this.cacheExpired,
    this.cacheNextRetryAt,
    required this.resolverVerdict,
    this.storeObjectExists,
    this.storeObjectTier,
    this.queueState,
    this.queueAttempts,
    this.queueNextAttemptAt,
    this.queueWaiting,
    this.queueError,
  });

  final String mediaId;
  final String sourceType;
  final String? originalFilename;
  final String? filePath;
  final String? localPath;
  final String? platformAssetId;
  final DateTime takenAt;
  final String? diveId;
  final String? siteId;

  final String? originDeviceId;
  final String? originDeviceName;

  /// True when the row was linked on this device, false when on another,
  /// null when the row carries no origin at all (linked before origins were
  /// recorded): unknown is not evidence of either.
  final bool? linkedHere;

  final String? contentHash;
  final int? contentSizeBytes;
  final DateTime? remoteUploadedAt;
  final DateTime? remoteThumbUploadedAt;
  final DateTime? remoteCompressedUploadedAt;
  final bool isOrphaned;
  final DateTime? lastVerifiedAt;
  final String? hlc;

  /// Whether a pending sync record exists for the row on this device.
  final bool pending;

  final String? cachedAssetId;
  final String? cacheMethod;
  final int? cacheAttempts;
  final bool? cacheExpired;

  /// When an `unresolved` cache entry next allows a gallery search.
  final DateTime? cacheNextRetryAt;

  /// `available`, an `UnavailableKind` name, `error: ...`, or `notProbed:`
  /// with a reason for the source types the report reads from stored state
  /// rather than checking live (see `MediaHealthReporter._skipReason`). For
  /// those rows `is_orphaned`, `last_verified_at` and the cache block are
  /// the verdict, written by the service that owns the live check.
  final String resolverVerdict;

  /// Null when the store was not probed.
  final bool? storeObjectExists;

  /// `original`, `rendition` or `thumbnail` when the object exists.
  final String? storeObjectTier;

  final String? queueState;
  final int? queueAttempts;
  final DateTime? queueNextAttemptAt;

  /// True when the queue entry is parked until [queueNextAttemptAt].
  final bool? queueWaiting;
  final String? queueError;

  /// The locator this row's source type actually uses, chosen by
  /// `OriginFacts._pointerFor`: the asset id for a gallery row, a path or
  /// bookmark for a local file, the URL for a network or manifest row, the
  /// remote asset id for a connector row, the content hash for a store row,
  /// and null for a signature, which references nothing a reader could act
  /// on. Derived from the three path columns this row happens to carry, it
  /// would read null for most of those types.
  final String? pointer;

  Map<String, Object?> toJson() => _redacted({
    'media_id': mediaId,
    'source_type': sourceType,
    'original_filename': originalFilename,
    'file_path': filePath,
    'local_path': localPath,
    'platform_asset_id': platformAssetId,
    'pointer': pointer,
    'taken_at': _ts(takenAt),
    'dive_id': diveId,
    'site_id': siteId,
    'origin_device_id': originDeviceId,
    'origin_device_name': originDeviceName,
    'linked_here': linkedHere,
    'content_hash': contentHash,
    'content_size_bytes': contentSizeBytes,
    'remote_uploaded_at': _ts(remoteUploadedAt),
    'remote_thumb_uploaded_at': _ts(remoteThumbUploadedAt),
    'remote_compressed_uploaded_at': _ts(remoteCompressedUploadedAt),
    'is_orphaned': isOrphaned,
    'last_verified_at': _ts(lastVerifiedAt),
    'hlc': hlc,
    'pending': pending,
    'cached_asset_id': cachedAssetId,
    'cache_method': cacheMethod,
    'cache_attempts': cacheAttempts,
    'cache_expired': cacheExpired,
    'cache_next_retry_at': _ts(cacheNextRetryAt),
    'resolver_verdict': resolverVerdict,
    'store_object_exists': storeObjectExists,
    'store_object_tier': storeObjectTier,
    'queue_state': queueState,
    'queue_attempts': queueAttempts,
    'queue_next_attempt_at': _ts(queueNextAttemptAt),
    'queue_waiting': queueWaiting,
    'queue_error': queueError,
  });

  String toText() {
    final origin = switch (originDeviceId) {
      null => 'unknown',
      final id => [
        id,
        if (originDeviceName != null) '($originDeviceName)',
        if (linkedHere == true) '(this device)',
      ].join(' '),
    };
    final cache = cacheMethod == null
        ? 'none'
        : [
            cacheMethod,
            if (cachedAssetId != null) 'asset $cachedAssetId',
            'attempts ${cacheAttempts ?? 0}',
            if (cacheExpired != null) (cacheExpired! ? 'expired' : 'fresh'),
            if (cacheNextRetryAt != null) 'next retry ${_ts(cacheNextRetryAt)}',
          ].join(', ');
    final store = switch (storeObjectExists) {
      null => 'not probed',
      true => 'exists as ${storeObjectTier ?? 'unknown tier'}',
      false => 'missing',
    };
    final queue = queueState == null
        ? 'none'
        : [
            queueState,
            'attempts ${queueAttempts ?? 0}',
            if (queueWaiting == true && queueNextAttemptAt != null)
              'waiting until ${_ts(queueNextAttemptAt)}',
            if (queueError != null) 'error: $queueError',
          ].join(', ');
    return redactSecrets(
      [
        'media_id: $mediaId',
        'source_type: $sourceType',
        'original_filename: ${originalFilename ?? 'null'}',
        'pointer: ${pointer ?? 'null'}',
        'taken_at: ${_ts(takenAt)}',
        'dive_id: ${diveId ?? 'null'}',
        'site_id: ${siteId ?? 'null'}',
        'origin_device: $origin',
        'content_hash: ${contentHash ?? 'null'}',
        'content_size_bytes: ${contentSizeBytes ?? 'null'}',
        'remote_uploaded_at: ${_ts(remoteUploadedAt)}',
        'remote_thumb_uploaded_at: ${_ts(remoteThumbUploadedAt)}',
        'remote_compressed_uploaded_at: ${_ts(remoteCompressedUploadedAt)}',
        'is_orphaned: $isOrphaned',
        'last_verified_at: ${_ts(lastVerifiedAt)}',
        'hlc: ${hlc ?? 'null'}',
        'pending: $pending',
        'cache: $cache',
        'resolver_verdict: $resolverVerdict',
        'store_object: $store',
        'queue: $queue',
      ].join('\n'),
    );
  }
}

/// A set of [MediaHealthRow]s with the device and store context they were
/// produced under. A single-row report carries the same header, so a copied
/// diagnostic for one photo still says which store the device is attached
/// to and which marker the store holds.
class MediaHealthReport {
  const MediaHealthReport({
    required this.generatedAt,
    required this.deviceId,
    this.deviceName,
    this.attachedStoreId,
    this.markerStoreId,
    required this.rows,
  });

  final DateTime generatedAt;
  final String deviceId;
  final String? deviceName;
  final String? attachedStoreId;

  /// The id the store's own marker carries; a mismatch with
  /// [attachedStoreId] is why transfers stay suspended.
  final String? markerStoreId;
  final List<MediaHealthRow> rows;

  Map<String, Object?> toJson() => {
    ..._redacted({
      'generated_at': _ts(generatedAt),
      'device_id': deviceId,
      'device_name': deviceName,
      'attached_store_id': attachedStoreId,
      'marker_store_id': markerStoreId,
    }),
    'rows': [for (final r in rows) r.toJson()],
  };

  String toText() => [
    redactSecrets(
      [
        'Submersion media health report',
        'generated_at: ${_ts(generatedAt)}',
        'device: $deviceId (${deviceName ?? 'unnamed'})',
        'attached_store: ${attachedStoreId ?? 'none'}',
        'marker_store: ${markerStoreId ?? 'none'}',
        'rows: ${rows.length}',
      ].join('\n'),
    ),
    '',
    for (final r in rows) ...[r.toText(), ''],
  ].join('\n');
}

/// Every rendering of a report goes through [redactSecrets], the same
/// backstop the persisted log uses.
///
/// The report is built to be pasted into a public bug thread, and it prints
/// each row's source locator verbatim: a media or manifest URL can carry
/// `?access_token=`, `?signature=` or `user:password@`, and a queue error is
/// an exception's `toString()`, which can carry a request URL or a header
/// nobody chose to log. The redactor recognises those by field name and
/// shape, so the paths, device names and hashes the report exists to show
/// pass through untouched.
Map<String, Object?> _redacted(Map<String, Object?> row) => {
  for (final e in row.entries)
    e.key: e.value is String ? redactSecrets(e.value as String) : e.value,
};

String _ts(DateTime? t) => t?.toUtc().toIso8601String() ?? 'null';
