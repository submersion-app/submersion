import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/dive_mark_actions.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gps_log/data/services/dive_mark_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/dive_mark_action_bridge.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';

import '../../../helpers/mock_providers.dart';

/// Keeps each call and the time it was given.
class _Marks implements DiveMarkService {
  final calls = <(String, DateTime?)>[];

  @override
  Future<Dive> enteredWater({required String diverId, DateTime? at}) async {
    calls.add(('entered:$diverId', at));
    return Dive(id: 'd', dateTime: DateTime(2026));
  }

  @override
  Future<Dive?> surfaced({DateTime? at}) async {
    calls.add(('surfaced', at));
    return null;
  }
}

class _Diver extends MockCurrentDiverIdNotifier {
  _Diver() {
    state = 'a';
  }
}

/// The lock screen notification follows the recording and the open draft,
/// and a tap reaches the mark service with the time it arrived (#637).
void main() {
  group('diveMarkNotificationActionProvider', () {
    ProviderContainer container({required bool recording, Dive? open}) {
      final c = ProviderContainer(
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => _Diver()),
          gpsRecorderStateProvider.overrideWith(
            (ref) => Stream.value(
              GpsRecorderState(
                status: recording
                    ? GpsRecorderStatus.recording
                    : GpsRecorderStatus.idle,
                trackId: recording ? 't1' : null,
              ),
            ),
          ),
          markingDraftProvider.overrideWith((ref) async => open),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<DiveMarkAction?> settle(ProviderContainer c) async {
      c.listen(diveMarkNotificationActionProvider, (_, _) {});
      await c.read(gpsRecorderStateProvider.future);
      await c.read(markingDraftProvider.future);
      return c.read(diveMarkNotificationActionProvider);
    }

    test('nothing to offer while idle', () async {
      expect(await settle(container(recording: false)), isNull);
    });

    test('Entered water while recording with no draft open', () async {
      expect(
        await settle(container(recording: true)),
        DiveMarkAction.enteredWater,
      );
    });

    test('Surfaced while a draft is open', () async {
      expect(
        await settle(
          container(
            recording: true,
            open: Dive(id: 'd', dateTime: DateTime(2026), isDraft: true),
          ),
        ),
        DiveMarkAction.surfaced,
      );
    });
  });

  test('a tap reaches the mark service with the time it arrived', () async {
    final taps = StreamController<DiveMarkTap>();
    final marks = _Marks();
    final at = DateTime.utc(2026, 7, 17, 10, 2);
    final sub = routeDiveMarkTaps(
      taps.stream,
      marks: () => marks,
      currentDiverId: () => 'a',
    );
    addTearDown(sub.cancel);

    taps.add((action: DiveMarkAction.enteredWater, at: at));
    taps.add((action: DiveMarkAction.surfaced, at: at));
    await pumpEventQueue();

    expect(marks.calls, [('entered:a', at), ('surfaced', at)]);
  });

  test('an Entered water tap with no diver is dropped', () async {
    final taps = StreamController<DiveMarkTap>();
    final marks = _Marks();
    final sub = routeDiveMarkTaps(
      taps.stream,
      marks: () => marks,
      currentDiverId: () => null,
    );
    addTearDown(sub.cancel);

    taps.add((action: DiveMarkAction.enteredWater, at: DateTime.utc(2026)));
    await pumpEventQueue();

    expect(marks.calls, isEmpty);
  });
}
