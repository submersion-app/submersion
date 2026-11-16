import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/diver_gas_switch_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Records what it was asked to write.
class _Writer implements DiverGasSwitchWriter {
  final saves = <({List<GasSwitch> switches, Set<String> loadedIds})>[];

  @override
  Future<bool> save({
    required String diveId,
    required List<GasSwitch> switches,
    required Set<String> loadedIds,
    bool edited = true,
    DateTime? now,
  }) async {
    saves.add((switches: switches, loadedIds: loadedIds));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Gas switches held in a sitting (issue #4527, plan 5).
void main() {
  final t0 = DateTime.utc(2026, 3, 9, 9);
  const back = DiveTank(id: 'a', gasMix: GasMix(o2: 21));
  const deco = DiveTank(id: 'b', gasMix: GasMix(o2: 50), order: 1);
  GasSwitch sw(String id, int t, String tank, {String? computer}) => GasSwitch(
    id: id,
    diveId: 'dive',
    timestamp: t,
    tankId: tank,
    createdAt: t0,
    computerId: computer,
  );
  final profile = [
    for (var t = 0; t <= 3000; t += 10)
      DiveProfilePoint(timestamp: t, depth: t < 1500 ? 30 : 6),
  ];
  final dive = Dive(
    id: 'dive',
    dateTime: t0,
    entryTime: t0,
    tanks: const [back, deco],
    profile: profile,
    computerId: 'mine',
  );
  final stored = [sw('s1', 0, 'a'), sw('s2', 2400, 'b')];

  late _Writer writer;
  setUp(() => writer = _Writer());

  Future<EditSession<Dive>> loaded(Dive d, [List<GasSwitch>? switches]) async {
    final s = EditSession(d);
    loadGasSwitches(
      s,
      read: () async => switches ?? stored,
      writer: () => writer,
    );
    await s.settled();
    return s;
  }

  test('loaded once per sitting; another computer\'s switches are not '
      'shown', () async {
    var reads = 0;
    final s = EditSession(dive);
    Future<List<GasSwitch>> read() async {
      reads++;
      return [...stored, sw('x', 600, 'b', computer: 'theirs')];
    }

    loadGasSwitches(s, read: read, writer: () => writer);
    loadGasSwitches(s, read: read, writer: () => writer);
    await s.settled();
    expect(reads, 1);
    expect(
      [for (final g in sittingGasSwitches(s)!.current) g.id],
      ['s1', 's2'],
    );
    expect(s.isDirty, isFalse);
  });

  test('an edit holds a change of the tanks card; editing it back releases '
      'it', () async {
    final s = await loaded(dive);
    changeGasSwitch(
      s,
      stored[1].copyWith(timestamp: 2460),
      GasSwitchField.time,
    );
    expect(s.changedCardIds, {'tanks'});
    changeGasSwitch(s, stored[1], GasSwitchField.time);
    gasSwitchTimeSettled(s, 's2');
    expect(s.isDirty, isFalse);
  });

  test(
    'a time sets the depth from the profile; a typed depth is kept',
    () async {
      final s = await loaded(dive);
      changeGasSwitch(
        s,
        stored[1].copyWith(timestamp: 1000),
        GasSwitchField.time,
      );
      expect(sittingGasSwitches(s)!.current.last.depth, 30);
      changeGasSwitch(
        s,
        sittingGasSwitches(s)!.current.last.copyWith(depth: 21),
        GasSwitchField.depth,
      );
      changeGasSwitch(
        s,
        sittingGasSwitches(s)!.current.last.copyWith(timestamp: 2000),
        GasSwitchField.time,
      );
      expect(sittingGasSwitches(s)!.current.last.depth, 21);
    },
  );

  test(
    'a removed cylinder takes its switches and the notice counts them',
    () async {
      final s = await loaded(dive);
      removeSittingTank(s, 'b');
      final held = sittingGasSwitches(s)!;
      expect([for (final g in held.current) g.id], ['s1']);
      expect(held.removedWithTank, 1);
      addGasSwitch(s);
      expect(sittingGasSwitches(s)!.removedWithTank, 0);
    },
  );

  test('switches loaded after a cylinder was removed leave its switches '
      'out', () async {
    final s = EditSession(dive);
    removeSittingTank(s, 'b');
    loadGasSwitches(s, read: () async => stored, writer: () => writer);
    await s.settled();
    expect([for (final g in sittingGasSwitches(s)!.current) g.id], ['s1']);
  });

  test(
    'the held write keeps only switches whose cylinder was written',
    () async {
      final s = await loaded(dive);
      changeGasSwitch(
        s,
        stored[1].copyWith(timestamp: 2460),
        GasSwitchField.time,
      );
      setTanks(s, const [back]);
      await s.runHeldWrites();
      expect(
        writer.saves.single.switches.map((g) => g.tankId),
        everyElement('a'),
      );
      expect(writer.saves.single.loadedIds, {'s1', 's2'});
    },
  );

  group('limits', () {
    test('the profile span first', () async {
      final s = await loaded(dive);
      expect(gasSwitchTimeLimits(s), (min: 0, max: 3000));
    });

    test('else the runtime, the bottom time, exit minus entry', () async {
      final bare = dive.copyWith(profile: const []);
      final s = await loaded(bare);
      expect(gasSwitchTimeLimits(s).max, isNull);
      s.set(diveExitField, t0.add(const Duration(minutes: 50)));
      s.set(diveRuntimeField, null);
      expect(gasSwitchTimeLimits(s).max, 3000);
      s.set(diveBottomTimeField, 2400.0);
      expect(gasSwitchTimeLimits(s).max, 2400);
      s.set(diveRuntimeField, 2700.0);
      expect(gasSwitchTimeLimits(s).max, 2700);
    });

    test('a loaded switch before the start lowers the floor', () async {
      final s = await loaded(dive, [sw('early', -30, 'a'), stored[1]]);
      expect(gasSwitchTimeLimits(s).min, -30);
    });
  });

  group('valid', () {
    test(
      'a runtime shortened past a switch makes the sitting invalid',
      () async {
        final s = await loaded(dive.copyWith(profile: const []));
        s.set(diveRuntimeField, 3000.0);
        expect(gasSwitchesValid(s), isTrue);
        s.set(diveRuntimeField, 1800.0);
        expect(gasSwitchesValid(s), isFalse);
      },
    );

    test('a duplicate second is invalid', () async {
      final s = await loaded(dive);
      changeGasSwitch(s, stored[1].copyWith(timestamp: 0), GasSwitchField.time);
      expect(gasSwitchesValid(s), isFalse);
    });

    test('hidden switches are not checked', () async {
      final s = await loaded(dive);
      changeGasSwitch(s, stored[1].copyWith(timestamp: 0), GasSwitchField.time);
      s.set(divePlannedField, true);
      expect(gasSwitchesValid(s), isTrue);
    });

    test('not loaded is valid', () {
      expect(gasSwitchesValid(EditSession(dive)), isTrue);
    });
  });

  // A switch saved already outside the dive blocks nothing until the
  // diver touches it: a Notes edit is not held hostage by an old import.
  group('invalid as stored', () {
    final late = sw('late', 3600, 'b');

    test('a switch stored past the end blocks nothing', () async {
      final s = await loaded(dive, [stored[0], late]);
      expect(gasSwitchesInvalidAsStored(s), {'late'});
      expect(gasSwitchesValid(s), isTrue);
    });

    test('touching it makes it count, and a time inside clears it', () async {
      final s = await loaded(dive, [stored[0], late]);
      changeGasSwitch(s, late.copyWith(timestamp: 3500), GasSwitchField.time);
      expect(gasSwitchesInvalidAsStored(s), isEmpty);
      expect(gasSwitchesValid(s), isFalse);
      changeGasSwitch(s, late.copyWith(timestamp: 2900), GasSwitchField.time);
      expect(gasSwitchesValid(s), isTrue);
    });

    test('a new cylinder for it is touching it too', () async {
      final s = await loaded(dive, [stored[0], late]);
      changeGasSwitch(s, late.copyWith(tankId: 'a'), GasSwitchField.tank);
      expect(gasSwitchesValid(s), isFalse);
    });

    test('still out after the runtime changes, it blocks nothing', () async {
      final bare = dive.copyWith(
        profile: const [],
        runtime: const Duration(minutes: 30),
      );
      final s = await loaded(bare, [stored[0], sw('past', 2400, 'b')]);
      expect(gasSwitchesValid(s), isTrue);
      s.set(diveRuntimeField, 2100.0);
      expect(gasSwitchesInvalidAsStored(s), {'past'});
      expect(gasSwitchesValid(s), isTrue);
    });

    test('a valid switch the sitting puts out of range still blocks', () async {
      final bare = dive.copyWith(
        profile: const [],
        runtime: const Duration(minutes: 50),
      );
      final s = await loaded(bare);
      s.set(diveRuntimeField, 1800.0);
      expect(gasSwitchesInvalidAsStored(s), isEmpty);
      expect(gasSwitchesValid(s), isFalse);
    });

    test('two stored at one second block nothing until one moves', () async {
      final s = await loaded(dive, [stored[0], sw('twin', 0, 'b')]);
      expect(gasSwitchesInvalidAsStored(s), {'s1', 'twin'});
      expect(gasSwitchesValid(s), isTrue);
      changeGasSwitch(
        s,
        sw('twin', 0, 'b').copyWith(timestamp: 600),
        GasSwitchField.time,
      );
      expect(gasSwitchesValid(s), isTrue);
    });

    test('a valid switch moved onto the twins\' second blocks', () async {
      final s = await loaded(dive, [stored[0], sw('twin', 0, 'b'), stored[1]]);
      expect(gasSwitchesValid(s), isTrue);
      changeGasSwitch(s, stored[1].copyWith(timestamp: 0), GasSwitchField.time);
      expect(gasSwitchesValid(s), isFalse);
    });
  });

  test('shown only with two breathing cylinders, not gauge, not planned', () {
    expect(gasSwitchesShown(EditSession(dive)), isTrue);
    expect(
      gasSwitchesShown(EditSession(dive.copyWith(tanks: const [back]))),
      isFalse,
    );
    expect(
      gasSwitchesShown(EditSession(dive.copyWith(diveMode: DiveMode.gauge))),
      isFalse,
    );
    expect(
      gasSwitchesShown(EditSession(dive.copyWith(isPlanned: true))),
      isFalse,
    );
  });

  test(
    'a new switch goes a minute after the last, to the gas not in use',
    () async {
      final s = await loaded(dive, [sw('s1', 0, 'a')]);
      addGasSwitch(s);
      final added = sittingGasSwitches(s)!.current.last;
      expect((added.timestamp, added.tankId), (60, 'b'));
      expect(added.depth, 30);
    },
  );

  test('a read answering after Cancel sets nothing', () async {
    final gate = Completer<List<GasSwitch>>();
    final s = EditSession(dive);
    loadGasSwitches(s, read: () => gate.future, writer: () => writer);
    s.dispose();
    gate.complete(stored);
    await Future<void>.delayed(Duration.zero);
    expect(sittingGasSwitches(s), isNull);
  });
}
