import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/domain/services/species_profile_positions.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

import '../../../species_id/domain/identification_rules_fixtures.dart';

/// Where on a dive's profile each species was seen (issue #5092).
void main() {
  final t0 = DateTime.utc(2026, 11, 27);

  // A 50 minute dive: down to 30 m by 10 min, back up to 0 by 50 min.
  final profile = <DiveProfilePoint>[
    for (var t = 0; t <= 3000; t += 10)
      DiveProfilePoint(
        timestamp: t,
        depth: t <= 600 ? t / 20 : 30 - (t - 600) / 80,
      ),
  ];

  Sighting sighting(String speciesId, {int? seenAt}) => Sighting(
    id: 's_$speciesId',
    diveId: 'd',
    speciesId: speciesId,
    speciesName: speciesId,
    speciesCategory: SpeciesCategory.fish,
    seenAtSeconds: seenAt,
  );

  MediaItem item(
    String id, {
    MediaType type = MediaType.photo,
    int? elapsed,
    double depth = 10,
    MatchConfidence confidence = MatchConfidence.exact,
    int? duration,
  }) => MediaItem(
    id: id,
    diveId: 'd',
    mediaType: type,
    takenAt: t0,
    durationSeconds: duration,
    createdAt: t0,
    updatedAt: t0,
    enrichment: elapsed == null
        ? null
        : MediaEnrichment(
            id: 'e_$id',
            mediaId: id,
            diveId: 'd',
            elapsedSeconds: elapsed,
            depthMeters: depth,
            matchConfidence: confidence,
            createdAt: t0,
          ),
  );

  MediaSpeciesTag tag(
    String mediaId,
    String speciesId, {
    bool unconfirmed = false,
  }) => MediaSpeciesTag(
    id: 't_${mediaId}_$speciesId',
    mediaId: mediaId,
    speciesId: speciesId,
    createdAt: t0,
    unconfirmed: unconfirmed,
  );

  MediaIdentification track(
    String id,
    String speciesId, {
    required int startMs,
    required int endMs,
    IdentificationDecision decision = IdentificationDecision.accepted,
  }) => ruleId(
    id,
    decision: decision,
    decidedSpeciesId: speciesId,
  ).copyWith(startMs: () => startMs, endMs: () => endMs, bestMs: () => startMs);

  Map<String, SpeciesProfilePositions> place({
    List<Sighting> sightings = const [],
    List<MediaItem> media = const [],
    List<MediaSpeciesTag> tags = const [],
    Map<String, List<MediaIdentification>> ids = const {},
    List<DiveProfilePoint>? onProfile,
  }) => speciesProfilePositions(
    sightings: sightings,
    media: media,
    tagsByMedia: {
      for (final t in tags)
        t.mediaId: [
          for (final u in tags)
            if (u.mediaId == t.mediaId) u,
        ],
    },
    identificationsByMedia: ids,
    profile: onProfile ?? profile,
  );

  test('a sighting time is a moment at the profile depth', () {
    final positions = place(sightings: [sighting('shark', seenAt: 720)]);
    expect(positions['shark']!.moments, [
      (seconds: 720, depthMeters: profileDepthAt(profile, 720)!),
    ]);
    expect(positions['shark']!.spans, isEmpty);
  });

  test('two sightings of one species keep both times, and media once', () {
    final positions = place(
      sightings: [
        sighting('shark', seenAt: 300),
        sighting('shark', seenAt: 900).copyWith(id: 's_shark_2'),
      ],
      media: [item('p1', elapsed: 2100, depth: 12.5)],
      tags: [tag('p1', 'shark')],
    )['shark']!;
    expect([for (final m in positions.moments) m.seconds], [300, 900, 2100]);
  });

  test('a time past the profile end is not placed', () {
    // A split or a shorter source can leave a typed time beyond the
    // profile; a clamped one would show a depth the diver cannot trace.
    expect(place(sightings: [sighting('shark', seenAt: 9000)]), isEmpty);
    expect(
      place(
        sightings: [sighting('shark', seenAt: 3000)],
      )['shark']!.moments.single.seconds,
      3000,
    );
  });

  test('a sighting without a time and without media has no positions', () {
    expect(place(sightings: [sighting('shark')]), isEmpty);
  });

  test('a tagged photo is a moment at its marker', () {
    final positions = place(
      sightings: [sighting('clown')],
      media: [item('p1', elapsed: 2100, depth: 12.5)],
      tags: [tag('p1', 'clown')],
    );
    expect(positions['clown']!.moments, [(seconds: 2100, depthMeters: 12.5)]);
  });

  test('an unconfirmed app tag counts like the diver\'s own', () {
    final positions = place(
      sightings: [sighting('clown')],
      media: [item('p1', elapsed: 2100, depth: 12.5)],
      tags: [tag('p1', 'clown', unconfirmed: true)],
    );
    expect(positions['clown']!.moments, hasLength(1));
  });

  test('accepted video tracks become spans offset by the clip start', () {
    final positions = place(
      sightings: [sighting('shark')],
      media: [item('v1', type: MediaType.video, elapsed: 600, duration: 60)],
      tags: [tag('v1', 'shark')],
      ids: {
        'v1': [
          track('a', 'shark', startMs: 2000, endMs: 9500),
          track('b', 'shark', startMs: 9800, endMs: 14000),
        ],
      },
    );
    final span = positions['shark']!.spans.single;
    expect((span.start, span.end), (602, 614));
    expect(positions['shark']!.moments, isEmpty);
  });

  test('a span\'s depths are the profile\'s shallowest and deepest in it', () {
    final positions = place(
      sightings: [sighting('shark')],
      media: [item('v1', type: MediaType.video, elapsed: 540, duration: 120)],
      tags: [tag('v1', 'shark')],
    );
    final span = positions['shark']!.spans.single;
    // 540 to 660 s climbs to 30 m at 600 s and back to 29.25 m.
    expect(span.maxDepth, 30);
    expect(span.minDepth, profileDepthAt(profile, 540));
  });

  test('a hand-tagged video with no track spans the whole clip', () {
    final positions = place(
      sightings: [sighting('turtle')],
      media: [item('v1', type: MediaType.video, elapsed: 600, duration: 45)],
      tags: [tag('v1', 'turtle')],
    );
    final span = positions['turtle']!.spans.single;
    expect((span.start, span.end), (600, 645));
  });

  test('a tagged video of unknown length is a moment at its start', () {
    final positions = place(
      sightings: [sighting('turtle')],
      media: [item('v1', type: MediaType.video, elapsed: 600, depth: 30)],
      tags: [tag('v1', 'turtle')],
    );
    expect(positions['turtle']!.spans, isEmpty);
    expect(positions['turtle']!.moments.single.seconds, 600);
  });

  test('rejected and other-species tracks are ignored', () {
    final positions = place(
      sightings: [sighting('shark')],
      media: [item('v1', type: MediaType.video, elapsed: 600, duration: 60)],
      tags: [tag('v1', 'shark')],
      ids: {
        'v1': [
          track(
            'r',
            'shark',
            startMs: 0,
            endMs: 5000,
            decision: IdentificationDecision.rejected,
          ),
          track('o', 'tang', startMs: 20000, endMs: 30000),
        ],
      },
    );
    // No usable track: the hand tag spans the clip.
    final span = positions['shark']!.spans.single;
    expect((span.start, span.end), (600, 660));
  });

  test('overlapping spans from two videos merge into one', () {
    final positions = place(
      sightings: [sighting('shark')],
      media: [
        item('v1', type: MediaType.video, elapsed: 600, duration: 60),
        item('v2', type: MediaType.video, elapsed: 650, duration: 30),
      ],
      tags: [tag('v1', 'shark'), tag('v2', 'shark')],
    );
    final span = positions['shark']!.spans.single;
    expect((span.start, span.end), (600, 680));
  });

  test('spans that do not touch stay apart, in time order', () {
    final positions = place(
      sightings: [sighting('shark')],
      media: [
        item('v2', type: MediaType.video, elapsed: 2000, duration: 30),
        item('v1', type: MediaType.video, elapsed: 600, duration: 60),
      ],
      tags: [tag('v1', 'shark'), tag('v2', 'shark')],
    );
    expect(
      [for (final s in positions['shark']!.spans) (s.start, s.end)],
      [(600, 660), (2000, 2030)],
    );
  });

  test('media with no place on the profile contribute nothing', () {
    final positions = place(
      sightings: [sighting('clown')],
      media: [
        item('none'),
        item('noProfile', elapsed: 100, confidence: MatchConfidence.noProfile),
        item('outside', elapsed: 99999),
        item('doc', type: MediaType.document, elapsed: 100),
      ],
      tags: [
        tag('none', 'clown'),
        tag('noProfile', 'clown'),
        tag('outside', 'clown'),
        tag('doc', 'clown'),
      ],
    );
    expect(positions, isEmpty);
  });

  test('a tag of a species with no sighting on the dive places nothing', () {
    final positions = place(
      media: [item('p1', elapsed: 2100)],
      tags: [tag('p1', 'clown')],
    );
    expect(positions, isEmpty);
  });

  test('the depth range covers moments and spans together', () {
    final positions = place(
      sightings: [sighting('shark', seenAt: 2900)],
      media: [item('v1', type: MediaType.video, elapsed: 540, duration: 120)],
      tags: [tag('v1', 'shark')],
    )['shark']!;
    expect(positions.maxDepthMeters, 30);
    expect(positions.minDepthMeters, profileDepthAt(profile, 2900));
    expect(positions.isEmpty, isFalse);
  });

  test('an empty profile gives no positions', () {
    final positions = place(
      sightings: [sighting('shark', seenAt: 720)],
      media: [item('p1', elapsed: 100)],
      tags: [tag('p1', 'shark')],
      onProfile: const [],
    );
    expect(positions, isEmpty);
  });
}
