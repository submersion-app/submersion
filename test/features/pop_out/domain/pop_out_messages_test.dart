import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';

void main() {
  group('PopOutMessage', () {
    final messages = <PopOutMessage>[
      const ShowDiveMessage('dive-1'),
      const ShowDiveMessage(null),
      const CursorMessage('dive-1', 754),
      const CursorMessage('dive-1', null),
      const PrefsMessage({
        'current_diver_id': 'diver-2',
        'display_zoom': 1.25,
        'flag': true,
        'count': 3,
        'list': ['a', 'b'],
      }),
      const LockMessage(true),
      const FocusRequestMessage(),
      const CloseMessage(),
      const FocusReportMessage(false),
      const FrameMessage(PopOutFrame(x: 10, y: 20, width: 900, height: 600)),
      const ClosedMessage(),
    ];

    test('every message round-trips through toCall/fromCall', () {
      for (final message in messages) {
        final call = message.toCall();
        expect(
          PopOutMessage.fromCall(MethodCall(call.method, call.arguments)),
          message,
          reason: call.method,
        );
      }
    });

    test('malformed args decode to null', () {
      expect(PopOutMessage.fromCall(const MethodCall('nope')), isNull);
      expect(PopOutMessage.fromCall(const MethodCall('cursor', 'x')), isNull);
      expect(
        PopOutMessage.fromCall(
          const MethodCall('cursor', {'diveId': 3, 'seconds': 1}),
        ),
        isNull,
      );
      expect(
        PopOutMessage.fromCall(const MethodCall('lock', {'locked': 'yes'})),
        isNull,
      );
      expect(
        PopOutMessage.fromCall(const MethodCall('frame', {'frame': 'x'})),
        isNull,
      );
    });
  });

  group('PopOutLaunch', () {
    const launch = PopOutLaunch(
      channel: 'submersion/pop_out/1',
      diveId: 'dive-9',
      prefs: {'display_zoom': 1.1, 'current_diver_id': 'd'},
      locked: false,
      savedFrame: PopOutFrame(x: 1, y: 2, width: 800, height: 500),
      mainFrame: PopOutFrame(x: 0, y: 0, width: 1280, height: 900),
    );

    test('launch round-trips and rejects other kinds', () {
      expect(PopOutLaunch.decode(launch.encode()), launch);
      expect(PopOutLaunch.decode(''), isNull);
      expect(PopOutLaunch.decode('not json'), isNull);
      expect(PopOutLaunch.decode('{"kind":"stats"}'), isNull);
    });

    test('a launch with no dive or saved frame round-trips', () {
      const bare = PopOutLaunch(
        channel: 'submersion/pop_out/2',
        diveId: null,
        prefs: {},
        locked: true,
        savedFrame: null,
        mainFrame: PopOutFrame(x: 0, y: 0, width: 1, height: 1),
      );
      expect(PopOutLaunch.decode(bare.encode()), bare);
    });
  });
}
