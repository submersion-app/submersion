import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/gas_exchange.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

/// Issue #4228: the tissue card shows each inert gas's direction on its own
/// (after trimix, helium leaves while nitrogen comes back in) and marks the
/// loading a compartment settles at when it is fully equilibrated with air.
void main() {
  // ZH-L16C compartment 1 coefficients.
  TissueCompartment comp1({double pN2 = 0.74, double pHe = 0.0}) =>
      TissueCompartment(
        compartmentNumber: 1,
        halfTimeN2: 4.0,
        halfTimeHe: 1.51,
        mValueAN2: 1.2599,
        mValueBN2: 0.5050,
        mValueAHe: 1.7424,
        mValueBHe: 0.4245,
        currentPN2: pN2,
        currentPHe: pHe,
      );

  DecoStatus statusWith(
    TissueCompartment comp, {
    double? inspiredN2,
    double? inspiredHe,
    double surfacePressure = 1.0,
  }) => DecoStatus(
    compartments: [comp],
    ndlSeconds: 0,
    ceilingMeters: 0,
    ttsSeconds: 0,
    gfLow: 0.3,
    gfHigh: 0.7,
    decoStops: const [],
    currentDepthMeters: 0,
    ambientPressureBar: surfacePressure,
    surfacePressureBar: surfacePressure,
    inspiredN2Bar: inspiredN2,
    inspiredHeBar: inspiredHe,
  );

  group('DecoStatus per-gas exchange', () {
    test(
      'after trimix at the surface, helium leaves while nitrogen enters',
      () {
        final comp = comp1(pN2: 0.40, pHe: 0.30);
        final status = statusWith(comp, inspiredN2: 0.74, inspiredHe: 0.0);

        expect(status.n2Exchange(comp), GasExchange.ongassing);
        expect(status.heExchange(comp), GasExchange.offgassing);
      },
    );

    test('a gas within the tolerance of the inspired pressure is in '
        'equilibrium', () {
      final comp = comp1(pN2: 0.7420);
      final status = statusWith(comp, inspiredN2: 0.7407, inspiredHe: 0.0);

      expect(status.n2Exchange(comp), GasExchange.equilibrium);
      expect(status.heExchange(comp), GasExchange.equilibrium);
      expect(status.netExchange(comp), GasExchange.equilibrium);
    });

    test('the net direction follows isOffgassing once a gas is moving', () {
      final comp = comp1(pN2: 1.6);
      final status = statusWith(comp, inspiredN2: 0.74, inspiredHe: 0.0);

      expect(status.netExchange(comp), GasExchange.offgassing);
      expect(status.isOffgassing(comp), isTrue);
    });

    test('the net direction is the only moving gas when the other is in '
        'equilibrium', () {
      // N2 0.012 bar below the inspired pressure (moving in), He 0.005 bar
      // above it (inside the tolerance). The combined Haldane rate is
      // negative here (0.012 / 4 < 0.005 / 1.51), but the He arrow reads
      // Equilibrium, so the badge must follow the N2 arrow, not the sign.
      final comp = comp1(pN2: 0.74 - 0.012, pHe: 0.005);
      final status = statusWith(comp, inspiredN2: 0.74, inspiredHe: 0.0);

      expect(status.n2Exchange(comp), GasExchange.ongassing);
      expect(status.heExchange(comp), GasExchange.equilibrium);
      expect(status.isOffgassing(comp), isTrue);
      expect(status.netExchange(comp), GasExchange.ongassing);
    });

    test('gases moving apart take the sign of the combined rate', () {
      final comp = comp1(pN2: 0.40, pHe: 0.30);
      final status = statusWith(comp, inspiredN2: 0.74, inspiredHe: 0.0);

      // (0.74 - 0.40) / 4 - 0.30 / 1.51 < 0: helium leaves faster.
      expect(status.netExchange(comp), GasExchange.offgassing);
    });

    test('gasExchanges returns each direction and the net one together', () {
      final comp = comp1(pN2: 0.40, pHe: 0.30);
      final status = statusWith(comp, inspiredN2: 0.74, inspiredHe: 0.0);

      final exchanges = status.gasExchanges(comp);
      expect(exchanges.n2, status.n2Exchange(comp));
      expect(exchanges.he, status.heExchange(comp));
      expect(exchanges.net, status.netExchange(comp));
    });

    test('every direction is unknown without an inspired gas', () {
      final comp = comp1(pN2: 1.6, pHe: 0.2);
      final status = statusWith(comp);

      expect(status.n2Exchange(comp), isNull);
      expect(status.heExchange(comp), isNull);
      expect(status.netExchange(comp), isNull);
    });
  });

  group('surface equilibrium loading', () {
    test('the inspired N2 at the status surface pressure', () {
      final status = statusWith(comp1(), surfacePressure: 0.8);

      expect(
        status.surfaceEquilibriumN2Bar,
        closeTo((0.8 - waterVaporPressure) * airN2Fraction, 1e-12),
      );
    });

    test('compartment 1 at sea level settles at about 23% loading', () {
      final comp = comp1();
      final status = statusWith(comp);

      expect(
        comp.equilibriumLoadingPercent(status.surfaceEquilibriumN2Bar),
        closeTo(22.86, 0.01),
      );
    });

    test('matches percentLoading of a compartment that has fully '
        'equilibrated', () {
      const eqN2 = (1.0 - waterVaporPressure) * airN2Fraction;
      final comp = comp1(pN2: eqN2);

      expect(
        comp.equilibriumLoadingPercent(eqN2),
        closeTo(comp.percentLoading, 1e-9),
      );
    });

    test('ignores the helium the compartment still holds', () {
      const eqN2 = (1.0 - waterVaporPressure) * airN2Fraction;

      expect(
        comp1(pN2: 0.4, pHe: 0.5).equilibriumLoadingPercent(eqN2),
        closeTo(comp1(pN2: eqN2).percentLoading, 1e-9),
      );
    });
  });
}
