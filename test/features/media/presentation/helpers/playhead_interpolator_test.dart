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

    test('shows the reported position as is when paused', () {
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

    test('shows the clip start before any report', () {
      final playhead = PlayheadInterpolator();

      expect(playhead.shown, Duration.zero);
      expect(playhead.advance(_ms(100)), isFalse);
    });
  });
}
