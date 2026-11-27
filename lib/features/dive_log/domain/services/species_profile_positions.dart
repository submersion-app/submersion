import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/species_crops.dart';

/// One moment a species was seen: a typed time, a photo or a clip of
/// unknown length.
typedef SpeciesMoment = ({int seconds, double depthMeters});

/// A stretch of the dive a species was in view on video, with the
/// shallowest and deepest profile depth inside it.
typedef SpeciesSpan = ({int start, int end, double minDepth, double maxDepth});

/// Where on a dive's profile one species was seen (issue #5092). Times are
/// seconds from the dive start, the profile's time axis.
class SpeciesProfilePositions {
  const SpeciesProfilePositions({required this.moments, required this.spans});

  SpeciesProfilePositions copyWith({
    List<SpeciesMoment>? moments,
    List<SpeciesSpan>? spans,
  }) => SpeciesProfilePositions(
    moments: moments ?? this.moments,
    spans: spans ?? this.spans,
  );

  /// Time-sorted.
  final List<SpeciesMoment> moments;

  /// Time-sorted, with overlapping or touching spans merged.
  final List<SpeciesSpan> spans;

  bool get isEmpty => moments.isEmpty && spans.isEmpty;

  /// The shallowest depth over every moment and span. Only for a
  /// non-empty position set.
  double get minDepthMeters => [
    for (final m in moments) m.depthMeters,
    for (final s in spans) s.minDepth,
  ].reduce(math.min);

  /// The deepest depth over every moment and span. Only for a non-empty
  /// position set.
  double get maxDepthMeters => [
    for (final m in moments) m.depthMeters,
    for (final s in spans) s.maxDepth,
  ].reduce(math.max);
}

/// Where each species sighted on a dive was seen on [profile], keyed by
/// species id, for the species that have any position.
///
/// The positions are, all together: the sighting's own time (a moment at
/// the profile depth then, when it falls on the profile); each photo tagged with the species (a moment
/// where its camera chip sits); each video tagged with it (a span per
/// stretch its accepted tracks were in view, or the whole clip when it has
/// none). Tags the app applied and the diver has not confirmed count like
/// the diver's own. A species tagged on media but not sighted on the dive
/// has no entry. An empty profile places nothing.
Map<String, SpeciesProfilePositions> speciesProfilePositions({
  required List<Sighting> sightings,
  required List<MediaItem> media,
  required Map<String, List<MediaSpeciesTag>> tagsByMedia,
  required Map<String, List<MediaIdentification>> identificationsByMedia,
  required List<DiveProfilePoint> profile,
}) {
  if (profile.isEmpty) return const {};
  final last = profile.last.timestamp;
  final placed = [
    for (final item in media) ?photoMarkerFor(item, maxProfileSeconds: last),
  ];

  final result = <String, SpeciesProfilePositions>{};
  // One pass per species: a dive can hold two sightings of one species,
  // and every typed time counts while its media count once.
  for (final speciesId in {for (final s in sightings) s.speciesId}) {
    final moments = <SpeciesMoment>[];
    final spans = <(int, int)>[];

    for (final sighting in sightings) {
      if (sighting.speciesId != speciesId) continue;
      final typed = sighting.seenAtSeconds;
      // Past the profile (a split, a shorter source) it has no place: a
      // clamped time would show a depth the diver cannot trace.
      if (typed == null || typed < 0 || typed > last) continue;
      moments.add((
        seconds: typed,
        depthMeters: profileDepthAt(profile, typed) ?? 0,
      ));
    }

    for (final marker in placed) {
      final item = marker.item;
      final tags = tagsByMedia[item.id] ?? const <MediaSpeciesTag>[];
      if (!tags.any((t) => t.speciesId == speciesId)) continue;
      if (!item.isVideo) {
        moments.add((
          seconds: marker.elapsedSeconds,
          depthMeters: marker.depthMeters,
        ));
        continue;
      }
      // The clip's own start, unclamped: one begun before the descent keeps
      // its tracks on the dive's clock, and the spans are clamped below.
      final base = item.enrichment?.elapsedSeconds ?? marker.elapsedSeconds;
      final tracks = cropsOfSpecies(
        identificationsByMedia[item.id] ?? const <MediaIdentification>[],
        speciesId,
      ).where((i) => i.isTrack).toList();
      final stretches = videoStretches(tracks);
      final duration = item.durationSeconds;
      if (stretches.isNotEmpty) {
        for (final s in stretches) {
          spans.add((base + s.startMs ~/ 1000, base + (s.endMs + 999) ~/ 1000));
        }
      } else if (duration != null && duration > 0) {
        spans.add((base, base + duration));
      } else {
        // A moment where its camera chip sits, clamped onto the profile.
        moments.add((
          seconds: marker.elapsedSeconds,
          depthMeters: marker.depthMeters,
        ));
      }
    }

    final merged = _merged([
      for (final (start, end) in spans)
        // A stretch wholly before or after the profile has no place.
        if (start <= last && end > 0) (math.max(start, 0), math.min(end, last)),
    ]);
    if (moments.isEmpty && merged.isEmpty) continue;
    moments.sort((a, b) => a.seconds.compareTo(b.seconds));
    result[speciesId] = SpeciesProfilePositions(
      moments: List.unmodifiable(moments),
      spans: List.unmodifiable([
        for (final (start, end) in merged) _withDepths(profile, start, end),
      ]),
    );
  }
  return result;
}

/// [spans] sorted, with overlapping or touching ones joined.
List<(int, int)> _merged(List<(int, int)> spans) {
  final sorted = [...spans]..sort((a, b) => a.$1.compareTo(b.$1));
  final out = <(int, int)>[];
  for (final (start, end) in sorted) {
    if (out.isNotEmpty && start <= out.last.$2) {
      final (s, e) = out.removeLast();
      out.add((s, math.max(e, end)));
    } else {
      out.add((start, end));
    }
  }
  return out;
}

/// The span from [start] to [end] with the profile's shallowest and
/// deepest depth inside it, its ends included.
SpeciesSpan _withDepths(List<DiveProfilePoint> profile, int start, int end) {
  final depths = [
    profileDepthAt(profile, start) ?? 0,
    profileDepthAt(profile, end) ?? 0,
    for (final p in profile)
      if (p.timestamp > start && p.timestamp < end) p.depth,
  ];
  return (
    start: start,
    end: end,
    minDepth: depths.reduce(math.min),
    maxDepth: depths.reduce(math.max),
  );
}
