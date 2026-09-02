import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

MediaEnrichment _enrichment({
  int? elapsedSeconds,
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
  group('MediaDiveWindow', () {
    test('matches the photo matcher buffers so the two rules stay in step', () {
      expect(DivePhotoMatcher.preBuffer, MediaDiveWindow.before);
      expect(DivePhotoMatcher.postBuffer, MediaDiveWindow.after);
    });

    test('accepts positions inside the profile', () {
      expect(
        MediaDiveWindow.contains(
          elapsedSeconds: 600,
          profileLengthSeconds: 3600,
        ),
        isTrue,
      );
    });

    test('accepts a surface shot inside the pre-dive buffer', () {
      expect(
        MediaDiveWindow.contains(
          elapsedSeconds: -MediaDiveWindow.before.inSeconds,
          profileLengthSeconds: 3600,
        ),
        isTrue,
      );
      expect(
        MediaDiveWindow.contains(
          elapsedSeconds: -MediaDiveWindow.before.inSeconds - 1,
          profileLengthSeconds: 3600,
        ),
        isFalse,
      );
    });

    test('accepts a debrief shot inside the post-dive buffer', () {
      expect(
        MediaDiveWindow.contains(
          elapsedSeconds: 3600 + MediaDiveWindow.after.inSeconds,
          profileLengthSeconds: 3600,
        ),
        isTrue,
      );
      expect(
        MediaDiveWindow.contains(
          elapsedSeconds: 3600 + MediaDiveWindow.after.inSeconds + 1,
          profileLengthSeconds: 3600,
        ),
        isFalse,
      );
    });
  });

  group('MediaEnrichment.isWithinDiveWindow', () {
    test('is false without an elapsed time', () {
      expect(_enrichment().isWithinDiveWindow(3600), isFalse);
    });

    test('is false for a noProfile row even with an elapsed time', () {
      expect(
        _enrichment(
          elapsedSeconds: 600,
          confidence: MatchConfidence.noProfile,
        ).isWithinDiveWindow(3600),
        isFalse,
      );
    });

    test('is false for an automatic position days outside the dive', () {
      // Issue #1090: a 2016 timestamp on a 2026 dive.
      expect(
        _enrichment(
          elapsedSeconds: -5554653 * 60,
          confidence: MatchConfidence.estimated,
        ).isWithinDiveWindow(3600),
        isFalse,
      );
      expect(
        _enrichment(
          elapsedSeconds: 1879 * 60,
          confidence: MatchConfidence.estimated,
        ).isWithinDiveWindow(3600),
        isFalse,
      );
    });

    test('is true for an automatic position inside the tolerance', () {
      expect(
        _enrichment(
          elapsedSeconds: 3600 + 120,
          confidence: MatchConfidence.estimated,
        ).isWithinDiveWindow(3600),
        isTrue,
      );
    });

    test('is always true for a manual position', () {
      // The diver's own placement is never second-guessed by the tolerance.
      expect(
        _enrichment(
          elapsedSeconds: 1879 * 60,
          confidence: MatchConfidence.manual,
        ).isWithinDiveWindow(3600),
        isTrue,
      );
      expect(
        _enrichment(
          elapsedSeconds: 600,
          confidence: MatchConfidence.manual,
        ).isManual,
        isTrue,
      );
    });
  });

  group('MatchConfidence.manual', () {
    test('round-trips through its database string', () {
      expect(MatchConfidence.fromString('manual'), MatchConfidence.manual);
      expect(MatchConfidence.manual.name, 'manual');
      expect(MatchConfidence.manual.displayName, 'Manual');
    });
  });
}
