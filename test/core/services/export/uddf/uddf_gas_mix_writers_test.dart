import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_gas_mix_writers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// Reading a `<mix>` back. Issue #4705: UDDF gives a mix as fractions
/// (`<o2>0.32</o2>`), but some programs write percentages (`<o2>32</o2>`).
/// Every value was multiplied by 100, so EAN32 was stored as 3200% oxygen and
/// air as 2100%.
void main() {
  GasMix parse(String body) => UddfGasMixWriters.parseGasMix(
    XmlDocument.parse('<mix id="m">$body</mix>').rootElement,
  );

  group('parseGasMix, a mix written in percent', () {
    test('keeps an oxygen percentage as written', () {
      expect(parse('<o2>32</o2><he>0</he>'), const GasMix(o2: 32));
    });

    test('keeps air', () {
      expect(parse('<o2>21</o2><n2>79</n2><he>0</he>'), const GasMix());
    });

    test('keeps a trimix', () {
      expect(parse('<o2>18</o2><he>45</he>'), const GasMix(o2: 18, he: 45));
    });

    test('keeps a fractional percentage', () {
      expect(parse('<o2>32.5</o2>'), const GasMix(o2: 32.5));
    });

    test('keeps pure oxygen', () {
      expect(parse('<o2>100</o2><he>0</he>'), const GasMix(o2: 100));
    });

    test('reads a small helium share in the same unit as the oxygen', () {
      // Read on its own, 1 could be a whole fraction: 100% helium. Beside
      // 30% oxygen it can only be 1%, so the unit is decided per mix.
      expect(parse('<o2>30</o2><he>1</he>'), const GasMix(o2: 30, he: 1));
    });

    test('an unreadable oxygen still falls back to air', () {
      // The fallback is a percentage, so it is not scaled by the unit the
      // helium gives the mix.
      expect(
        parse('<o2>not a number</o2><he>45</he>'),
        const GasMix(o2: 21, he: 45),
      );
    });
  });

  group('parseGasMix, a mix written as fractions', () {
    test('converts the fractions the spec defines', () {
      expect(parse('<o2>0.32</o2><he>0.0</he>'), const GasMix(o2: 32));
    });

    test('restores every tenth of a percent exactly', () {
      // Multiplying the stored fraction by 100 left 93 of these, and 29%,
      // slightly off (0.29 * 100 is 28.999999999999996).
      for (var tenths = 1; tenths <= 1000; tenths++) {
        final percent = tenths / 10;
        final fraction = (percent / 100).toString();

        expect(
          parse('<o2>$fraction</o2><he>0.0</he>').o2,
          percent,
          reason: 'o2 $fraction',
        );
        expect(
          parse('<o2>0.0</o2><he>$fraction</he>').he,
          percent,
          reason: 'he $fraction',
        );
      }
    });

    test('keeps the precision another program wrote', () {
      expect(parse('<o2>0.32125</o2><he>0.0</he>').o2, 32.125);
    });

    test('an unreadable fraction still falls back', () {
      expect(parse('<o2>not a number</o2><he>nor this</he>'), const GasMix());
    });

    test('reads a whole fraction as pure oxygen, not 1%', () {
      expect(parse('<o2>1.0</o2><he>0.0</he>'), const GasMix(o2: 100));
      expect(parse('<o2>1</o2>'), const GasMix(o2: 100));
    });

    test('reads a whole fraction with float noise as pure gas, not 1%', () {
      expect(
        parse('<o2>1.0000000000000002</o2><he>0</he>'),
        const GasMix(o2: 100),
      );
    });

    test('a non-finite value neither poisons the mix nor sets its unit', () {
      // Infinity is above 1, so taking it at face value would have read the
      // oxygen beside it as 0.32%.
      expect(parse('<o2>0.32</o2><he>Infinity</he>'), const GasMix(o2: 32));
      expect(parse('<o2>NaN</o2><he>0.0</he>'), const GasMix());
    });
  });

  group('parseGasMix, a value that is no share of a gas', () {
    test('falls back like an unreadable one', () {
      expect(parse('<o2>320</o2><he>0</he>'), const GasMix());
      expect(parse('<o2>-0.1</o2><he>0.0</he>'), const GasMix());
      expect(parse('<o2>32</o2><he>-5</he>'), const GasMix(o2: 32));
    });

    test('does not decide the unit of the mix', () {
      // 320 is no share of a gas in either unit, so it leaves the helium
      // beside it a fraction rather than turning 0.45 into 0.45%.
      expect(parse('<o2>320</o2><he>0.45</he>'), const GasMix(o2: 21, he: 45));
    });

    test('a mix over 100% in all falls back to air', () {
      expect(parse('<o2>0.8</o2><he>0.5</he>'), const GasMix());
      expect(parse('<o2>80</o2><he>50</he>'), const GasMix());
      // The oxygen fallback counts too: 21% beside 90% helium is no gas.
      expect(parse('<o2>bad</o2><he>0.9</he>'), const GasMix());
    });

    test('a mix of exactly 100% is kept', () {
      expect(parse('<o2>0.29</o2><he>0.71</he>'), const GasMix(o2: 29, he: 71));
    });
  });

  test('an import stores each tank at the percentage written', () async {
    final result = await UddfFullImportService().importAllDataFromUddf(
      _percentLogbook,
    );

    final tanks = result.dives.single['tanks'] as List;
    expect(
      [for (final tank in tanks) tank['gasMix']],
      const [GasMix(o2: 32), GasMix(), GasMix(o2: 18, he: 45)],
    );
  });
}

/// A logbook from a program that writes each mix in percent.
const _percentLogbook = '''<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
<generator>
  <name>Percent Logbook</name>
</generator>
<gasdefinitions>
  <mix id="ean32">
    <name>EAN32</name>
    <o2>32</o2>
    <he>0</he>
  </mix>
  <mix id="air">
    <name>Air</name>
    <o2>21</o2>
    <n2>79</n2>
    <he>0</he>
  </mix>
  <mix id="tx18_45">
    <name>Trimix 18/45</name>
    <o2>18</o2>
    <he>45</he>
  </mix>
</gasdefinitions>
<profiledata>
  <repetitiongroup id="rg1">
    <dive id="dive_1">
      <informationbeforedive>
        <divenumber>1</divenumber>
        <datetime>2025-03-17T10:05:00</datetime>
      </informationbeforedive>
      <tankdata id="tank_1">
        <link ref="ean32"/>
      </tankdata>
      <tankdata id="tank_2">
        <link ref="air"/>
      </tankdata>
      <tankdata id="tank_3">
        <link ref="tx18_45"/>
      </tankdata>
      <informationafterdive>
        <greatestdepth>23.0</greatestdepth>
        <diveduration>3000</diveduration>
      </informationafterdive>
    </dive>
  </repetitiongroup>
</profiledata>
</uddf>
''';
