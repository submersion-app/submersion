import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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
  final entry = DateTime.utc(2026, 1, 1, 10, 0, 50);
  final exit = DateTime.utc(2026, 1, 1, 10, 50, 10);
  const runtime = Duration(seconds: 2960);
  const bottomTime = Duration(seconds: 2409);

  /// The dive from issue #3901.
  Dive imported({
    DateTime? exitTime,
    Duration? bottom = bottomTime,
    Duration? run = runtime,
    List<DiveProfilePoint> profile = const [],
  }) => Dive(
    id: 'dive-3901',
    dateTime: entry,
    entryTime: entry,
    exitTime: exitTime,
    bottomTime: bottom,
    runtime: run,
    profile: profile,
  );

  group('SeededDiveTimes.of', () {
    test('shows whole minutes and keeps the stored values exact', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));

      expect(seeded.shown.entry, DateTime.utc(2026, 1, 1, 10, 0));
      expect(seeded.shown.exit, DateTime.utc(2026, 1, 1, 10, 50));
      expect(seeded.shown.bottomTimeMinutes, 40);
      expect(seeded.shown.runtimeMinutes, 49);
      expect(seeded.exact.entry, entry);
      expect(seeded.exact.exit, exit);
      expect(seeded.exact.bottomTime, bottomTime);
      expect(seeded.exact.runtime, runtime);
    });

    test('falls back to dateTime for a dive with no entry time', () {
      final seeded = SeededDiveTimes.of(Dive(id: 'd', dateTime: entry));

      expect(seeded.shown.entry, DateTime.utc(2026, 1, 1, 10, 0));
      expect(seeded.exact.entry, entry);
    });

    test('estimates a missing exit from runtime, not held as stored', () {
      final seeded = SeededDiveTimes.of(imported());

      // 10:00:50 + 2960 s = 10:50:10.
      expect(seeded.shown.exit, DateTime.utc(2026, 1, 1, 10, 50));
      expect(seeded.exact.exit, isNull);
    });

    test('estimates a missing exit from bottom time with no runtime', () {
      final seeded = SeededDiveTimes.of(imported(run: null));

      // 10:00:50 + 2409 s = 10:40:59.
      expect(seeded.shown.exit, DateTime.utc(2026, 1, 1, 10, 40));
      expect(seeded.exact.exit, isNull);
    });

    test('shows runtime from the timestamps when none is stored', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit, run: null));

      expect(seeded.shown.runtimeMinutes, 49);
      expect(seeded.exact.runtime, runtime);
    });

    test('times runtime from dateTime for a dive with no entry time', () {
      final seeded = SeededDiveTimes.of(
        Dive(id: 'd', dateTime: entry, exitTime: exit),
      );

      expect(seeded.shown.runtimeMinutes, 49);
      expect(resolveDiveTimes(seeded.shown, seeded: seeded).runtime, runtime);
    });

    test('never holds a negative runtime from reversed timestamps', () {
      final seeded = SeededDiveTimes.of(
        imported(
          exitTime: entry.subtract(const Duration(minutes: 5)),
          run: null,
        ),
      );

      expect(seeded.exact.runtime, isNull);
    });

    test('holds a profile bottom time exactly when none is stored', () {
      final dive = imported(
        exitTime: exit,
        bottom: null,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 60, depth: 20),
          DiveProfilePoint(timestamp: 2510, depth: 20),
          DiveProfilePoint(timestamp: 2570, depth: 0),
        ],
      );
      final calculated = dive.calculateBottomTimeFromProfile();

      final seeded = SeededDiveTimes.of(dive);

      expect(calculated, isNotNull);
      expect(seeded.exact.bottomTime, calculated);
      expect(seeded.shown.bottomTimeMinutes, calculated!.inMinutes);
    });
  });

  group('resolveDiveTimes', () {
    test('an untouched form saves every stored value exactly (#3901)', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));

      final saved = resolveDiveTimes(seeded.shown, seeded: seeded);

      expect(saved.entry, entry);
      expect(saved.exit, exit);
      expect(saved.runtime, runtime);
      expect(saved.bottomTime, bottomTime);
    });

    test('keeps a stored runtime that differs from exit minus entry', () {
      const reported = Duration(seconds: 2900);
      final seeded = SeededDiveTimes.of(
        imported(exitTime: exit, run: reported),
      );

      final saved = resolveDiveTimes(seeded.shown, seeded: seeded);

      expect(saved.runtime, reported);
    });

    test('an estimated exit stays unset and runtime stays stored', () {
      final seeded = SeededDiveTimes.of(imported());

      final saved = resolveDiveTimes(seeded.shown, seeded: seeded);

      expect(saved.exit, isNull);
      expect(saved.runtime, runtime);
    });

    test('an estimated exit does not turn bottom time into runtime', () {
      final seeded = SeededDiveTimes.of(imported(run: null));

      final saved = resolveDiveTimes(seeded.shown, seeded: seeded);

      expect(saved.exit, isNull);
      expect(saved.runtime, isNull);
      expect(saved.bottomTime, bottomTime);
    });

    test('a moved entry saves the pick and derives runtime from it', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));
      final moved = DateTime.utc(2026, 1, 1, 10, 5);

      final saved = resolveDiveTimes(
        seeded.shown.copyWith(entry: moved),
        seeded: seeded,
      );

      expect(saved.entry, moved);
      expect(saved.exit, exit);
      expect(saved.runtime, exit.difference(moved));
      expect(saved.bottomTime, bottomTime);
    });

    test('a moved exit saves the pick and derives runtime from it', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));
      final moved = DateTime.utc(2026, 1, 1, 10, 55);

      final saved = resolveDiveTimes(
        seeded.shown.copyWith(exit: moved),
        seeded: seeded,
      );

      expect(saved.entry, entry);
      expect(saved.exit, moved);
      expect(saved.runtime, moved.difference(entry));
    });

    test('an exit moved before entry saves no runtime', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));

      final saved = resolveDiveTimes(
        seeded.shown.copyWith(exit: DateTime.utc(2026, 1, 1, 9, 0)),
        seeded: seeded,
      );

      expect(saved.runtime, isNull);
    });

    test('picking an exit for a dive without one derives runtime', () {
      final seeded = SeededDiveTimes.of(imported());
      final picked = DateTime.utc(2026, 1, 1, 10, 55);

      final saved = resolveDiveTimes(
        seeded.shown.copyWith(exit: picked),
        seeded: seeded,
      );

      expect(saved.exit, picked);
      expect(saved.runtime, picked.difference(entry));
    });

    test('a moved entry leaves a stored runtime alone with no exit', () {
      final seeded = SeededDiveTimes.of(imported());

      final saved = resolveDiveTimes(
        seeded.shown.copyWith(entry: DateTime.utc(2026, 1, 1, 11, 0)),
        seeded: seeded,
      );

      expect(saved.exit, isNull);
      expect(saved.runtime, runtime);
    });

    test('a typed bottom time saves the whole minutes typed', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));

      final saved = resolveDiveTimes(
        seeded.shown.copyWith(bottomTimeMinutes: 41),
        seeded: seeded,
      );

      expect(saved.bottomTime, const Duration(minutes: 41));
      expect(saved.runtime, runtime);
    });

    test('a cleared bottom time saves none', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));

      final saved = resolveDiveTimes(
        DiveTimeInputs(
          entry: seeded.shown.entry,
          exit: seeded.shown.exit,
          runtimeMinutes: seeded.shown.runtimeMinutes,
        ),
        seeded: seeded,
      );

      expect(saved.bottomTime, isNull);
    });

    test('a typed runtime saves when the dive has no exit', () {
      final seeded = SeededDiveTimes.of(imported());

      final saved = resolveDiveTimes(
        seeded.shown.copyWith(runtimeMinutes: 55),
        seeded: seeded,
      );

      expect(saved.runtime, const Duration(minutes: 55));
    });

    test('a dive with an exit keeps deriving runtime from its times', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));

      final saved = resolveDiveTimes(
        seeded.shown.copyWith(runtimeMinutes: 55),
        seeded: seeded,
      );

      expect(saved.runtime, runtime);
    });

    test('a new dive saves what the form holds', () {
      final newEntry = DateTime.utc(2026, 1, 1, 10, 0);
      final newExit = DateTime.utc(2026, 1, 1, 10, 50);

      final saved = resolveDiveTimes(
        DiveTimeInputs(
          entry: newEntry,
          exit: newExit,
          bottomTimeMinutes: 40,
          runtimeMinutes: 12,
        ),
      );

      expect(saved.entry, newEntry);
      expect(saved.exit, newExit);
      expect(saved.bottomTime, const Duration(minutes: 40));
      expect(saved.runtime, const Duration(minutes: 50));
    });

    test('a new dive with no exit saves the runtime typed', () {
      final saved = resolveDiveTimes(
        DiveTimeInputs(
          entry: DateTime.utc(2026, 1, 1, 10, 0),
          runtimeMinutes: 12,
        ),
      );

      expect(saved.exit, isNull);
      expect(saved.bottomTime, isNull);
      expect(saved.runtime, const Duration(minutes: 12));
    });
  });

  group('ExactDiveTimes.end', () {
    test('is the exit when there is one', () {
      final times = ExactDiveTimes(entry: entry, exit: exit, runtime: runtime);

      expect(times.end, exit);
    });

    test('is the runtime after entry with no exit', () {
      expect(ExactDiveTimes(entry: entry, runtime: runtime).end, exit);
    });

    test('is unset with no exit and no positive runtime', () {
      expect(ExactDiveTimes(entry: entry).end, isNull);
      expect(ExactDiveTimes(entry: entry, runtime: Duration.zero).end, isNull);
    });
  });

  group('SeededDiveTimes.entryFor and exitFor', () {
    test('read the stored instant for an unchanged input', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));

      expect(seeded.entryFor(seeded.shown.entry), entry);
      expect(seeded.exitFor(seeded.shown.exit), exit);
    });

    test('read the input once it moves', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));
      final moved = DateTime.utc(2026, 1, 1, 11, 0);

      expect(seeded.entryFor(moved), moved);
      expect(seeded.exitFor(moved), moved);
    });

    test('read an unchanged estimated exit as unset', () {
      final seeded = SeededDiveTimes.of(imported());

      expect(seeded.exitFor(seeded.shown.exit), isNull);
    });
  });

  group('SeededDiveTimes.withExitPicked', () {
    test('saves an estimated exit the diver confirmed at the minute shown', () {
      final seeded = SeededDiveTimes.of(imported(run: null));
      final confirmed = DateTime.utc(2026, 1, 1, 10, 40);

      final saved = resolveDiveTimes(
        seeded.shown,
        seeded: seeded.withExitPicked(),
      );

      expect(saved.exit, confirmed);
      expect(saved.runtime, confirmed.difference(entry));
    });

    test('a confirmed estimate does not bring runtime down to bottom time', () {
      final seeded = SeededDiveTimes.of(imported());

      final saved = resolveDiveTimes(
        seeded.shown,
        seeded: seeded.withExitPicked(),
      );

      // Exit 10:50:00 minus entry 10:00:50, the minute the picker holds.
      expect(saved.runtime, const Duration(seconds: 2950));
    });

    test('keeps a stored exit confirmed at the same minute', () {
      final seeded = SeededDiveTimes.of(imported(exitTime: exit));

      final saved = resolveDiveTimes(
        seeded.shown,
        seeded: seeded.withExitPicked(),
      );

      expect(saved.exit, exit);
      expect(saved.runtime, runtime);
    });
  });
}
