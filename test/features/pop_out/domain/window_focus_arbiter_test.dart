import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/pop_out/domain/window_focus_arbiter.dart';

void main() {
  late List<String> events;
  late WindowFocusArbiter arbiter;

  void build() {
    events = [];
    arbiter = WindowFocusArbiter(
      onLeft: () => events.add('left'),
      onReturned: () => events.add('returned'),
    );
  }

  test('no pop-out open reports at once', () {
    fakeAsync((async) {
      build();
      arbiter.mainLeft();
      expect(events, ['left']);
      arbiter.mainReturned();
      expect(events, ['left', 'returned']);
      arbiter.dispose();
    });
  });

  test('no pop-out open passes every change through, repeats included', () {
    // As before pop-outs: inactive, hidden and paused each report leaving,
    // and every resume reports returning.
    fakeAsync((async) {
      build();
      arbiter
        ..mainLeft()
        ..mainLeft()
        ..mainLeft()
        ..mainReturned()
        ..mainReturned();
      expect(events, ['left', 'left', 'left', 'returned', 'returned']);
      arbiter.dispose();
    });
  });

  test('focus hand-off to the pop-out within the grace is not leaving', () {
    fakeAsync((async) {
      build();
      arbiter.popOutOpen = true;
      arbiter.mainLeft();
      async.elapse(const Duration(milliseconds: 100));
      arbiter.popOutFocus(true);
      async.elapse(const Duration(seconds: 1));
      expect(events, isEmpty);
      // And back again: not a return either, since nothing was left.
      arbiter.popOutFocus(false);
      arbiter.mainReturned();
      async.elapse(const Duration(seconds: 1));
      expect(events, isEmpty);
      arbiter.dispose();
    });
  });

  test(
    'pop-out focus arriving before the main window blurs is not leaving',
    () {
      fakeAsync((async) {
        build();
        arbiter.popOutOpen = true;
        arbiter.popOutFocus(true);
        arbiter.mainLeft();
        async.elapse(const Duration(seconds: 1));
        expect(events, isEmpty);
        arbiter.dispose();
      });
    },
  );

  test(
    'main window leaving with no pop-out focus is leaving after the grace',
    () {
      fakeAsync((async) {
        build();
        arbiter.popOutOpen = true;
        arbiter.mainLeft();
        async.elapse(const Duration(milliseconds: 299));
        expect(events, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(events, ['left']);
        arbiter.dispose();
      });
    },
  );

  test('pop-out losing focus to another app is leaving', () {
    fakeAsync((async) {
      build();
      arbiter.popOutOpen = true;
      arbiter.mainLeft();
      arbiter.popOutFocus(true);
      async.elapse(const Duration(seconds: 1));
      arbiter.popOutFocus(false);
      async.elapse(const Duration(milliseconds: 300));
      expect(events, ['left']);
      arbiter.dispose();
    });
  });

  test('returning after a real leave is reported once', () {
    fakeAsync((async) {
      build();
      arbiter.popOutOpen = true;
      arbiter.mainLeft();
      async.elapse(const Duration(seconds: 1));
      expect(events, ['left']);
      // The diver clicks the pop-out first, then the main window.
      arbiter.popOutFocus(true);
      arbiter.mainReturned();
      expect(events, ['left', 'returned']);
      arbiter.dispose();
    });
  });

  test('closing the pop-out while it holds focus is leaving', () {
    fakeAsync((async) {
      build();
      arbiter.popOutOpen = true;
      arbiter.mainLeft();
      arbiter.popOutFocus(true);
      async.elapse(const Duration(seconds: 1));
      arbiter.popOutOpen = false;
      async.elapse(const Duration(milliseconds: 300));
      expect(events, ['left']);
      arbiter.dispose();
    });
  });

  test('dispose cancels a pending leave', () {
    fakeAsync((async) {
      build();
      arbiter.popOutOpen = true;
      arbiter.mainLeft();
      arbiter.dispose();
      async.elapse(const Duration(seconds: 1));
      expect(events, isEmpty);
    });
  });
}
