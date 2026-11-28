import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/pop_out/domain/dive_follow_state.dart';

void main() {
  test('following moves with the main window', () {
    var state = const DiveFollowState();
    expect(state.shownDiveId, isNull);
    state = state.followed('a');
    expect(state.shownDiveId, 'a');
    state = state.followed('b');
    expect(state.shownDiveId, 'b');
    expect(state.isPinned, isFalse);
  });

  test(
    'pinned ignores followed changes and unpin jumps to the latest followed',
    () {
      var state = const DiveFollowState().followed('a').pin();
      expect(state.isPinned, isTrue);
      state = state.followed('b').followed('c');
      expect(state.shownDiveId, 'a');
      state = state.unpin();
      expect(state.isPinned, isFalse);
      expect(state.shownDiveId, 'c');
    },
  );

  test('pin with nothing shown stays unpinned', () {
    expect(const DiveFollowState().pin().isPinned, isFalse);
  });

  test('a null followed id keeps the last dive', () {
    final state = const DiveFollowState().followed('a').followed(null);
    expect(state.shownDiveId, 'a');
  });

  test('diveMissing on the pinned dive unpins', () {
    final state = const DiveFollowState()
        .followed('a')
        .pin()
        .followed('b')
        .diveMissing('a');
    expect(state.isPinned, isFalse);
    expect(state.shownDiveId, 'b');
  });

  test('diveMissing on the pinned dive that was also followed clears it', () {
    final state = const DiveFollowState().followed('a').pin().diveMissing('a');
    expect(state.isPinned, isFalse);
    expect(state.shownDiveId, isNull);
  });

  test('diveMissing on the followed dive clears it', () {
    final state = const DiveFollowState().followed('a').diveMissing('a');
    expect(state.shownDiveId, isNull);
  });

  test('diveMissing for another dive changes nothing', () {
    final state = const DiveFollowState().followed('a');
    expect(state.diveMissing('z'), state);
  });
}
