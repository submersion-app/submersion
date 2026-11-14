import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_media_hover.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../../helpers/mock_providers.dart';

/// 0 to 600 s in 10 s steps: index i is at i * 10 seconds.
final _profile = [
  for (var t = 0; t <= 600; t += 10)
    DiveProfilePoint(timestamp: t, depth: t < 300 ? t / 15 : (600 - t) / 15),
];

/// A photo on the dive, taken [elapsedSeconds] in; with null, one that was
/// never matched to the profile.
MediaItem _photo(String diveId, {int? elapsedSeconds}) {
  final now = DateTime.utc(2026, 1, 1);
  return MediaItem(
    id: 'm1',
    diveId: diveId,
    mediaType: MediaType.photo,
    takenAt: now,
    createdAt: now,
    updatedAt: now,
    enrichment: elapsedSeconds == null
        ? null
        : MediaEnrichment(
            id: 'e1',
            mediaId: 'm1',
            diveId: diveId,
            elapsedSeconds: elapsedSeconds,
            depthMeters: 12,
            matchConfidence: MatchConfidence.exact,
            createdAt: now,
          ),
  );
}

void main() {
  final dive = createTestDiveWithBottomTime().copyWith(profile: _profile);

  ProviderContainer container({SourceProfile? activeSource}) {
    final container = ProviderContainer(
      overrides: [
        activeSourceProfileProvider(
          dive.id,
        ).overrideWith((ref) => activeSource),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  int? cursor(ProviderContainer container) =>
      container.read(profileTrackingIndexProvider(dive.id));

  test('moves the cursor to the sample at the item\'s moment', () {
    final c = container();

    mediaHoverCursorHandler(c, dive)(_photo(dive.id, elapsedSeconds: 125));

    expect(cursor(c), 12);
  });

  test('clears the cursor when the pointer leaves', () {
    final c = container();
    final onHover = mediaHoverCursorHandler(c, dive);

    onHover(_photo(dive.id, elapsedSeconds: 125));
    onHover(null);

    expect(cursor(c), isNull);
  });

  test('an item with no place on the profile leaves the cursor as it is', () {
    final c = container();
    c.read(profileTrackingIndexProvider(dive.id).notifier).state = 7;

    mediaHoverCursorHandler(c, dive)(_photo(dive.id));

    expect(cursor(c), 7);
  });

  test('a dive with no profile does nothing', () {
    final c = container();
    final bare = dive.copyWith(profile: const []);

    mediaHoverCursorHandler(c, bare)(_photo(dive.id, elapsedSeconds: 125));

    expect(cursor(c), isNull);
  });

  test('indexes the active source\'s series on a multi-computer dive', () {
    final c = container(
      activeSource: SourceProfile(
        sourceId: 's1',
        computerId: 'c1',
        isEdited: false,
        points: [
          for (var t = 0; t <= 600; t += 60)
            DiveProfilePoint(timestamp: t, depth: 10),
        ],
      ),
    );

    mediaHoverCursorHandler(c, dive)(_photo(dive.id, elapsedSeconds: 125));

    expect(cursor(c), 2);
  });

  test('clamps a capture time past the end to the last sample', () {
    final c = container();

    mediaHoverCursorHandler(c, dive)(_photo(dive.id, elapsedSeconds: 620));

    expect(cursor(c), _profile.length - 1);
  });

  test('reads the series when hovered, not when the handler was made', () {
    final source = StateProvider<SourceProfile?>((ref) => null);
    final c = ProviderContainer(
      overrides: [
        activeSourceProfileProvider(
          dive.id,
        ).overrideWith((ref) => ref.watch(source)),
      ],
    );
    addTearDown(c.dispose);
    final onHover = mediaHoverCursorHandler(c, dive);

    c.read(source.notifier).state = SourceProfile(
      sourceId: 's1',
      computerId: 'c1',
      isEdited: false,
      points: [
        for (var t = 0; t <= 600; t += 60)
          DiveProfilePoint(timestamp: t, depth: 10),
      ],
    );
    onHover(_photo(dive.id, elapsedSeconds: 125));

    expect(cursor(c), 2);
  });
}
