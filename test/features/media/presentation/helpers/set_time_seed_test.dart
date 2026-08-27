import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/set_time_seed.dart';

/// The Set-time dialog opens on a seed both call sites (viewer chip, info
/// panel action) derive the same way: the pin if there is one, else the
/// automatic position if it is inside the dive window, else the start.
/// The seed is always inside the dialog's range, so a surface shot at
/// -1:30 opens at 0:00 by this rule rather than by a clamp the caller
/// cannot see.
MediaItem _item({int? manualElapsedSeconds, MediaEnrichment? enrichment}) {
  final now = DateTime.utc(2026, 1, 1);
  return MediaItem(
    id: 'm1',
    diveId: 'd1',
    mediaType: MediaType.photo,
    takenAt: now,
    manualElapsedSeconds: manualElapsedSeconds,
    createdAt: now,
    updatedAt: now,
    enrichment: enrichment,
  );
}

MediaEnrichment _at(
  int elapsedSeconds, {
  MatchConfidence confidence = MatchConfidence.exact,
}) => MediaEnrichment(
  id: 'e1',
  mediaId: 'm1',
  diveId: 'd1',
  elapsedSeconds: elapsedSeconds,
  depthMeters: 10,
  matchConfidence: confidence,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  const length = 1800;

  test('a pin wins over the automatic position', () {
    final item = _item(manualElapsedSeconds: 900, enrichment: _at(600));
    expect(setTimeSeedFor(item, profileLengthSeconds: length), 900);
  });

  test('an automatic position inside the profile is used as is', () {
    expect(
      setTimeSeedFor(_item(enrichment: _at(600)), profileLengthSeconds: length),
      600,
    );
  });

  test('no enrichment opens at the start', () {
    expect(setTimeSeedFor(_item(), profileLengthSeconds: length), 0);
  });

  test('a position outside the dive window opens at the start', () {
    final item = _item(
      enrichment: _at(1879 * 60, confidence: MatchConfidence.estimated),
    );
    expect(setTimeSeedFor(item, profileLengthSeconds: length), 0);
  });

  test('a surface shot in the pre-dive buffer opens at the start', () {
    final item = _item(
      enrichment: _at(-90, confidence: MatchConfidence.estimated),
    );
    expect(setTimeSeedFor(item, profileLengthSeconds: length), 0);
  });

  test('a debrief shot in the post-dive buffer opens at the end', () {
    final item = _item(
      enrichment: _at(length + 300, confidence: MatchConfidence.estimated),
    );
    expect(setTimeSeedFor(item, profileLengthSeconds: length), length);
  });

  test('a pin past a since-shortened profile opens at the end', () {
    final item = _item(manualElapsedSeconds: length + 60);
    expect(setTimeSeedFor(item, profileLengthSeconds: length), length);
  });
}
