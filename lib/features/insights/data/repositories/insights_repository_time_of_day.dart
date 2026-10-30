part of 'insights_repository.dart';

/// Dives per [TimeOfDayBucket] (issue #3340).
class TimeOfDayDistribution {
  const TimeOfDayDistribution({
    required this.segments,
    required this.divesWithoutLocation,
  });

  static const TimeOfDayDistribution empty = TimeOfDayDistribution(
    segments: [],
    divesWithoutLocation: 0,
  );

  /// One segment per bucket that has dives, in the order of the day. Each
  /// label is a [TimeOfDayBucket.key], not display text; the presentation
  /// layer translates it through `timeOfDayDistributionLabel`.
  final List<DistributionSegment> segments;

  /// The dives bucketed on the fallback clock times because they have no
  /// site, or their site has no usable coordinates. A dive at a placed site
  /// where the sun did not rise or set is not counted here.
  final int divesWithoutLocation;
}

/// The Time patterns "Dives by Time of Day" distribution, kept beside the
/// repository so the main file does not grow further; a part shares its
/// scope helpers.
extension InsightsRepositoryTimeOfDay on InsightsRepository {
  /// Dives bucketed by entry and exit against sunrise and sunset at the
  /// dive site (issue #3340).
  ///
  /// Sunrise and sunset depend on the site and the date, which SQL cannot
  /// work out, so the query only reads each in-scope dive's times and site
  /// coordinates and [TimeOfDayClassifier] buckets them here.
  Future<TimeOfDayDistribution> getDivesByTimeOfDay({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = [?diverId, ...df.params];

      final results = await _db.customSelect('''
        SELECT
          ${diveStartMillisSql('d')} AS start_ms,
          ${diveExitMillisSql('d')} AS exit_ms,
          s.latitude AS site_latitude,
          s.longitude AS site_longitude
        FROM dives d
        LEFT JOIN dive_sites s ON s.id = d.site_id
        WHERE 1 = 1 $diverFilter ${df.clause}
        ''', variables: params.map((p) => Variable(p)).toList()).get();
      if (results.isEmpty) return TimeOfDayDistribution.empty;

      final classifier = TimeOfDayClassifier();
      final counts = <TimeOfDayBucket, int>{};
      var divesWithoutLocation = 0;
      for (final row in results) {
        final exitMs = row.read<int?>('exit_ms');
        final result = classifier.classify(
          entry: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('start_ms'),
            isUtc: true,
          ),
          exit: exitMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(exitMs, isUtc: true),
          latitude: row.read<double?>('site_latitude'),
          longitude: row.read<double?>('site_longitude'),
        );
        counts[result.bucket] = (counts[result.bucket] ?? 0) + 1;
        if (result.basis == SunTimesBasis.noLocation) divesWithoutLocation++;
      }

      return TimeOfDayDistribution(
        segments: [
          for (final bucket in TimeOfDayBucket.values)
            if (counts[bucket] case final count?)
              DistributionSegment(
                label: bucket.key,
                count: count,
                percentage: count / results.length * 100,
              ),
        ],
        divesWithoutLocation: divesWithoutLocation,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives by time of day',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
