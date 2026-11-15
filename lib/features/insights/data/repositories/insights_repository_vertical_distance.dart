part of 'insights_repository.dart';

/// The cache key for one dive's figure: the algorithm version and the
/// fingerprint of its primary series rows.
String verticalDistanceInputsHash(String seriesFingerprint) =>
    'v$verticalDistanceAlgorithmVersion|$seriesFingerprint';

/// The Profile page's total ascent and descent (issue #4569), kept beside the
/// repository so the main file does not grow further; a part shares its
/// scope helpers.
extension InsightsRepositoryVerticalDistance on InsightsRepository {
  /// Every in-scope dive's vertical distance, in dive order.
  ///
  /// A dive with a primary profile counts its profile's figure, never less
  /// than its stored max depth. A dive without one counts its max depth and
  /// is marked estimated. Profile figures come from the device-only cache
  /// when its fingerprint still matches; only new or changed profiles are
  /// decoded, on a worker isolate, and written back.
  ///
  /// The cache is a convenience: a failure to read or write it is logged and
  /// the figures are worked out without it. [cache] defaults to the device's
  /// cache database; tests pass their own.
  Future<VerticalDistanceTimeline> getVerticalDistanceTimeline({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    VerticalDistanceCacheRepository? cache,
  }) async {
    final List<QueryRow> rows;
    final Map<String, String> fingerprints;
    try {
      rows = await _verticalDistanceDiveRows(diverId, filter);
      if (rows.isEmpty) return VerticalDistanceTimeline.empty;
      fingerprints = await _primarySeriesFingerprints([
        for (final r in rows) r.read<String>('id'),
      ]);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get vertical distance timeline',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    final figures = await _profileVerticalDistances(
      fingerprints,
      cache ?? VerticalDistanceCacheRepository(),
    );

    return VerticalDistanceTimeline([
      for (final r in rows)
        _diveVerticalDistance(
          r.read<String>('id'),
          r.read<int>('start_ms'),
          r.readNullable<double>('max_depth'),
          figures[r.read<String>('id')],
        ),
    ]);
  }

  /// Every in-scope dive's max depth, in dive order: each dive counted once
  /// straight down to its deepest point and back, whatever its profile did
  /// on the way. A dive with no max depth adds nothing. Reads no profiles,
  /// so it needs no cache.
  Future<VerticalDistanceTimeline> getMaxDepthTimeline({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final rows = await _verticalDistanceDiveRows(diverId, filter);
      return VerticalDistanceTimeline([
        for (final r in rows)
          DiveVerticalDistance(
            diveId: r.read<String>('id'),
            startMillis: r.read<int>('start_ms'),
            meters: r.readNullable<double>('max_depth') ?? 0,
            estimated: false,
          ),
      ]);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get max depth timeline',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The in-scope dives' id, start and max depth, in dive order: the rows
  /// both timelines are built from.
  Future<List<QueryRow>> _verticalDistanceDiveRows(
    String? diverId,
    DiveFilterState filter,
  ) {
    final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
    final df = _diveFilter(filter, alias: 'd');
    final params = [?diverId, ...df.params];
    return _db
        .customSelect(
          '''
      SELECT
        d.id AS id,
        ${diveStartMillisSql('d')} AS start_ms,
        d.max_depth AS max_depth
      FROM dives d
      WHERE 1 = 1 $diverFilter ${df.clause}
      ORDER BY start_ms, d.id
      ''',
          variables: params.map((p) => Variable(p)).toList(),
          readsFrom: {_db.dives},
        )
        .get();
  }

  DiveVerticalDistance _diveVerticalDistance(
    String id,
    int startMillis,
    double? maxDepth,
    double? profileMeters,
  ) {
    final floor = maxDepth ?? 0;
    // A profile with nothing measured in it (every depth unusable, or a blob
    // that would not decode) is no profile: the dive counts its max depth and
    // says so.
    final measured = profileMeters != null && profileMeters > 0;
    return DiveVerticalDistance(
      diveId: id,
      startMillis: startMillis,
      meters: measured
          ? (profileMeters > floor ? profileMeters : floor)
          : floor,
      estimated: !measured,
    );
  }

  /// Each dive's primary-series fingerprint, for the dives that have one.
  /// Built from row metadata only, never the blobs: each row's id,
  /// `updated_at` and `sample_count`, in stored order.
  Future<Map<String, String>> _primarySeriesFingerprints(
    List<String> diveIds,
  ) async {
    final parts = <String, List<String>>{};
    for (final chunk in seriesIdChunks(diveIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT dive_id, id, updated_at, sample_count '
            'FROM dive_profile_series '
            'WHERE is_primary = 1 AND dive_id IN ($placeholders) '
            'ORDER BY dive_id, start_timestamp, id',
            variables: [for (final id in chunk) Variable(id)],
            readsFrom: {_db.diveProfileSeries},
          )
          .get();
      for (final r in rows) {
        parts
            .putIfAbsent(r.read<String>('dive_id'), () => [])
            .add(
              '${r.read<String>('id')}:${r.read<int>('updated_at')}:'
              '${r.read<int>('sample_count')}',
            );
      }
    }
    return {for (final e in parts.entries) e.key: e.value.join(',')};
  }

  /// Profile figures for the fingerprinted dives: cached where the hash
  /// matches, decoded on a worker otherwise. A dive whose blobs all fail to
  /// decode gets 0, measured nothing. When the cache cannot be read it is
  /// not written either, and after one failed write it is not written
  /// again: a cache that is not there is not retried per chunk.
  Future<Map<String, double>> _profileVerticalDistances(
    Map<String, String> fingerprints,
    VerticalDistanceCacheRepository cache,
  ) async {
    if (fingerprints.isEmpty) return const {};
    final hashes = {
      for (final e in fingerprints.entries)
        e.key: verticalDistanceInputsHash(e.value),
    };

    var stored = <String, VerticalDistanceCacheEntry>{};
    var cacheUsable = true;
    try {
      stored = await cache.getEntries(hashes.keys.toSet());
    } catch (e, stackTrace) {
      cacheUsable = false;
      _log.error(
        'Failed to read the vertical distance cache',
        error: e,
        stackTrace: stackTrace,
      );
    }

    final figures = <String, double>{};
    final misses = <String>[];
    for (final MapEntry(key: id, value: hash) in hashes.entries) {
      final entry = stored[id];
      if (entry != null && entry.inputsHash == hash) {
        figures[id] = entry.meters;
      } else {
        misses.add(id);
      }
    }

    // Each chunk is written as soon as it is worked out, so a first load of
    // a large library that is interrupted keeps what it finished. A dive
    // whose blobs would not decode is cached as 0, measured nothing, so it
    // is not decoded again until its profile changes.
    for (final chunk in InsightsRepository._diveChunks(misses)) {
      final Map<String, double> computed;
      try {
        final blobs = await _primaryBlobs(chunk);
        computed = blobs.isEmpty
            ? const {}
            : await compute(verticalDistanceByDiveFromBlobs, blobs);
      } catch (e, stackTrace) {
        _log.error(
          'Failed to work out vertical distances',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
      final entries = {
        for (final id in chunk)
          id: (meters: computed[id] ?? 0.0, inputsHash: hashes[id]!),
      };
      for (final MapEntry(key: id, value: e) in entries.entries) {
        figures[id] = e.meters;
      }
      if (!cacheUsable) continue;
      try {
        await cache.putAll(entries);
      } catch (e, stackTrace) {
        cacheUsable = false;
        _log.error(
          'Failed to write the vertical distance cache',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    return figures;
  }
}
