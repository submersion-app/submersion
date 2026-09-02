/// A single profile sample's decompression-relevant fields, independent of
/// any particular profile-point entity so this detector can be shared by
/// every import path (file import, dive computer download, cloud import)
/// without those features depending on each other.
class DecoDiveSample {
  final double depth;
  final int? ndl;
  final double? ceiling;
  final int? decoType;
  final int? tts;

  const DecoDiveSample({
    required this.depth,
    this.ndl,
    this.ceiling,
    this.decoType,
    this.tts,
  });
}

/// Detects whether a dive incurred a decompression obligation, based on the
/// profile samples and events a source provided.
///
/// Many import sources (dive computer downloads, Suunto/Shearwater cloud
/// exports, Subsurface, UDDF, FIT) carry no explicit dive type, so imported
/// dives used to default to "recreational" even when the profile clearly
/// shows mandatory deco. Callers use this detector to default such dives to
/// the built-in "technical" type instead.
class DecoDiveDetector {
  DecoDiveDetector._();

  /// Samples this close to the surface are ignored for the exhausted-NDL
  /// signal: some computers zero out NDL on surface samples.
  static const double _surfaceDepthMeters = 1.0;

  /// `decoType` value meaning a mandatory deco stop (0=NDL, 1=safety stop,
  /// 2=deco stop, 3=deep stop).
  static const int _decoStopSampleType = 2;

  /// Parser event names that prove a deco obligation. Matches the event
  /// names consumed by the UDDF importer's profile-event persistence.
  static const Set<String> _decoEventTypes = {'decoStopStart', 'decoViolation'};

  /// Returns true when the profile or events show a decompression
  /// obligation: a positive deco ceiling, a deco stop sample, an exhausted
  /// NDL with time-to-surface remaining while at depth, or a deco stop /
  /// deco violation event.
  static bool isDecoDive({
    required Iterable<DecoDiveSample> samples,
    List<Map<String, dynamic>>? eventMaps,
  }) {
    for (final sample in samples) {
      if ((sample.ceiling ?? 0) > 0) return true;
      if (sample.decoType == _decoStopSampleType) return true;
      final inDecoByNdl =
          sample.ndl == 0 &&
          (sample.tts ?? 0) > 0 &&
          sample.depth > _surfaceDepthMeters;
      if (inDecoByNdl) return true;
    }

    if (eventMaps != null) {
      for (final event in eventMaps) {
        final eventType = event['eventType'];
        if (eventType is String && _decoEventTypes.contains(eventType)) {
          return true;
        }
      }
    }

    return false;
  }
}
