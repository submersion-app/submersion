import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/helpers/playhead_interpolator.dart';

const _clip = Duration(seconds: 30);

Duration _ms(int ms) => Duration(milliseconds: ms);

/// A playhead that heard [position] while playing at [speed], first drawn
/// at clock [now].
PlayheadInterpolator _playing(
  Duration position, {
  Duration now = Duration.zero,
  double speed = 1.0,
}) {
  final playhead = PlayheadInterpolator()
    ..report(
      position: position,
      advancing: true,
      speed: speed,
      duration: _clip,
    );
  playhead.advance(now);
  return playhead;
}

void main() {
  group('PlayheadInterpolator', () {
    test('glides forward between reports while playing', () {
      final playhead = _playing(_ms(10000));

      expect(playhead.advance(_ms(16)), isTrue);
      expect(playhead.shown, _ms(10016));
      expect(playhead.advance(_ms(50)), isTrue);
      expect(playhead.shown, _ms(10050));
    });

    test('moves at the playback speed', () {
      final playhead = _playing(_ms(10000), speed: 2.0);

      playhead.advance(_ms(40));

      expect(playhead.shown, _ms(10080));
    });

    test('takes the next report from the frame after it arrives', () {
      final playhead = _playing(_ms(10000));
      playhead.advance(_ms(100));

      playhead.report(
        position: _ms(10100),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );
      playhead.advance(_ms(116));
      expect(playhead.shown, _ms(10100));
      playhead.advance(_ms(132));
      expect(playhead.shown, _ms(10116));
    });

    test('never steps back for a report just behind what it drew', () {
      final playhead = _playing(_ms(10000));
      playhead.advance(_ms(120));
      expect(playhead.shown, _ms(10120));

      // The player was polled a little before this frame.
      playhead.report(
        position: _ms(10100),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );
      playhead.advance(_ms(136));
      expect(playhead.shown, _ms(10120), reason: 'held, not pulled back');
      playhead.advance(_ms(166));
      expect(playhead.shown, _ms(10130));
    });

    test('jumps back at once when the player itself went back', () {
      final playhead = _playing(_ms(10000));
      playhead.advance(_ms(100));

      // A seek back, or a looping clip starting over.
      playhead.report(
        position: _ms(2000),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );

      expect(playhead.shown, _ms(2000));
      playhead.advance(_ms(116));
      expect(playhead.shown, _ms(2000));
      playhead.advance(_ms(132));
      expect(playhead.shown, _ms(2016));
    });

    test('jumps forward at once when the player skipped ahead', () {
      final playhead = _playing(_ms(10000));
      playhead.advance(_ms(16));

      playhead.report(
        position: _ms(20000),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );
      playhead.advance(_ms(32));

      expect(playhead.shown, _ms(20000));
    });

    test('runs at most maxLead past the last report, then rests', () {
      final playhead = _playing(_ms(10000));

      expect(playhead.advance(PlayheadInterpolator.maxLead), isFalse);
      expect(playhead.shown, _ms(10000) + PlayheadInterpolator.maxLead);
      expect(playhead.advance(const Duration(seconds: 5)), isFalse);
      expect(
        playhead.shown,
        _ms(10000) + PlayheadInterpolator.maxLead,
        reason: 'a stalled player does not drag the bar off with it',
      );
    });

    test('stops at the end of the clip', () {
      final playhead = _playing(_ms(29900));

      expect(playhead.advance(_ms(300)), isFalse);
      expect(playhead.shown, _clip);
    });

    test('pausing on the last poll keeps the playhead where it was drawn', () {
      final playhead = _playing(_ms(10000));
      playhead.advance(_ms(80));

      // pause() leaves the position at the last poll.
      final needsFrames = playhead.report(
        position: _ms(10000),
        advancing: false,
        speed: 1.0,
        duration: _clip,
      );

      expect(needsFrames, isFalse);
      expect(playhead.shown, _ms(10080));
    });

    test('a seek given up on no longer counts as landing', () {
      final playhead = _playing(_ms(15000));
      playhead.advance(_ms(120));

      playhead.expectSeek(_ms(15050));
      playhead.expectSeek(null);
      playhead.report(
        position: _ms(15050),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );

      expect(playhead.shown, _ms(15120), reason: 'an ordinary late poll');
    });

    test('a paused report that moves the playhead is shown as is', () {
      final playhead = _playing(_ms(10000));
      playhead.advance(_ms(80));

      playhead.report(
        position: _ms(10050),
        advancing: false,
        speed: 1.0,
        duration: _clip,
      );

      expect(playhead.shown, _ms(10050));
      expect(playhead.advance(_ms(500)), isFalse);
      expect(playhead.shown, _ms(10050));
    });

    test('rests at zero speed', () {
      final playhead = _playing(_ms(10000), speed: 0.0);

      expect(playhead.advance(_ms(200)), isFalse);
      expect(playhead.shown, _ms(10000));
    });

    test('starting to play again glides from where it paused', () {
      final playhead = PlayheadInterpolator()
        ..report(
          position: _ms(5000),
          advancing: false,
          speed: 1.0,
          duration: _clip,
        );

      playhead.report(
        position: _ms(5000),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );
      expect(playhead.advance(_ms(1000)), isTrue);
      expect(playhead.shown, _ms(5000));
      playhead.advance(_ms(1020));
      expect(playhead.shown, _ms(5020));
    });

    test('says whether it moves on between reports', () {
      final playhead = PlayheadInterpolator();
      bool reportAt(double speed, {bool advancing = true}) => playhead.report(
        position: _ms(1000),
        advancing: advancing,
        speed: speed,
        duration: _clip,
      );

      expect(reportAt(1.0), isTrue);
      expect(reportAt(0.0), isFalse);
      expect(reportAt(1.0, advancing: false), isFalse);
    });

    test('a report of the same position does not restart the glide', () {
      final playhead = _playing(_ms(10000));
      playhead.advance(_ms(60));

      // A buffered-range update: the player notifies, the position has not
      // been polled again.
      playhead.report(
        position: _ms(10000),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );
      playhead.advance(_ms(76));

      expect(playhead.shown, _ms(10076));
    });

    test('a seek back to just behind the playhead lands where it was sent', () {
      final playhead = _playing(_ms(15000));
      playhead.advance(_ms(120));
      expect(playhead.shown, _ms(15120));

      playhead.expectSeek(_ms(15050));
      // A poll taken before the seek lands still glides on.
      playhead.report(
        position: _ms(15100),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );
      expect(playhead.shown, _ms(15120));

      playhead.report(
        position: _ms(15050),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );
      expect(playhead.shown, _ms(15050));
      playhead.advance(_ms(136));
      playhead.advance(_ms(152));
      expect(playhead.shown, _ms(15066));
    });

    test('once at rest, a report that moves nothing asks for no frames', () {
      final playhead = _playing(_ms(10000));
      expect(playhead.advance(PlayheadInterpolator.maxLead), isFalse);

      final needsFrames = playhead.report(
        position: _ms(10000),
        advancing: true,
        speed: 1.0,
        duration: _clip,
      );

      expect(needsFrames, isFalse);
      expect(
        playhead.report(
          position: _ms(10100),
          advancing: true,
          speed: 1.0,
          duration: _clip,
        ),
        isTrue,
        reason: 'a new position moves it on again',
      );
    });

    test('keeps a held playhead inside a clip that turns out shorter', () {
      final playhead = _playing(_ms(10000));
      playhead.advance(_ms(400));
      expect(playhead.shown, _ms(10400));

      playhead.report(
        position: _ms(10100),
        advancing: true,
        speed: 1.0,
        duration: _ms(10200),
      );

      expect(playhead.shown, _ms(10200));
    });

    test('shows the clip start before any report', () {
      final playhead = PlayheadInterpolator();

      expect(playhead.shown, Duration.zero);
      expect(playhead.advance(_ms(100)), isFalse);
    });
  });
}
