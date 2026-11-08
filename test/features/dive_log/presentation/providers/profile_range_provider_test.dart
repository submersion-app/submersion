import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';

void main() {
  group('RangeSelectionNotifier', () {
    test('a series from 0 keeps its default middle half', () {
      final notifier = RangeSelectionNotifier()..initialize(2400);
      notifier.toggleRangeMode();
      expect(notifier.state.startTimestamp, 600);
      expect(notifier.state.endTimestamp, 1800);
      expect(notifier.state.startProgress, 0.25);
    });
  });

  group('a series that starts before the primary (#4296)', () {
    RangeSelectionNotifier enabled() {
      final notifier = RangeSelectionNotifier()
        ..initialize(2400, startSeconds: -600);
      notifier.toggleRangeMode();
      return notifier;
    }

    test('the default selection is the middle half of the whole series', () {
      final notifier = enabled();
      expect(notifier.state.minTimestamp, -600);
      expect(notifier.state.startTimestamp, 150);
      expect(notifier.state.endTimestamp, 1650);
    });

    test('a range can start before 0, down to the first sample', () {
      final notifier = enabled();
      notifier.setRange(-400, 100);
      expect(notifier.state.startTimestamp, -400);
      notifier.setRange(-5000, 100);
      expect(notifier.state.startTimestamp, -600);
      notifier.setStart(-900);
      expect(notifier.state.startTimestamp, -600);
    });

    test('progress spans the whole series', () {
      final notifier = enabled();
      notifier.setRange(-600, 2400);
      expect(notifier.state.startProgress, 0);
      expect(notifier.state.endProgress, 1);
      notifier.setStartProgress(0.5);
      expect(notifier.state.startTimestamp, 900);
    });

    test('times before 0 read with a sign', () {
      expect(RangeSelectionState.formatTimestamp(-65), '-01:05');
      expect(RangeSelectionState.formatTimestamp(65), '01:05');
    });
  });
}
