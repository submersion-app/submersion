import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/video_sighting_providers.dart';

import '../../domain/identification_rules_fixtures.dart';

/// Serves [tracks] for one video and ticks [changes] on demand.
class _FakeIdentifications extends MediaIdentificationRepository {
  _FakeIdentifications(this.tracks);

  List<MediaIdentification> tracks;
  final changes = StreamController<void>.broadcast();
  int reads = 0;

  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) async {
    reads++;
    return [
      for (final t in tracks)
        if (t.mediaId == mediaId) t,
    ];
  }

  @override
  Stream<void> watchChanges() => changes.stream;
}

MediaIdentification _track(
  String id,
  String speciesId,
  int startMs,
  int endMs, {
  int? bestMs,
  bool pending = false,
}) =>
    ruleId(
      id,
      decision: IdentificationDecision.accepted,
      decidedSpeciesId: speciesId,
    ).copyWith(
      mediaId: 'm1',
      startMs: () => startMs,
      endMs: () => endMs,
      bestMs: () => pending ? null : (bestMs ?? startMs),
    );

/// When a species was seen on a video, for the sighting chip's viewer
/// (issue #5084).
void main() {
  const key = (mediaId: 'm1', speciesId: 's1');

  ProviderContainer containerWith(_FakeIdentifications repository) {
    final container = ProviderContainer(
      overrides: [
        mediaIdentificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repository.changes.close);
    return container;
  }

  test('merges the species tracks into sightings in time order', () async {
    final container = containerWith(
      _FakeIdentifications([
        _track('late', 's1', 60000, 65000),
        _track('early', 's1', 4000, 8000),
        _track('overlap', 's1', 7000, 9000),
      ]),
    );
    expect(await container.read(videoSpeciesSightingsProvider(key).future), [
      (startMs: 4000, endMs: 9000),
      (startMs: 60000, endMs: 65000),
    ]);
  });

  test('leaves out other species and pending tracks', () async {
    final container = containerWith(
      _FakeIdentifications([
        _track('other', 's2', 1000, 2000),
        _track('pending', 's1', 3000, 4000, pending: true),
        _track('mine', 's1', 5000, 6000),
      ]),
    );
    expect(await container.read(videoSpeciesSightingsProvider(key).future), [
      (startMs: 5000, endMs: 6000),
    ]);
  });

  test('a video with no tracks has no sightings', () async {
    final container = containerWith(_FakeIdentifications([]));
    expect(
      await container.read(videoSpeciesSightingsProvider(key).future),
      isEmpty,
    );
  });

  test('reads again when the identifications change', () async {
    final repository = _FakeIdentifications([]);
    final container = containerWith(repository);
    final sub = container.listen(videoSpeciesSightingsProvider(key), (_, _) {});
    addTearDown(sub.close);
    expect(
      await container.read(videoSpeciesSightingsProvider(key).future),
      isEmpty,
    );

    repository.tracks = [_track('new', 's1', 2000, 3000)];
    repository.changes.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(await container.read(videoSpeciesSightingsProvider(key).future), [
      (startMs: 2000, endMs: 3000),
    ]);
  });
}
