import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/video_identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';

import '../data/identification_fixtures.dart';

/// Joining a track left open at one chunk's end to the one that carries on
/// in the next (issue #4675).
void main() {
  group('seamJoins', () {
    TrackedAnimal openUntil(int endMs, {String? storedId}) {
      final tracker = VideoTracker();
      for (var ms = endMs - 1000; ms <= endMs; ms += 250) {
        tracker.add(
          FrameDetections(
            ms: ms,
            boxes: const [
              DetectedBox(
                box: IdentificationBox(x: 0.1, y: 0.4, width: 0.2, height: 0.1),
                score: 0.9,
              ),
            ],
          ),
        );
      }
      if (storedId != null) {
        tracker.markStored(
          tracker.openTracks.single,
          storedId: storedId,
          namedWorth: 0.018,
        );
      }
      return tracker.openTracks.single;
    }

    MediaIdentification later({
      int startMs = 30000,
      IdentificationDecision decision = IdentificationDecision.undecided,
      String? decidedSpeciesId,
    }) {
      final t = track(
        'later',
        startMs: startMs,
        endMs: startMs + 2000,
        decision: decision,
        decidedSpeciesId: decidedSpeciesId,
      );
      return t.copyWith(
        path: [
          for (final s in t.path)
            s.copyWith(
              box: const IdentificationBox(
                x: 0.1,
                y: 0.4,
                width: 0.2,
                height: 0.1,
              ),
            ),
        ],
      );
    }

    test('a fish crossing the seam is paired', () {
      final open = openUntil(29750);
      final pairs = seamJoins(
        open: [open],
        openRows: const {},
        stored: [later()],
        seamMs: 30000,
      );
      expect(pairs, hasLength(1));
      expect(identical(pairs.single.open, open), isTrue);
      expect(pairs.single.later.id, 'later');
    });

    test('a stored track starting too long after the seam is not', () {
      expect(
        seamJoins(
          open: [openUntil(29750)],
          openRows: const {},
          stored: [later(startMs: 31000)],
          seamMs: 30000,
        ),
        isEmpty,
      );
    });

    test('a stored track starting longer after the open fish was last seen '
        'than the tracker bridges is not', () {
      // Last seen 750 ms before the seam: the tracker links it no later
      // than the seam itself.
      expect(
        seamJoins(
          open: [openUntil(29250)],
          openRows: const {},
          stored: [later()],
          seamMs: 30000,
        ),
        hasLength(1),
      );
      expect(
        seamJoins(
          open: [openUntil(29250)],
          openRows: const {},
          stored: [later(startMs: 30500)],
          seamMs: 30000,
        ),
        isEmpty,
      );
    });

    test('a stored track elsewhere in the frame is not', () {
      final elsewhere = later().copyWith(
        path: [
          for (final s in later().path) s.copyWith(box: s.box.copyWith(x: 0.7)),
        ],
      );
      expect(
        seamJoins(
          open: [openUntil(29750)],
          openRows: const {},
          stored: [elsewhere],
          seamMs: 30000,
        ),
        isEmpty,
      );
    });

    test('a fish that moved most of its length across the seam is '
        'paired', () {
      // 0.15 across with a width of 0.2: an overlap of 0.14 and a shift
      // of three quarters of a box.
      final moved = later().copyWith(
        path: [
          for (final s in later().path)
            s.copyWith(box: s.box.copyWith(x: 0.25)),
        ],
      );
      expect(
        seamJoins(
          open: [openUntil(29750)],
          openRows: const {},
          stored: [moved],
          seamMs: 30000,
        ),
        hasLength(1),
      );
    });

    test('a nearby stored track two open fish could continue is paired '
        'with neither', () {
      final other = VideoTracker();
      for (var ms = 28750; ms <= 29750; ms += 250) {
        other.add(
          FrameDetections(
            ms: ms,
            boxes: const [
              DetectedBox(
                box: IdentificationBox(x: 0.4, y: 0.4, width: 0.2, height: 0.1),
                score: 0.9,
              ),
            ],
          ),
        );
      }
      // Between the two, overlapping neither by 0.3.
      final between = later().copyWith(
        path: [
          for (final s in later().path)
            s.copyWith(box: s.box.copyWith(x: 0.25)),
        ],
      );
      expect(
        seamJoins(
          open: [openUntil(29750), other.openTracks.single],
          openRows: const {},
          stored: [between],
          seamMs: 30000,
        ),
        isEmpty,
      );
    });

    test('saidDifferently needs a say on both parts, and a difference', () {
      final accepted = track(
        'a',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
      );
      final rejected = track('b', decision: IdentificationDecision.rejected);
      final claimed = track('c', claimedSpeciesId: 'sp_queen_parrotfish');
      expect(saidDifferently(accepted, rejected), isTrue);
      expect(saidDifferently(accepted, claimed), isTrue);
      expect(saidDifferently(accepted, track('d')), isFalse);
      expect(
        saidDifferently(
          accepted,
          track(
            'e',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_queen_parrotfish',
          ),
        ),
        isFalse,
      );
    });

    test('parts the diver decided differently stay apart', () {
      final accepted = track(
        'early',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
      );
      expect(
        seamJoins(
          open: [openUntil(29750, storedId: 'early')],
          openRows: {'early': accepted},
          stored: [later(decision: IdentificationDecision.rejected)],
          seamMs: 30000,
        ),
        isEmpty,
      );
    });

    test('a decided part joins an undecided one', () {
      final accepted = track(
        'early',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
      );
      expect(
        seamJoins(
          open: [openUntil(29750, storedId: 'early')],
          openRows: {'early': accepted},
          stored: [later()],
          seamMs: 30000,
        ),
        hasLength(1),
      );
    });

    test('each stored track is used once, the most overlapping first', () {
      final near = openUntil(29750);
      final far = VideoTracker();
      for (var ms = 28750; ms <= 29750; ms += 250) {
        far.add(
          FrameDetections(
            ms: ms,
            boxes: const [
              DetectedBox(
                box: IdentificationBox(
                  x: 0.15,
                  y: 0.4,
                  width: 0.2,
                  height: 0.1,
                ),
                score: 0.9,
              ),
            ],
          ),
        );
      }
      final pairs = seamJoins(
        open: [far.openTracks.single, near],
        openRows: const {},
        stored: [later()],
        seamMs: 30000,
      );
      expect(pairs, hasLength(1));
      expect(identical(pairs.single.open, near), isTrue);
    });
  });
}
