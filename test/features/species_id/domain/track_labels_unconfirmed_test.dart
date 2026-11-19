import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';

import '../data/identification_fixtures.dart';

/// A fish the app tagged on its own keeps the outlined pill (the app's
/// confident name) until the diver confirms the tag; then it is filled, as
/// any fish the diver tagged (issue #4727).
void main() {
  final applied = track(
    'a',
    decision: IdentificationDecision.accepted,
    decidedSpeciesId: 'sp_a',
  );

  test('an accepted fish whose tag is unconfirmed is outlined', () {
    expect(
      labelKind(applied, playing: false, unconfirmed: true),
      TrackLabelKind.confident,
    );
  });

  test('it shows while playing too', () {
    expect(
      labelKind(applied, playing: true, unconfirmed: true),
      TrackLabelKind.confident,
    );
  });

  test('labelsAt outlines the fish of an unconfirmed species and names it '
      'with the app\'s guess', () {
    final labels = labelsAt(
      [applied],
      1500,
      playing: false,
      unconfirmedSpeciesIds: const {'sp_a'},
    );
    expect(labels.single.kind, TrackLabelKind.confident);
    expect(labels.single.candidate, applied.top);
    expect(labels.single.speciesId, isNull);
  });

  test('once confirmed, the same fish is filled', () {
    final labels = labelsAt([applied], 1500, playing: false);
    expect(labels.single.kind, TrackLabelKind.accepted);
    expect(labels.single.speciesId, 'sp_a');
  });

  test('a fish the diver named from the frame keeps the filled pill', () {
    final claimed = applied.copyWith(claimedSpeciesId: () => 'sp_a');
    final labels = labelsAt(
      [claimed],
      1500,
      playing: false,
      unconfirmedSpeciesIds: const {'sp_a'},
    );
    expect(labels.single.kind, TrackLabelKind.accepted);
  });
}
