import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const metric = UnitFormatter(AppSettings());

  SacRateDisplay display({
    GasConsumptionLane lane = GasConsumptionLane.rmv,
    double factor = 1.0,
    double? Function(String?)? volumeFor,
    UnitFormatter? units,
  }) => SacRateDisplay(
    units: units ?? metric,
    lane: lane,
    normalizationFactor: factor,
    volumeFor: volumeFor ?? (_) => 12.0,
  );

  group('format', () {
    test('converts with the volume in the RMV lane', () {
      expect(display().format(1.5), '18.0 L/min');
    });

    test('applies the normalization factor', () {
      expect(display(factor: 2.0).format(0.5), '12.0 L/min');
    });

    test('uses the volume of the segment\'s own cylinder', () {
      final rates = display(volumeFor: (id) => id == 'stage' ? 7.0 : 11.0);

      expect(rates.format(1.0, tankId: 'stage'), '7.0 L/min');
      expect(rates.format(1.0, tankId: 'back'), '11.0 L/min');
    });

    test('stays in pressure units when the cylinder has no volume', () {
      expect(display(volumeFor: (_) => null).format(1.5), '1.5 bar/min');
    });

    test('stays in pressure units in the SAC lane', () {
      expect(display(lane: GasConsumptionLane.sac).format(1.5), '1.5 bar/min');
    });

    test('follows the diver\'s pressure and volume units', () {
      const imperial = UnitFormatter(
        AppSettings(
          pressureUnit: PressureUnit.psi,
          volumeUnit: VolumeUnit.cubicFeet,
        ),
      );

      expect(
        display(lane: GasConsumptionLane.sac, units: imperial).format(1.0),
        '15 psi/min',
      );
      expect(display(units: imperial).format(1.0), '0.42 cuft/min');
    });
  });

  group('unit', () {
    test('names the volume unit when any entry converts', () {
      final rates = display(volumeFor: (id) => id == 'back' ? 12.0 : null);

      expect(rates.unit(const ['back', 'stage']), 'L/min');
    });

    test('names the pressure unit when no entry converts', () {
      final rates = display(volumeFor: (_) => null);

      expect(rates.unit(const ['back']), 'bar/min');
    });
  });

  group('comparable', () {
    test('is the displayed value when every entry converts', () {
      final rates = display(volumeFor: (id) => id == 'stage' ? 7.0 : 11.0);
      const ids = ['stage', 'back'];

      // Same bar/min, different cylinders: the row with the larger cylinder
      // breathed more gas, and its bar has to say so.
      expect(rates.comparable(1.0, tankId: 'stage', among: ids), 7.0);
      expect(rates.comparable(1.0, tankId: 'back', among: ids), 11.0);
    });

    test('falls back to bar/min for all when one entry cannot convert', () {
      final rates = display(volumeFor: (id) => id == 'back' ? 12.0 : null);
      const ids = ['back', 'stage'];

      expect(rates.comparable(1.0, tankId: 'back', among: ids), 1.0);
      expect(rates.comparable(1.0, tankId: 'stage', among: ids), 1.0);
    });

    test('applies the normalization factor', () {
      final rates = display(factor: 2.0, lane: GasConsumptionLane.sac);

      expect(rates.comparable(1.0, among: const [null]), 2.0);
    });
  });

  group('averages', () {
    SacSegment segment(int seconds, double sacRate, {String? tankId}) =>
        SacSegment(
          startTimestamp: 0,
          endTimestamp: seconds,
          avgDepth: 10,
          minDepth: 0,
          maxDepth: 20,
          sacRate: sacRate,
          gasConsumed: 1,
          tankId: tankId,
        );

    group('cell', () {
      test('drops the unit when it matches the heading', () {
        expect(
          display().cell([segment(60, 1.5)], headingUnit: 'L/min'),
          '18.0',
        );
      });

      test('keeps the unit on an entry that reads differently', () {
        final rates = display(volumeFor: (id) => id == 'back' ? 12.0 : null);

        expect(
          rates.cell([segment(60, 1.5, tankId: 'stage')], headingUnit: 'L/min'),
          '1.5 bar/min',
        );
      });

      test('converts each stretch with its own cylinder', () {
        final rates = display(volumeFor: (id) => id == 'twin' ? 24.0 : 7.0);

        expect(
          rates.cell([
            segment(360, 1.0, tankId: 'twin'),
            segment(240, 1.0, tankId: 'stage'),
          ], headingUnit: 'L/min'),
          '17.2',
        );
      });
    });

    test('puts a group on the scale of every entry in [among]', () {
      final rates = display(volumeFor: (id) => id == 'back' ? 12.0 : null);

      expect(
        rates.averageRate(
          [segment(60, 1.5, tankId: 'back')],
          among: const ['back', 'stage'],
        ),
        closeTo(1.5, 1e-9),
      );
    });

    test('weights each segment by its duration', () {
      final rates = display();

      expect(
        rates.averageRate([segment(60, 2.0), segment(180, 1.0)]),
        closeTo(15.0, 1e-9),
      );
    });

    test('averages what each segment displays across cylinders', () {
      final rates = display(volumeFor: (id) => id == 'a' ? 10.0 : 20.0);

      expect(
        rates.formatAverage([
          segment(60, 1.0, tankId: 'a'),
          segment(60, 1.0, tankId: 'b'),
        ]),
        '15.0 L/min',
      );
    });

    test('reads in pressure units when a segment cannot convert', () {
      final rates = display(volumeFor: (id) => id == 'a' ? 10.0 : null);

      expect(
        rates.formatAverage([
          segment(60, 1.0, tankId: 'a'),
          segment(60, 2.0, tankId: 'b'),
        ]),
        '1.5 bar/min',
      );
    });

    test('is zero with no time to weight by', () {
      expect(display().averageRate([segment(0, 2.0)]), 0.0);
    });
  });

  group('formatComparable', () {
    test('reads in volume units when every entry converts', () {
      expect(
        display().formatComparable(18.0, among: const [null]),
        '18.0 L/min',
      );
    });

    test('reads in pressure units when one entry cannot convert', () {
      final rates = display(volumeFor: (id) => id == 'back' ? 12.0 : null);

      expect(
        rates.formatComparable(1.5, among: const ['back', 'stage']),
        '1.5 bar/min',
      );
    });
  });

  group('displayComparable', () {
    test('reads a volume rate in the diver\'s volume unit', () {
      const imperial = UnitFormatter(
        AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      );

      expect(
        display(units: imperial).displayComparable(28.3168, among: const ['a']),
        closeTo(1.0, 0.001),
      );
    });

    test('reads a pressure rate in the diver\'s pressure unit', () {
      const imperial = UnitFormatter(
        AppSettings(pressureUnit: PressureUnit.psi),
      );
      final rates = display(units: imperial, lane: GasConsumptionLane.sac);

      expect(
        rates.displayComparable(1.0, among: const ['a']),
        closeTo(14.5, 0.01),
      );
    });

    test('stays in pressure units when one entry cannot convert', () {
      final rates = display(volumeFor: (id) => id == 'back' ? 12.0 : null);

      expect(rates.displayComparable(1.5, among: const ['back', 'stage']), 1.5);
    });
  });

  group('comparableUnit', () {
    test('matches what formatComparable writes', () {
      final rates = display(volumeFor: (id) => id == 'back' ? 12.0 : null);

      expect(rates.comparableUnit(const ['back']), 'L/min');
      expect(rates.comparableUnit(const ['back', 'stage']), 'bar/min');
    });
  });

  group('gas used', () {
    SacSegment used(double bar, {String? tankId}) => SacSegment(
      startTimestamp: 0,
      endTimestamp: 60,
      avgDepth: 10,
      minDepth: 0,
      maxDepth: 20,
      sacRate: 1.0,
      gasConsumed: bar,
      tankId: tankId,
    );

    test('reads in volume in the RMV lane, each on its own cylinder', () {
      final rates = display(volumeFor: (id) => id == 'stage' ? 7.0 : 12.0);
      final segments = [used(10, tankId: 'back'), used(20, tankId: 'stage')];

      expect(rates.gasUsed(segments), 260);
      expect(rates.formatGasUsed(segments), '260 L');
    });

    test('stays in pressure units in the SAC lane', () {
      final rates = display(lane: GasConsumptionLane.sac);

      expect(rates.formatGasUsed([used(30)]), '30 bar');
    });

    test('adds no bar from cylinders that cannot convert', () {
      final rates = display(volumeFor: (id) => id == 'back' ? 12.0 : null);

      expect(
        rates.formatGasUsed([
          used(100, tankId: 'back'),
          used(20, tankId: 'stage'),
        ]),
        '--',
      );
      // One cylinder's drops still add up.
      expect(
        rates.formatGasUsed([
          used(10, tankId: 'stage'),
          used(5, tankId: 'stage'),
        ]),
        '15 bar',
      );
    });

    test('is not scaled by the normalization factor', () {
      // The rate is aligned with the dive's own SAC; what was used is what
      // the pressure readings say.
      expect(display(factor: 2.0).formatGasUsed([used(10)]), '120 L');
    });

    test('follows the diver\'s volume unit', () {
      const imperial = UnitFormatter(
        AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      );

      expect(display(units: imperial).formatGasUsed([used(100)]), '42 cuft');
    });

    test('shares among entries that all read in volume', () {
      final rates = display(volumeFor: (id) => id == 'stage' ? 7.0 : 12.0);

      expect(rates.canShare(const ['back', 'stage']), isTrue);
    });

    test('shares in pressure only within one cylinder', () {
      final rates = display(lane: GasConsumptionLane.sac);

      expect(rates.canShare(const ['back', 'back']), isTrue);
      expect(rates.canShare(const [null, null]), isTrue);
      // Bar from two cylinders of unknown size can't be added up.
      expect(rates.canShare(const ['back', 'stage']), isFalse);
    });

    test('measures shares on one scale among mixed cylinders', () {
      final rates = display(volumeFor: (id) => id == 'back' ? 12.0 : null);

      // The stage can't convert, so all of them stay in bar.
      expect(
        rates.gasUsed([used(10, tankId: 'back')], among: const ['back']),
        120,
      );
      expect(
        rates.gasUsed(
          [used(10, tankId: 'back')],
          among: const ['back', 'stage'],
        ),
        10,
      );
    });
  });
}
