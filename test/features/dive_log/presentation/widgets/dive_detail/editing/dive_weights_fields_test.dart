import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/data/services/diver_gas_switch_writer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

class _NoWriter implements DiverGasSwitchWriter {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The Weight card's values as fields of a sitting (issue #4527, plan 5).
void main() {
  final t0 = DateTime.utc(2026, 3, 9, 9);
  const belt = DiveWeight(
    id: 'w1',
    diveId: 'dive',
    weightType: WeightType.belt,
    amountKg: 4,
  );
  const pocket = DiveWeight(
    id: 'w2',
    diveId: 'dive',
    weightType: WeightType.integrated,
    amountKg: 2,
  );
  final dive = Dive(id: 'dive', dateTime: t0, weights: const [belt, pocket]);
  final legacy = Dive(
    id: 'dive',
    dateTime: t0,
    weightAmount: 6,
    weightType: WeightType.belt,
  );

  test('every field belongs to the weights card', () {
    expect(
      {
        diveWeightsField.cardId,
        diveWeightingFeedbackField.cardId,
        diveWeightingFeedbackKgField.cardId,
      },
      {'weights'},
    );
  });

  group('the legacy single weight', () {
    test('reads as one row and opening the card is no change', () {
      final rows = diveWeightsField.read(legacy);
      expect(rows, hasLength(1));
      expect((rows.single.id, rows.single.amountKg), ('', 6.0));
      expect(rows.single.weightType, WeightType.belt);
      final s = EditSession(legacy)..set(diveWeightsField, rows);
      expect(s.isDirty, isFalse);
    });

    test('a legacy weight with no type reads as a belt, as the form does', () {
      final untyped = Dive(id: 'dive', dateTime: t0, weightAmount: 3);
      expect(diveWeightsField.read(untyped).single.weightType, WeightType.belt);
    });

    test('edited, it is written as a row and the legacy columns clear', () {
      final s = EditSession(legacy);
      final row = diveWeightsField.read(legacy).single.copyWith(amountKg: 7);
      s.set(diveWeightsField, [row]);
      final saved = s.applyTo(legacy);
      expect(saved.weights.single.amountKg, 7);
      expect((saved.weightAmount, saved.weightType), (null, null));
    });

    test('none at all reads as no rows', () {
      expect(diveWeightsField.read(Dive(id: 'd', dateTime: t0)), isEmpty);
    });
  });

  test('the same weights in another order are no change', () {
    expect(
      diveWeightsField.same(const [belt, pocket], const [pocket, belt]),
      isTrue,
    );
    expect(
      diveWeightsField.same(
        const [belt, pocket],
        [belt, pocket.copyWith(amountKg: 3)],
      ),
      isFalse,
    );
  });

  group('weighting feedback', () {
    final over = dive.copyWith(
      weightingFeedback: WeightingFeedback.overweighted,
      weightingFeedbackKg: 2,
    );

    test('correct clears the amount', () {
      final s = EditSession(over);
      setWeightingFeedback(s, WeightingFeedback.correct);
      expect(s.valueOf(diveWeightingFeedbackKgField), isNull);
    });

    test('over again gives back the stored amount', () {
      final s = EditSession(over);
      setWeightingFeedback(s, WeightingFeedback.correct);
      setWeightingFeedback(s, WeightingFeedback.overweighted);
      expect(s.isDirty, isFalse);
    });

    test('none clears both', () {
      final s = EditSession(over);
      setWeightingFeedback(s, null);
      final saved = s.applyTo(over);
      expect(
        (saved.weightingFeedback, saved.weightingFeedbackKg),
        (null, null),
      );
    });
  });

  test('a preset replaces the weights with fresh rows', () {
    final preset = WeightPreset(
      id: 'p',
      diverId: 'me',
      displayName: 'Warm water',
      entries: const [
        WeightPresetEntry(
          id: 'e',
          presetId: 'p',
          weightType: WeightType.integrated,
          amountKg: 3,
        ),
      ],
      createdAt: t0,
      updatedAt: t0,
    );
    final s = EditSession(dive);
    applyWeightPresetInSitting(s, preset);
    final rows = s.valueOf(diveWeightsField);
    expect(rows.single.amountKg, 3);
    expect(rows.single.id, isNotEmpty);
    expect(rows.single.diveId, 'dive');
  });

  test('the last dive at a center replaces weights and cylinders, and drops '
      'their switches', () async {
    const back = DiveTank(id: 'a', volume: 12, gasMix: GasMix(o2: 32));
    const deco = DiveTank(id: 'b', gasMix: GasMix(o2: 50), order: 1);
    final withGas = dive.copyWith(tanks: const [back, deco]);
    final s = EditSession(withGas);
    loadGasSwitches(
      s,
      read: () async => [
        GasSwitch(
          id: 's',
          diveId: 'dive',
          timestamp: 60,
          tankId: 'b',
          createdAt: t0,
        ),
      ],
      writer: _NoWriter.new,
    );
    await s.settled();
    final last = LastDiveAtCenter(
      diveId: 'old',
      dateTime: t0.subtract(const Duration(days: 30)),
      weightingFeedback: null,
      weightingFeedbackKg: null,
      weights: const [
        DiveWeight(
          id: 'x',
          diveId: 'old',
          weightType: WeightType.belt,
          amountKg: 8,
        ),
      ],
      tanks: const [DiveTank(id: 'y', volume: 11.1, gasMix: GasMix(o2: 21))],
    );

    applyLastDiveInSitting(s, last, defaultStartPressure: 200);

    final w = s.working;
    expect(w.weights.single.amountKg, 8);
    expect(w.weights.single.id, isNot('x'));
    expect(w.tanks.single.volume, 11.1);
    expect(w.tanks.single.id, isNot('y'));
    expect(
      (w.tanks.single.startPressure, w.tanks.single.endPressure),
      (200.0, 50.0),
    );
    expect(sittingGasSwitches(s)!.current, isEmpty);
    expect(s.changedCardIds, {'weights', 'tanks'});
  });

  test(
    'applying asks first whenever the sitting holds weights or cylinders',
    () {
      expect(
        applyLastDiveNeedsConfirm(weights: const [], tanks: const []),
        isFalse,
      );
      expect(
        applyLastDiveNeedsConfirm(weights: const [belt], tanks: const []),
        isTrue,
      );
    },
  );
}
