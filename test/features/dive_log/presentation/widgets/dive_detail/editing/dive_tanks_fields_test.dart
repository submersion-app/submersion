import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Tanks card's values as fields of a sitting, and the dive mode rule
/// (issue #4527, plan 5).
void main() {
  const back = DiveTank(id: 'a', volume: 12, startPressure: 200);
  const stage = DiveTank(id: 'b', volume: 7, gasMix: GasMix(o2: 50), order: 1);
  final oc = Dive(
    id: 'dive',
    dateTime: DateTime.utc(2026, 3, 9),
    tanks: const [back, stage],
  );
  final ccr = oc.copyWith(
    diveMode: DiveMode.ccr,
    setpointLow: 0.7,
    setpointHigh: 1.3,
    setpointDeco: 1.4,
    diluentGas: const GasMix(o2: 21),
    scrubber: const ScrubberInfo(type: 'Sofnolime', ratedMinutes: 180),
    loopVolume: 6,
  );
  final scr = oc.copyWith(
    diveMode: DiveMode.scr,
    scrType: ScrType.cmf,
    scrInjectionRate: 8,
    scrAdditionRatio: 0.33,
    scrOrificeSize: '40',
    assumedVo2: 1.3,
    loopO2Min: 30,
    loopO2Max: 60,
    loopO2Avg: 45,
    diluentGas: const GasMix(o2: 40),
    scrubber: const ScrubberInfo(type: 'ExtendAir'),
  );

  final all = <EditField<Dive, Object?>>[
    diveModeField,
    diveSetpointLowField,
    diveSetpointHighField,
    diveSetpointDecoField,
    diveDiluentGasField,
    diveScrubberField,
    diveLoopVolumeField,
    diveScrTypeField,
    diveScrInjectionRateField,
    diveScrAdditionRatioField,
    diveScrOrificeSizeField,
    diveAssumedVo2Field,
    diveLoopO2MinField,
    diveLoopO2MaxField,
    diveLoopO2AvgField,
    diveTanksField,
  ];

  void seedCcr(EditSession<Dive> s) =>
      setDiveMode(s, DiveMode.ccr, seedLow: 0.7, seedHigh: 1.2);

  test('every field belongs to the tanks card, and ids are unique', () {
    expect({for (final f in all) f.cardId}, {'tanks'});
    expect({for (final f in all) f.id}, hasLength(all.length));
  });

  test('the mode is also shown on details and the header', () {
    expect(diveModeField.alsoShownOn, {'details', 'header'});
  });

  test('each optional value can be emptied', () {
    // Every rebreather value set at once, so clearing one is seen.
    final full = ccr.copyWith(
      scrType: ScrType.cmf,
      scrInjectionRate: 8,
      scrAdditionRatio: 0.33,
      scrOrificeSize: '40',
      assumedVo2: 1.3,
      loopO2Min: 30,
      loopO2Max: 60,
      loopO2Avg: 45,
    );
    for (final field in all) {
      if (field == diveModeField || field == diveTanksField) continue;
      expect(field.read(full), isNotNull, reason: field.id);
      // Called dynamically: a typed write cannot be reached through Object?.
      final Dive cleared = (field as dynamic).write(full, null);
      expect(field.read(cleared), isNull, reason: field.id);
    }
  });

  test('cylinders in another order are a change', () {
    expect(
      diveTanksField.same(const [back, stage], const [stage, back]),
      isFalse,
    );
    expect(
      diveTanksField.same(const [back, stage], const [back, stage]),
      isTrue,
    );
  });

  group('setDiveMode', () {
    test('entering CCR fills empty setpoints only', () {
      final s = EditSession(oc.copyWith(setpointHigh: 1.4));
      seedCcr(s);
      expect(s.valueOf(diveModeField), DiveMode.ccr);
      expect(s.valueOf(diveSetpointLowField), 0.7);
      expect(s.valueOf(diveSetpointHighField), 1.4);
    });

    test('OC, CCR, OC leaves the sitting clean', () {
      final s = EditSession(oc);
      seedCcr(s);
      setDiveMode(s, DiveMode.oc, seedLow: 0.7, seedHigh: 1.2);
      expect(s.isDirty, isFalse);
    });

    test('a seeded setpoint the diver changed is kept on leaving CCR', () {
      final s = EditSession(oc);
      seedCcr(s);
      s.set(diveSetpointLowField, 0.8);
      setDiveMode(s, DiveMode.oc, seedLow: 0.7, seedHigh: 1.2);
      expect(s.valueOf(diveSetpointLowField), 0.8);
      expect(s.valueOf(diveSetpointHighField), isNull);
    });

    test('to gauge and back keeps every cylinder', () {
      final s = EditSession(oc);
      setDiveMode(s, DiveMode.gauge, seedLow: 0.7, seedHigh: 1.2);
      expect(s.working.tanks, oc.tanks);
      setDiveMode(s, DiveMode.oc, seedLow: 0.7, seedHigh: 1.2);
      expect(s.isDirty, isFalse);
    });
  });

  group('at Save', () {
    test('CCR to OC drops setpoints, diluent, scrubber and loop volume', () {
      final s = EditSession(ccr);
      setDiveMode(s, DiveMode.oc, seedLow: 0.7, seedHigh: 1.2);
      final saved = diveSittingApply(s, ccr);
      expect(saved.diveMode, DiveMode.oc);
      expect([
        saved.setpointLow,
        saved.setpointHigh,
        saved.setpointDeco,
        saved.diluentGas,
        saved.scrubber,
        saved.loopVolume,
      ], everyElement(isNull));
      expect(saved.tanks, ccr.tanks);
    });

    test('SCR to CCR drops the SCR values and keeps the gas as diluent', () {
      final s = EditSession(scr);
      seedCcr(s);
      final saved = diveSittingApply(s, scr);
      expect(saved.diluentGas, const GasMix(o2: 40));
      expect(saved.scrubber, scr.scrubber);
      expect([
        saved.scrType,
        saved.scrInjectionRate,
        saved.scrAdditionRatio,
        saved.scrOrificeSize,
        saved.assumedVo2,
        saved.loopO2Min,
        saved.loopO2Max,
        saved.loopO2Avg,
      ], everyElement(isNull));
      expect((saved.setpointLow, saved.setpointHigh), (0.7, 1.2));
    });

    test('a stored OC dive with setpoints, saved for another card, keeps '
        'them', () {
      final leftover = oc.copyWith(setpointLow: 0.7, setpointHigh: 1.3);
      final s = EditSession(leftover)..set(diveTanksField, const [back]);
      final saved = diveSittingApply(s, leftover);
      expect((saved.setpointLow, saved.setpointHigh), (0.7, 1.3));
      expect(saved.tanks, const [back]);
    });

    test('a value typed under a mode picked and left again is not saved; '
        'the dive keeps what it was stored with', () {
      final leftover = oc.copyWith(loopVolume: 5);
      final s = EditSession(leftover);
      setDiveMode(s, DiveMode.scr, seedLow: 0.7, seedHigh: 1.2);
      s.set(diveScrInjectionRateField, 9.5);
      setDiveMode(s, DiveMode.ccr, seedLow: 0.7, seedHigh: 1.2);
      s
        ..set(diveDiluentGasField, const GasMix(o2: 21))
        ..set(diveLoopVolumeField, 7.0);
      setDiveMode(s, DiveMode.oc, seedLow: 0.7, seedHigh: 1.2);

      final saved = diveSittingApply(s, leftover);
      expect(saved.diveMode, DiveMode.oc);
      expect(saved.scrInjectionRate, isNull);
      expect(saved.diluentGas, isNull);
      expect(saved.loopVolume, 5);
    });

    test('changes are applied to the dive as stored at Save', () {
      final s = EditSession(oc)..set(diveTanksField, const [back]);
      final newer = oc.copyWith(notes: 'synced');
      expect(diveSittingApply(s, newer).notes, 'synced');
    });
  });
}
