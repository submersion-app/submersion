import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The header block's values as fields of a sitting, and the rules that
/// keep entry, exit and runtime in step (issue #4527, plan 4).
void main() {
  final entry = DateTime.utc(2026, 3, 9, 9, 42, 27);
  final exit = DateTime.utc(2026, 3, 9, 10, 34, 51);
  const runtime = Duration(minutes: 52, seconds: 24);
  final timed = Dive(
    id: 'dive',
    dateTime: entry,
    entryTime: entry,
    exitTime: exit,
    runtime: runtime,
    diveNumber: 214,
  );

  double seconds(Duration d) => d.inSeconds.toDouble();

  final all = <EditField<Dive, Object?>>[
    diveNameField,
    diveNumberField,
    diveSiteField,
    diveEntryField,
    diveExitField,
    diveRuntimeField,
    diveBottomTimeField,
    diveMaxDepthField,
    diveAvgDepthField,
    diveWaterTempField,
    diveRatingField,
    diveFavoriteField,
    divePlannedField,
  ];

  test('every field belongs to the header card, and ids are unique', () {
    expect({for (final f in all) f.cardId}, {diveHeaderCardId});
    expect({for (final f in all) f.id}, hasLength(all.length));
    expect(diveHeaderCardId, 'header');
  });

  test('average depth is shown on Details as well', () {
    expect(diveAvgDepthField.alsoShownOn, {'details'});
  });

  test('the entry writes entryTime and dateTime together', () {
    final t = DateTime.utc(2026, 3, 10, 8);
    final d = diveEntryField.write(timed, t);
    expect((d.entryTime, d.dateTime), (t, t));
  });

  test('a dive stored with dateTime only reads it as its entry', () {
    final legacy = Dive(id: 'dive', dateTime: entry);
    final session = EditSession(legacy)..set(diveEntryField, entry);

    expect(diveEntryField.read(legacy), entry);
    expect(session.isDirty, isFalse);
  });

  test('a rating of 0 is no rating, and clears a stored one', () {
    final rated = timed.copyWith(rating: 4);
    expect(diveRatingField.write(rated, 0).rating, isNull);
    expect(diveRatingField.write(rated, null).rating, isNull);
    expect(diveRatingField.same(0, null), isTrue);
  });

  test('the number rounds, and null clears it', () {
    expect(diveNumberField.read(timed), 214.0);
    expect(diveNumberField.write(timed, 215.0).diveNumber, 215);
    expect(diveNumberField.write(timed, null).diveNumber, isNull);
  });

  test('the name is trimmed, and blank is none', () {
    final named = timed.copyWith(name: 'Night drift');
    expect(diveNameField.write(timed, '  Night drift ').name, 'Night drift');
    expect(diveNameField.write(named, '   ').name, isNull);
    expect(diveNameField.same(' a ', 'a'), isTrue);
  });

  test('depths, temperature and bottom time clear with null', () {
    final full = timed.copyWith(
      maxDepth: 28.4,
      avgDepth: 16.2,
      waterTemp: 24,
      bottomTime: const Duration(minutes: 41),
    );
    expect(diveMaxDepthField.write(full, null).maxDepth, isNull);
    expect(diveAvgDepthField.write(full, null).avgDepth, isNull);
    expect(diveWaterTempField.write(full, null).waterTemp, isNull);
    expect(diveBottomTimeField.write(full, null).bottomTime, isNull);
    expect(diveBottomTimeField.read(full), 2460.0);
  });

  test('runtime is held in seconds, and null clears it', () {
    expect(diveRuntimeField.read(timed), 3144.0);
    expect(
      diveRuntimeField.write(timed, 3600.0).runtime,
      Duration.zero + const Duration(hours: 1),
    );
    expect(diveRuntimeField.write(timed, null).runtime, isNull);
  });

  test('the same site with other details is not a change', () {
    const a = DiveSite(id: 'a', name: 'Blue Corner');
    const renamed = DiveSite(id: 'a', name: 'Blue Corner Wall');
    const b = DiveSite(id: 'b', name: 'Blue Hole');
    expect(diveSiteField.same(a, renamed), isTrue);
    expect(diveSiteField.same(a, b), isFalse);
    expect(diveSiteField.write(timed.copyWith(site: a), null).site, isNull);
  });

  group('pickedInstant', () {
    test('the stored minute keeps the stored seconds', () {
      expect(pickedInstant(DateTime.utc(2026, 3, 9, 9, 42), entry), entry);
    });

    test('another minute is taken as picked', () {
      final picked = DateTime.utc(2026, 3, 9, 9, 43);
      expect(pickedInstant(picked, entry), picked);
    });

    test('with nothing current it is taken as picked', () {
      final picked = DateTime.utc(2026, 3, 9, 9, 43);
      expect(pickedInstant(picked, null), picked);
    });
  });

  group('linked times', () {
    EditSession<Dive> sitting([Dive? dive]) => EditSession(dive ?? timed);

    test(
      'moving the entry moves the exit by as much, and keeps the runtime',
      () {
        final session = sitting();

        setEntryTime(session, entry.add(const Duration(minutes: 10)));

        expect(
          session.valueOf(diveExitField),
          exit.add(const Duration(minutes: 10)),
        );
        expect(session.valueOf(diveRuntimeField), seconds(runtime));
      },
    );

    test('moving the entry back leaves the sitting clean', () {
      final session = sitting();

      setEntryTime(session, entry.add(const Duration(days: 1)));
      setEntryTime(session, entry);

      expect(session.isDirty, isFalse);
    });

    test('a dive with no exit keeps none when the entry moves', () {
      final session = sitting(
        Dive(id: 'dive', dateTime: entry, entryTime: entry, runtime: runtime),
      );

      setEntryTime(session, entry.add(const Duration(minutes: 10)));

      expect(session.valueOf(diveExitField), isNull);
    });

    test('a new exit sets the runtime to exit minus entry', () {
      final session = sitting();

      setExitTime(session, DateTime.utc(2026, 3, 9, 10, 42, 27));

      expect(session.valueOf(diveRuntimeField), 3600.0);
    });

    test('an exit before the entry clears the runtime', () {
      final session = sitting();

      setExitTime(session, DateTime.utc(2026, 3, 9, 9));

      expect(session.valueOf(diveRuntimeField), isNull);
    });

    test('the stored exit set again changes nothing', () {
      final session = sitting();

      setExitTime(session, exit);

      expect(session.isDirty, isFalse);
    });

    test('an exit moved and moved back leaves the sitting clean', () {
      // The stored runtime is not exit minus entry: a computer's own count.
      final session = sitting(
        timed.copyWith(runtime: const Duration(minutes: 51)),
      );

      setExitTime(session, DateTime.utc(2026, 3, 9, 11));
      setExitTime(session, exit);

      expect(session.isDirty, isFalse);
    });

    test('clearing the exit leaves the runtime', () {
      final session = sitting();

      setExitTime(session, null);

      expect(session.valueOf(diveExitField), isNull);
      expect(session.valueOf(diveRuntimeField), seconds(runtime));
    });

    test('a runtime moves a recorded exit', () {
      final session = sitting();

      setRuntime(session, const Duration(minutes: 60));

      expect(
        session.valueOf(diveExitField),
        DateTime.utc(2026, 3, 9, 10, 42, 27),
      );
    });

    test('the stored runtime typed back puts the stored exit back', () {
      final session = sitting(
        timed.copyWith(runtime: const Duration(minutes: 51)),
      );

      setRuntime(session, const Duration(minutes: 60));
      setRuntime(session, const Duration(minutes: 51));

      expect(session.valueOf(diveExitField), exit);
      expect(session.isDirty, isFalse);
    });

    // Final review, Important 2: emptying the field a digit at a time
    // passes through runtimes the diver never meant.
    test('a runtime cleared digit by digit puts the exit back', () {
      final session = sitting();

      setRuntime(session, const Duration(minutes: 5));
      setRuntime(session, null);

      expect(session.valueOf(diveExitField), exit);
      expect(session.valueOf(diveRuntimeField), isNull);
    });

    test('a runtime typed down to zero puts the exit back', () {
      final session = sitting();

      setRuntime(session, const Duration(minutes: 60));
      setRuntime(session, const Duration(minutes: 6));
      setRuntime(session, Duration.zero);

      expect(session.valueOf(diveExitField), exit);
    });

    // PR review: the entry moved between typing a runtime and clearing it
    // moves the exit to give back with it.
    test('a runtime cleared after the entry moved gives back the exit, moved '
        'with the entry', () {
      final session = sitting();
      const shift = Duration(minutes: 10);

      setRuntime(session, const Duration(minutes: 60));
      setEntryTime(session, entry.add(shift));
      setRuntime(session, null);

      expect(session.valueOf(diveExitField), exit.add(shift));
    });

    test('an exit picked after typing a runtime is kept when the runtime is '
        'cleared', () {
      final session = sitting();
      final picked = DateTime.utc(2026, 3, 9, 11);

      setRuntime(session, const Duration(minutes: 60));
      setExitTime(session, picked);
      setRuntime(session, null);

      expect(session.valueOf(diveExitField), picked);
    });

    // Code review: the stored runtime typed back on a dive stored with no
    // exit must move the exit the diver picked, not clear it.
    test(
      'the stored runtime typed back keeps an exit picked in the sitting',
      () {
        final session = sitting(
          Dive(id: 'dive', dateTime: entry, entryTime: entry, runtime: runtime),
        );
        setExitTime(session, DateTime.utc(2026, 3, 9, 10, 50));

        setRuntime(session, const Duration(minutes: 5));
        setRuntime(session, runtime);

        expect(session.valueOf(diveExitField), entry.add(runtime));
        expect(session.valueOf(diveRuntimeField), seconds(runtime));
      },
    );

    test('a runtime on a dive with no exit stores no exit', () {
      final session = sitting(
        Dive(id: 'dive', dateTime: entry, entryTime: entry, runtime: runtime),
      );

      setRuntime(session, const Duration(minutes: 60));

      expect(session.valueOf(diveExitField), isNull);
      expect(session.valueOf(diveRuntimeField), 3600.0);
    });

    test('zero or no runtime moves nothing', () {
      final session = sitting();

      setRuntime(session, Duration.zero);
      expect(session.valueOf(diveExitField), exit);

      setRuntime(session, null);
      expect(session.valueOf(diveExitField), exit);
      expect(session.valueOf(diveRuntimeField), isNull);
    });

    test('the estimate is entry plus runtime, else bottom time, else none', () {
      final noExit = Dive(id: 'dive', dateTime: entry, entryTime: entry);
      expect(
        estimatedExit(noExit.copyWith(runtime: runtime)),
        entry.add(runtime),
      );
      expect(
        estimatedExit(noExit.copyWith(bottomTime: const Duration(minutes: 40))),
        entry.add(const Duration(minutes: 40)),
      );
      expect(estimatedExit(noExit), isNull);
      expect(estimatedExit(timed), isNull);
    });
  });

  group('planned', () {
    Future<int?> never() async => fail('no number should be asked for');

    test('planned clears the number', () {
      final session = EditSession(timed);

      setPlanned(session, true, nextNumber: never);

      expect(session.valueOf(divePlannedField), isTrue);
      expect(session.valueOf(diveNumberField), isNull);
    });

    test('back to logged gives the stored number back, and is clean', () {
      final session = EditSession(timed);

      setPlanned(session, true, nextNumber: never);
      setPlanned(session, false, nextNumber: never);

      expect(session.valueOf(diveNumberField), 214.0);
      expect(session.isDirty, isFalse);
    });

    test('a logged dive with no number is offered the next one', () async {
      final session = EditSession(timed.copyWith(clearDiveNumber: true))
        ..set(divePlannedField, true);

      setPlanned(session, false, nextNumber: () async => 215);
      await session.settled();

      expect(session.valueOf(diveNumberField), 215.0);
    });

    test('the next number is dropped if one was typed meanwhile', () async {
      final session = EditSession(timed.copyWith(clearDiveNumber: true))
        ..set(divePlannedField, true);
      final gate = Completer<int?>();

      setPlanned(session, false, nextNumber: () => gate.future);
      session.set(diveNumberField, 300.0);
      gate.complete(215);
      await session.settled();

      expect(session.valueOf(diveNumberField), 300.0);
    });

    test('the next number is dropped if planned again meanwhile', () async {
      final session = EditSession(timed.copyWith(clearDiveNumber: true))
        ..set(divePlannedField, true);
      final gate = Completer<int?>();

      setPlanned(session, false, nextNumber: () => gate.future);
      setPlanned(session, true, nextNumber: never);
      gate.complete(215);
      await session.settled();

      expect(session.valueOf(diveNumberField), isNull);
    });

    test('a number that cannot be had leaves the dive without one', () async {
      final session = EditSession(timed.copyWith(clearDiveNumber: true))
        ..set(divePlannedField, true);

      setPlanned(
        session,
        false,
        nextNumber: () async => throw StateError('no database'),
      );
      await session.settled();

      expect(session.valueOf(diveNumberField), isNull);
    });

    test('the switch is offered only for a logged dive with no source that '
        'is not a draft', () {
      expect(plannedSwitchOffered(timed, hasPrimarySource: false), isTrue);
      expect(plannedSwitchOffered(timed, hasPrimarySource: true), isFalse);
      expect(
        plannedSwitchOffered(
          timed.copyWith(isPlanned: true),
          hasPrimarySource: false,
        ),
        isFalse,
      );
      expect(
        plannedSwitchOffered(
          timed.copyWith(isDraft: true),
          hasPrimarySource: false,
        ),
        isFalse,
      );
    });

    // PR review: sources not yet loaded are not "no source".
    test('the switch is not offered while the sources are unknown', () {
      expect(plannedSwitchOffered(timed, hasPrimarySource: null), isFalse);
    });
  });
}
