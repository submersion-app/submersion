import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/helpers/linked_dive_times.dart';
import 'package:submersion/features/dive_log/presentation/helpers/seeded_dive_times.dart';

/// One input edited, the rest as they were.
extension on DiveTimeInputs {
  DiveTimeInputs copyWith({
    DateTime? entry,
    DateTime? exit,
    int? bottomTimeMinutes,
    int? runtimeMinutes,
  }) => DiveTimeInputs(
    entry: entry ?? this.entry,
    exit: exit ?? this.exit,
    bottomTimeMinutes: bottomTimeMinutes ?? this.bottomTimeMinutes,
    runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
  );
}

void main() {
  // A dive computer's times, seconds and all (the dive from issue #3901).
  final entry = DateTime.utc(2026, 1, 1, 10, 0, 50);
  final exit = DateTime.utc(2026, 1, 1, 10, 50, 10);
  const runtime = Duration(seconds: 2960);
  const bottomTime = Duration(seconds: 2409);

  Dive dive({DateTime? exitTime, Duration? run = runtime}) => Dive(
    id: 'dive-241',
    dateTime: entry,
    entryTime: entry,
    exitTime: exitTime,
    bottomTime: bottomTime,
    runtime: run,
  );

  /// What a save writes once the form shows [linked]'s inputs.
  ExactDiveTimes saved(SeededDiveTimes linked) =>
      resolveDiveTimes(linked.shown, seeded: linked);

  group('moveDiveEntry', () {
    test('moves a recorded exit by the same amount, seconds and all', () {
      final seeded = SeededDiveTimes.of(dive(exitTime: exit));
      final moved = moveDiveEntry(
        seeded.shown,
        DateTime.utc(2026, 1, 4, 13, 0),
        seeded: seeded,
      );

      expect(moved.shown.entry, DateTime.utc(2026, 1, 4, 13, 0));
      expect(moved.shown.exit, DateTime.utc(2026, 1, 4, 13, 50));
      expect(moved.shown.runtimeMinutes, 49);
      final times = saved(moved);
      expect(times.entry, DateTime.utc(2026, 1, 4, 13, 0, 50));
      expect(times.exit, DateTime.utc(2026, 1, 4, 13, 50, 10));
      expect(times.runtime, runtime);
      expect(times.bottomTime, bottomTime);
    });

    test('keeps a stored runtime that differs from exit minus entry', () {
      // Computers log runtime apart from the timestamps; a shift keeps both.
      const logged = Duration(minutes: 47);
      final seeded = SeededDiveTimes.of(dive(exitTime: exit, run: logged));
      final moved = moveDiveEntry(
        seeded.shown,
        DateTime.utc(2026, 1, 1, 12, 0),
        seeded: seeded,
      );

      expect(saved(moved).runtime, logged);
      expect(saved(moved).exit, DateTime.utc(2026, 1, 1, 12, 50, 10));
    });

    test('moves an estimated exit without saving it', () {
      final seeded = SeededDiveTimes.of(dive());
      expect(seeded.shown.exit, DateTime.utc(2026, 1, 1, 10, 50));

      final moved = moveDiveEntry(
        seeded.shown,
        DateTime.utc(2026, 1, 2, 10, 0),
        seeded: seeded,
      );

      expect(moved.shown.exit, DateTime.utc(2026, 1, 2, 10, 50));
      final times = saved(moved);
      expect(times.exit, isNull);
      expect(times.runtime, runtime);
      expect(times.end, DateTime.utc(2026, 1, 2, 10, 50, 10));
    });

    test('moves an exit the diver typed and keeps its runtime', () {
      final seeded = SeededDiveTimes.of(dive(exitTime: exit));
      final form = seeded.shown.copyWith(
        exit: DateTime.utc(2026, 1, 1, 11, 30),
        runtimeMinutes: 89,
      );
      final moved = moveDiveEntry(
        form,
        DateTime.utc(2026, 1, 1, 12, 0),
        seeded: seeded,
      );

      expect(moved.shown.exit, DateTime.utc(2026, 1, 1, 13, 30));
      final times = saved(moved);
      expect(times.exit, DateTime.utc(2026, 1, 1, 13, 30));
      expect(times.runtime, resolveDiveTimes(form, seeded: seeded).runtime);
    });

    test('leaves a dive with no exit without one', () {
      final seeded = SeededDiveTimes.of(
        Dive(id: 'd', dateTime: entry, entryTime: entry),
      );
      final moved = moveDiveEntry(
        seeded.shown,
        DateTime.utc(2026, 1, 1, 12, 0),
        seeded: seeded,
      );

      expect(moved.shown.exit, isNull);
      expect(saved(moved).exit, isNull);
    });

    test('moves a new dive whole minutes, with nothing stored behind it', () {
      final form = DiveTimeInputs(
        entry: DateTime.utc(2026, 1, 1, 9, 0),
        exit: DateTime.utc(2026, 1, 1, 9, 45),
        bottomTimeMinutes: 40,
      );
      final moved = moveDiveEntry(form, DateTime.utc(2026, 1, 3, 9, 30));

      expect(moved.shown.exit, DateTime.utc(2026, 1, 3, 10, 15));
      final times = saved(moved);
      expect(times.entry, DateTime.utc(2026, 1, 3, 9, 30));
      expect(times.exit, DateTime.utc(2026, 1, 3, 10, 15));
      expect(times.runtime, const Duration(minutes: 45));
      expect(times.bottomTime, const Duration(minutes: 40));
    });
  });

  group('setDiveRuntime', () {
    test('moves a recorded exit to entry plus the runtime', () {
      final seeded = SeededDiveTimes.of(dive(exitTime: exit));
      final linked = setDiveRuntime(seeded.shown, 60, seeded: seeded);

      expect(linked.shown.runtimeMinutes, 60);
      expect(linked.shown.exit, DateTime.utc(2026, 1, 1, 11, 0));
      final times = saved(linked);
      expect(times.entry, entry);
      expect(times.exit, DateTime.utc(2026, 1, 1, 11, 0, 50));
      expect(times.runtime, const Duration(minutes: 60));
      expect(times.bottomTime, bottomTime);
    });

    test('moves an estimated exit without saving it', () {
      final seeded = SeededDiveTimes.of(dive());
      final linked = setDiveRuntime(seeded.shown, 55, seeded: seeded);

      expect(linked.shown.exit, DateTime.utc(2026, 1, 1, 10, 55));
      final times = saved(linked);
      expect(times.exit, isNull);
      expect(times.runtime, const Duration(minutes: 55));
    });

    test('shows an estimated exit on a dive that had none', () {
      final form = DiveTimeInputs(entry: DateTime.utc(2026, 1, 1, 9, 0));
      final linked = setDiveRuntime(form, 50);

      expect(linked.shown.exit, DateTime.utc(2026, 1, 1, 9, 50));
      final times = saved(linked);
      expect(times.exit, isNull);
      expect(times.runtime, const Duration(minutes: 50));
    });

    test('moves the exit a diver picked on a new dive', () {
      final form = DiveTimeInputs(
        entry: DateTime.utc(2026, 1, 1, 9, 0),
        exit: DateTime.utc(2026, 1, 1, 9, 45),
        runtimeMinutes: 45,
      );
      final linked = setDiveRuntime(form, 52);

      expect(linked.shown.exit, DateTime.utc(2026, 1, 1, 9, 52));
      expect(saved(linked).exit, DateTime.utc(2026, 1, 1, 9, 52));
      expect(saved(linked).runtime, const Duration(minutes: 52));
    });

    test('then moving the entry keeps the typed runtime', () {
      final seeded = SeededDiveTimes.of(dive(exitTime: exit));
      final linked = setDiveRuntime(seeded.shown, 60, seeded: seeded);
      final moved = moveDiveEntry(
        linked.shown,
        DateTime.utc(2026, 1, 2, 8, 0),
        seeded: linked,
      );

      expect(moved.shown.exit, DateTime.utc(2026, 1, 2, 9, 0));
      expect(saved(moved).runtime, const Duration(minutes: 60));
      expect(saved(moved).exit, DateTime.utc(2026, 1, 2, 9, 0, 50));
    });
  });
}
