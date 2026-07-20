import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  GearFeature feature({
    EquipmentType type = EquipmentType.wetsuit,
    String name = 'Suit',
    String? size,
    double? buoyancyKg,
    double? weightKg,
  }) => GearFeature.fromEquipment(
    id: 'e1',
    type: type,
    name: name,
    size: size,
    buoyancyKg: buoyancyKg,
    weightKg: weightKg,
  );

  test(
    'user-entered buoyancy is a strong prior and wins over type default',
    () {
      final f = feature(buoyancyKg: -2.0);
      expect(f.priorKg, -2.0);
      expect(f.priorStrength, 8.0);
      expect(f.hasUserSpec, isTrue);
    },
  );

  test('wetsuit thickness parsed from the name drives the prior', () {
    expect(feature(name: '7mm Farmer John').priorKg, closeTo(7.0, 0.001));
    expect(feature(name: 'Fusion 3 mm shorty').priorKg, closeTo(3.0, 0.001));
    expect(feature(name: 'Steamer', size: '5mm').priorKg, closeTo(5.0, 0.001));
  });

  test('wetsuit thickness clamps to 10 kg (raised from 8)', () {
    expect(feature(name: '12mm monster').priorKg, 10.0);
    // A parsed 9mm now survives (was clamped to 8 before).
    expect(feature(name: '9mm heavy').priorKg, closeTo(9.0, 0.001));
  });

  test('string-parsed wetsuit thickness carries attribute strength (4.0)', () {
    // Raised from the old type-default 2.0: a thickness parsed from free
    // text tells us something real about the suit.
    expect(feature(name: '7mm Farmer John').priorStrength, 4.0);
  });

  test('wetsuit without thickness defaults to 4.0', () {
    expect(feature(name: 'Old faithful').priorKg, 4.0);
    expect(feature(name: 'Old faithful').priorStrength, 2.0);
    expect(feature(name: 'Old faithful').hasUserSpec, isFalse);
  });

  test('type defaults: drysuit, bcd, hood, gloves, boots, other', () {
    expect(feature(type: EquipmentType.drysuit, name: 'DS').priorKg, 10.0);
    expect(feature(type: EquipmentType.bcd, name: 'Wing').priorKg, -0.5);
    expect(feature(type: EquipmentType.hood, name: 'H').priorKg, 0.3);
    expect(feature(type: EquipmentType.gloves, name: 'G').priorKg, 0.2);
    expect(feature(type: EquipmentType.boots, name: 'B').priorKg, 0.4);
    expect(feature(type: EquipmentType.fins, name: 'F').priorKg, 0.0);
    expect(feature(type: EquipmentType.regulator, name: 'R').priorKg, 0.0);
  });

  test('dry mass uses metadata, else type default', () {
    expect(feature(weightKg: 2.6).dryMassKg, 2.6);
    expect(feature(name: 'no meta').dryMassKg, 2.0); // wetsuit default
    expect(feature(type: EquipmentType.bcd, name: 'W').dryMassKg, 3.5);
    expect(feature(type: EquipmentType.drysuit, name: 'D').dryMassKg, 3.0);
    expect(feature(type: EquipmentType.mask, name: 'M').dryMassKg, 0.5);
  });

  test('non-finite user numerics are ignored, not propagated', () {
    // Infinity/NaN buoyancy is not an authoritative spec; fall through the
    // ladder instead of seeding the model with a non-finite prior.
    final infBuoy = feature(name: '5mm', buoyancyKg: double.infinity);
    expect(infBuoy.priorKg.isFinite, isTrue);
    expect(infBuoy.hasUserSpec, isFalse);
    expect(infBuoy.priorKg, closeTo(5.0, 0.001)); // from the name parse
    expect(infBuoy.priorStrength, 4.0);

    // Non-finite dry weight falls back to the type dry-mass default.
    final nanWeight = feature(name: 'Suit', weightKg: double.nan);
    expect(nanWeight.dryMassKg, 2.0); // wetsuit default
    expect(nanWeight.dryMassKg.isFinite, isTrue);
  });

  test('non-finite primary thickness is not a usable signal', () {
    GearFeature f(EquipmentType type, double mm) => GearFeature.fromEquipment(
      id: 't',
      type: type,
      name: 'Item',
      traits: GearBuoyancyTraits(primaryThicknessMm: mm),
    );
    // NaN thickness -> no attribute signal -> wetsuit type default.
    final nanSuit = f(EquipmentType.wetsuit, double.nan);
    expect(nanSuit.priorKg, 4.0);
    expect(nanSuit.priorStrength, 2.0);
    // Infinity thickness -> no signal -> hood type default, stays finite.
    final infHood = f(EquipmentType.hood, double.infinity);
    expect(infHood.priorKg, 0.3);
    expect(infHood.priorKg.isFinite, isTrue);
  });

  test('weights and tank types are rejected as gear features', () {
    expect(
      () => feature(type: EquipmentType.weights, name: 'Lead'),
      throwsArgumentError,
    );
    expect(
      () => feature(type: EquipmentType.tank, name: 'AL80'),
      throwsArgumentError,
    );
  });

  group('attribute-derived priors', () {
    GearFeature suit({GearBuoyancyTraits? traits, String name = 'Suit'}) =>
        GearFeature.fromEquipment(
          id: 'w1',
          type: EquipmentType.wetsuit,
          name: name,
          traits: traits,
        );

    test('multi-panel blend: torso 0.5 + limb mean 0.5', () {
      final f = suit(
        traits: const GearBuoyancyTraits(panelThicknessesMm: [5, 4, 3]),
      );
      // 5*0.5 + ((4+3)/2)*0.5 = 4.25
      expect(f.priorKg, closeTo(4.25, 0.001));
      expect(f.priorStrength, 4.0);
      expect(f.hasUserSpec, isFalse);
    });

    test('single panel equals primary; style factors apply', () {
      expect(
        suit(
          traits: const GearBuoyancyTraits(
            panelThicknessesMm: [5],
            suitStyle: 'shorty',
          ),
        ).priorKg,
        closeTo(5 * 0.55, 0.001),
      );
      expect(
        suit(
          traits: const GearBuoyancyTraits(
            primaryThicknessMm: 5,
            suitStyle: 'two_piece',
          ),
        ).priorKg,
        closeTo(5 * 1.35, 0.001),
      );
      expect(
        suit(
          traits: const GearBuoyancyTraits(
            primaryThicknessMm: 5,
            suitStyle: 'semi_dry',
          ),
        ).priorKg,
        closeTo(5.5, 0.001),
      );
    });

    test(
      'wetsuit prior clamps to 10 kg; style without thickness falls back',
      () {
        expect(
          suit(
            traits: const GearBuoyancyTraits(
              primaryThicknessMm: 9,
              suitStyle: 'two_piece',
            ),
          ).priorKg,
          10.0,
        );
        final styleOnly = suit(
          traits: const GearBuoyancyTraits(suitStyle: 'shorty'),
        );
        expect(styleOnly.priorKg, 4.0);
        expect(styleOnly.priorStrength, 2.0);
      },
    );

    test('drysuit shell material factors', () {
      GearFeature dry(String? material) => GearFeature.fromEquipment(
        id: 'd1',
        type: EquipmentType.drysuit,
        name: 'Dry',
        traits: material == null
            ? null
            : GearBuoyancyTraits(shellMaterial: material),
      );
      expect(dry('neoprene').priorKg, 13.0);
      expect(dry('crushed_neoprene').priorKg, 11.0);
      expect(dry('trilaminate').priorKg, 9.0);
      expect(dry('vulcanized_rubber').priorKg, 9.0);
      expect(dry('neoprene').priorStrength, 4.0);
      expect(dry(null).priorKg, 10.0);
      expect(dry(null).priorStrength, 2.0);
      // Unknown future choice key falls through to the default, weak.
      expect(dry('unobtainium').priorKg, 10.0);
      expect(dry('unobtainium').priorStrength, 2.0);
    });

    test('accessories scale per mm with clamps and glove modifiers', () {
      GearFeature acc(EquipmentType type, {GearBuoyancyTraits? traits}) =>
          GearFeature.fromEquipment(
            id: 'a1',
            type: type,
            name: 'Acc',
            traits: traits,
          );
      expect(
        acc(
          EquipmentType.hood,
          traits: const GearBuoyancyTraits(primaryThicknessMm: 7),
        ).priorKg,
        closeTo(0.7, 0.001),
      );
      expect(
        acc(
          EquipmentType.boots,
          traits: const GearBuoyancyTraits(primaryThicknessMm: 5),
        ).priorKg,
        closeTo(0.6, 0.001),
      );
      expect(
        acc(
          EquipmentType.gloves,
          traits: const GearBuoyancyTraits(
            primaryThicknessMm: 5,
            gloveType: 'mitt',
          ),
        ).priorKg,
        closeTo(0.06 * 5 * 1.15, 0.001),
      );
      expect(
        acc(
          EquipmentType.gloves,
          traits: const GearBuoyancyTraits(
            primaryThicknessMm: 5,
            gloveType: 'dry',
          ),
        ).priorKg,
        closeTo(0.06 * 5 * 0.5, 0.001),
      );
      // No thickness -> old flat defaults, weak.
      final flat = acc(
        EquipmentType.gloves,
        traits: const GearBuoyancyTraits(gloveType: 'mitt'),
      );
      expect(flat.priorKg, 0.2);
      expect(flat.priorStrength, 2.0);
      // Absurd thickness clamps: effective mm capped at 15, prior at 2 kg.
      expect(
        acc(
          EquipmentType.boots,
          traits: const GearBuoyancyTraits(primaryThicknessMm: 400),
        ).priorKg,
        lessThanOrEqualTo(2.0),
      );
    });

    test('bcd style and lift capacity', () {
      GearFeature bcd({GearBuoyancyTraits? traits}) =>
          GearFeature.fromEquipment(
            id: 'b1',
            type: EquipmentType.bcd,
            name: 'BCD',
            traits: traits,
          );
      expect(
        bcd(traits: const GearBuoyancyTraits(bcdStyle: 'jacket')).priorKg,
        closeTo(0.5, 0.001),
      );
      expect(
        bcd(traits: const GearBuoyancyTraits(bcdStyle: 'back_inflate')).priorKg,
        closeTo(0.0, 0.001),
      );
      expect(
        bcd(traits: const GearBuoyancyTraits(bcdStyle: 'wing')).priorKg,
        closeTo(-0.5, 0.001),
      );
      expect(
        bcd(traits: const GearBuoyancyTraits(bcdStyle: 'sidemount')).priorKg,
        closeTo(-0.3, 0.001),
      );
      final wing20 = bcd(
        traits: const GearBuoyancyTraits(bcdStyle: 'wing', liftCapacityKg: 20),
      );
      expect(wing20.priorKg, closeTo(-0.5 + 0.2, 0.001));
      expect(wing20.priorStrength, 4.0);
      // Lift alone still counts as attribute-derived (base = absent -0.5).
      final liftOnly = bcd(
        traits: const GearBuoyancyTraits(liftCapacityKg: 30),
      );
      expect(liftOnly.priorKg, closeTo(-0.5 + 0.3, 0.001));
      expect(liftOnly.priorStrength, 4.0);
      // No attributes -> unchanged default.
      expect(bcd().priorKg, -0.5);
      expect(bcd().priorStrength, 2.0);
      // An unknown/future style key with no lift is not a usable attribute
      // signal: it falls through to the type default, not the strength-4.0
      // ladder.
      final unknownStyle = bcd(
        traits: const GearBuoyancyTraits(bcdStyle: 'no_such_style'),
      );
      expect(unknownStyle.priorKg, -0.5);
      expect(unknownStyle.priorStrength, 2.0);
      // An unknown style paired with a real lift capacity still counts (the
      // lift is the signal); the unknown style contributes the absent-style
      // base, matching lift-only.
      final unknownWithLift = bcd(
        traits: const GearBuoyancyTraits(
          bcdStyle: 'no_such_style',
          liftCapacityKg: 30,
        ),
      );
      expect(unknownWithLift.priorKg, closeTo(-0.5 + 0.3, 0.001));
      expect(unknownWithLift.priorStrength, 4.0);
      // Lift is physically non-negative; a signed value from the free
      // numeric field must not drag the prior downward.
      final negLift = bcd(
        traits: const GearBuoyancyTraits(bcdStyle: 'wing', liftCapacityKg: -50),
      );
      expect(negLift.priorKg, closeTo(-0.5, 0.001));
      expect(negLift.priorStrength, 4.0);
      // A non-finite lift is likewise ignored and never yields NaN.
      final infLift = bcd(
        traits: const GearBuoyancyTraits(
          bcdStyle: 'jacket',
          liftCapacityKg: double.infinity,
        ),
      );
      expect(infLift.priorKg, closeTo(0.5, 0.001));
      expect(infLift.priorKg.isFinite, isTrue);
      // A negative-lift-only item carries no usable signal -> type default.
      final negLiftOnly = bcd(
        traits: const GearBuoyancyTraits(liftCapacityKg: -10),
      );
      expect(negLiftOnly.priorKg, -0.5);
      expect(negLiftOnly.priorStrength, 2.0);
    });

    test('explicit buoyancy still wins over traits', () {
      final f = GearFeature.fromEquipment(
        id: 'w1',
        type: EquipmentType.wetsuit,
        name: 'Suit',
        buoyancyKg: 1.25,
        traits: const GearBuoyancyTraits(primaryThicknessMm: 7),
      );
      expect(f.priorKg, 1.25);
      expect(f.priorStrength, 8.0);
      expect(f.hasUserSpec, isTrue);
    });

    test('legacy string parse now carries attribute strength', () {
      final f = GearFeature.fromEquipment(
        id: 'w1',
        type: EquipmentType.wetsuit,
        name: '7mm Farmer John',
      );
      expect(f.priorKg, closeTo(7.0, 0.001));
      expect(f.priorStrength, 4.0);
    });

    test('no attributes reproduces current defaults exactly', () {
      GearFeature bare(EquipmentType type) =>
          GearFeature.fromEquipment(id: 'x', type: type, name: 'Item');
      expect(bare(EquipmentType.wetsuit).priorKg, 4.0);
      expect(bare(EquipmentType.drysuit).priorKg, 10.0);
      expect(bare(EquipmentType.bcd).priorKg, -0.5);
      expect(bare(EquipmentType.hood).priorKg, 0.3);
      expect(bare(EquipmentType.gloves).priorKg, 0.2);
      expect(bare(EquipmentType.boots).priorKg, 0.4);
      expect(bare(EquipmentType.fins).priorKg, 0.0);
      for (final t in [
        EquipmentType.wetsuit,
        EquipmentType.drysuit,
        EquipmentType.bcd,
        EquipmentType.hood,
        EquipmentType.gloves,
        EquipmentType.boots,
        EquipmentType.fins,
      ]) {
        expect(bare(t).priorStrength, 2.0, reason: t.name);
      }
    });
  });
}
