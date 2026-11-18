import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// Issue #4705: UDDF gives a mix as fractions (`<o2>0.32</o2>`), but some
/// programs write percentages (`<o2>32</o2>`). Every value was multiplied by
/// 100, so EAN32 was stored as 3200% oxygen and air as 2100%.
void main() {
  GasMix parse(String body) => UddfImportParsers.parseGasMix(
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

    test('reads a whole fraction as pure oxygen, not 1%', () {
      expect(parse('<o2>1.0</o2><he>0.0</he>'), const GasMix(o2: 100));
      expect(parse('<o2>1</o2>'), const GasMix(o2: 100));
    });

    test('a non-finite value neither poisons the mix nor sets its unit', () {
      // Infinity is above 1, so taking it at face value would have read the
      // oxygen beside it as 0.32%.
      expect(parse('<o2>0.32</o2><he>Infinity</he>'), const GasMix(o2: 32));
      expect(parse('<o2>NaN</o2><he>0.0</he>'), const GasMix());
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
