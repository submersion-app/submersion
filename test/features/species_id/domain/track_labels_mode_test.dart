import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';

import '../data/identification_fixtures.dart';

/// What a label mode draws on a video and on a photo (issue #4825).
void main() {
  /// A photo detection the app could not name.
  MediaIdentification unnamedPhoto(String id, {required bool specific}) =>
      identification(
        id,
      ).copyWith(suggestable: false, confident: false, specific: specific);

  group('LabelMode', () {
    test('reads its own ids back', () {
      for (final mode in LabelMode.values) {
        expect(LabelMode.fromId(mode.id), mode);
      }
    });

    test('reads an unknown id, or none, as names', () {
      expect(LabelMode.fromId('later-version'), LabelMode.names);
      expect(LabelMode.fromId(null), LabelMode.names);
    });
  });

  group('labelKind by mode', () {
    test('off draws nothing, whatever the animal', () {
      final animals = [
        track('confident'),
        track(
          'tagged',
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp_a',
        ),
        track('unnamed', suggestable: false, confident: false),
        identification('photo'),
      ];
      for (final animal in animals) {
        for (final playing in [true, false]) {
          expect(
            labelKind(animal, playing: playing, mode: LabelMode.off),
            isNull,
            reason: '${animal.id}, playing $playing',
          );
        }
      }
    });

    test('all life dots an unnamed fish, playing or paused, however brief '
        'or vague', () {
      final brief = track(
        'a',
        suggestable: false,
        confident: false,
        specific: false,
        endMs: 1250,
      );
      expect(
        labelKind(brief, playing: true, mode: LabelMode.allLife),
        TrackLabelKind.dot,
      );
      expect(
        labelKind(brief, playing: false, mode: LabelMode.allLife),
        TrackLabelKind.dot,
      );
    });

    test('all life leaves the names as they are', () {
      expect(
        labelKind(track('a'), playing: true, mode: LabelMode.allLife),
        TrackLabelKind.confident,
      );
      expect(
        labelKind(
          track('b', confident: false),
          playing: true,
          mode: LabelMode.allLife,
        ),
        TrackLabelKind.suggestion,
      );
      expect(
        labelKind(
          track(
            'c',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_a',
          ),
          playing: true,
          mode: LabelMode.allLife,
        ),
        TrackLabelKind.accepted,
      );
    });

    test('a dismissed animal draws nothing in all life', () {
      expect(
        labelKind(
          track('a', decision: IdentificationDecision.rejected),
          playing: false,
          mode: LabelMode.allLife,
        ),
        isNull,
      );
    });

    test('names keeps the guarded paused dot on a video', () {
      final long = track(
        'a',
        suggestable: false,
        confident: false,
        endMs: 2000,
      );
      final brief = track(
        'b',
        suggestable: false,
        confident: false,
        endMs: 1500,
      );
      final vague = track(
        'c',
        suggestable: false,
        confident: false,
        specific: false,
        endMs: 3000,
      );
      expect(labelKind(long, playing: false), TrackLabelKind.dot);
      expect(labelKind(long, playing: true), isNull);
      expect(labelKind(brief, playing: false), isNull);
      expect(labelKind(vague, playing: false), isNull);
    });

    test('a photo in names behaves like a paused video, without the one '
        'second rule', () {
      final specific = unnamedPhoto('p', specific: true);
      final vague = unnamedPhoto('q', specific: false);
      expect(labelKind(specific, playing: false), TrackLabelKind.dot);
      expect(labelKind(vague, playing: false), isNull);
      expect(
        labelKind(vague, playing: false, mode: LabelMode.allLife),
        TrackLabelKind.dot,
      );
    });

    test('a photo tag fills the pill only on a detection the app could '
        'suggest or the diver named', () {
      final accepted = identification(
        'p',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_a',
      );
      final weak = accepted.copyWith(suggestable: false, specific: true);
      final weakAndVague = weak.copyWith(specific: false);
      final claimed = weak.copyWith(claimedSpeciesId: () => 'sp_a');
      expect(labelKind(accepted, playing: false), TrackLabelKind.accepted);
      expect(labelKind(weak, playing: false), TrackLabelKind.dot);
      expect(labelKind(weakAndVague, playing: false), isNull);
      expect(
        labelKind(weakAndVague, playing: false, mode: LabelMode.allLife),
        TrackLabelKind.dot,
      );
      expect(labelKind(claimed, playing: false), TrackLabelKind.accepted);
    });

    test('a video tag fills the pill whether or not the track is still '
        'suggestable', () {
      final accepted = track(
        'a',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_a',
        suggestable: false,
        confident: false,
      );
      expect(labelKind(accepted, playing: true), TrackLabelKind.accepted);
    });
  });

  group('labelsAt', () {
    test('passes the mode on', () {
      final unnamed = track(
        'a',
        suggestable: false,
        confident: false,
        specific: false,
      );
      expect(labelsAt([unnamed], 1500, playing: true), isEmpty);
      expect(
        labelsAt([unnamed], 1500, playing: true, mode: LabelMode.allLife),
        hasLength(1),
      );
      expect(
        labelsAt([track('b')], 1500, playing: true, mode: LabelMode.off),
        isEmpty,
      );
    });
  });

  group('photoLabels', () {
    /// [i] at [x], [y], a twentieth of the photo square.
    MediaIdentification at(MediaIdentification i, double x, double y) =>
        i.copyWith(
          box: IdentificationBox(x: x, y: y, width: 0.05, height: 0.05),
        );

    test('labels each detection where it is', () {
      final labels = photoLabels([at(identification('p'), 0.3, 0.6)]);
      expect(labels, hasLength(1));
      expect(labels.single.identificationId, 'p');
      expect(labels.single.kind, TrackLabelKind.suggestion);
      expect(labels.single.box.x, 0.3);
      expect(labels.single.box.y, 0.6);
      expect(labels.single.candidate!.candidate.commonName, 'Queen Parrotfish');
    });

    test('leaves out video tracks', () {
      expect(photoLabels([track('a')]), isEmpty);
    });

    test('a hundred animals get a hundred labels', () {
      final many = [
        for (var k = 0; k < 100; k++)
          at(identification('p$k'), (k % 10) * 0.1, (k ~/ 10) * 0.1),
      ];
      expect(photoLabels(many), hasLength(100));
    });

    test('merges two detections on one animal, the tag first', () {
      final labels = photoLabels([
        identification('app'),
        identification(
          'diver',
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp_a',
        ),
      ]);
      expect(labels, hasLength(1));
      expect(labels.single.kind, TrackLabelKind.accepted);
      expect(labels.single.speciesId, 'sp_a');
    });

    test('a tag the app applied and the diver has not confirmed keeps the '
        "app's outlined pill", () {
      final labels = photoLabels(
        [
          identification(
            'p',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_a',
          ),
        ],
        unconfirmedSpeciesIds: {'sp_a'},
      );
      expect(labels.single.kind, TrackLabelKind.confident);
    });

    test('draws nothing when off, and dots the unnamed in all life', () {
      final unnamed = unnamedPhoto('p', specific: false);
      expect(photoLabels([unnamed]), isEmpty);
      expect(photoLabels([unnamed], mode: LabelMode.off), isEmpty);
      expect(
        photoLabels([unnamed], mode: LabelMode.allLife).single.kind,
        TrackLabelKind.dot,
      );
    });
  });
}
