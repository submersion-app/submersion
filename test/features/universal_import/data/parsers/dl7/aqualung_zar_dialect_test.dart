import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/parsers/dl7/aqualung_zar_dialect.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_units.dart';

// Structure mirrors a real DiverLog+/DiveCloud export (values synthetic).
const _aqualungZar = '''
<AQUALUNG>
<APP>DiverLog+</APP>
<DUID>4321_98765_20240612093000_42</DUID>
<TITLE>Morning Reef Drift</TITLE>
<DIVE_DT>20240612093000</DIVE_DT>
<DIVE_MODE>0</DIVE_MODE>
<PDC_MODEL>I330R</PDC_MODEL>
<PDC_SERIAL>98765</PDC_SERIAL>
<MANUFACTURER>AQUALUNG</MANUFACTURER>
<PDC_FIRMWARE>1.003.000</PDC_FIRMWARE>
<DIVER_NAME>LASTNAME=[Test¶Diver]</DIVER_NAME>
<LOCATION>GPS=[20.877432,-156.679867],LOCNAME=[Molokini Crater],CITY=[Kihei],STATE/PROVINCE=[Hawaii],COUNTRY=[United States],MINTEMP=26.5</LOCATION>
<GEAR>GEAR_UNITS=0</GEAR>
<RATING>4</RATING>
<DIVESTATS>DIVENO=42,DATATYPE=8,DECO=N,VIOL=N,MODE=0,MANUALDIVE=0,EDT=000600,SI=010000,MAXDEPTH=18.2880,MAXO2=1,PO2=0.53,MINTEMP=26.5</DIVESTATS>
<TANK>NUMBER=1,TID=0,ON=N,CYLNAME=[AL80],CYLSIZE=80.0CU FT,WORKINGPRESSURE=3000PSI,STARTPRESSURE=3000,ENDPRESSURE=1800,FO2=32,AVGDEPTH=12.2,DIVETIME=6,SAC=0</TANK>
<DECOTIME>0,0,0,0,2,0,0,0,0,0,0,0</DECOTIME>
</AQUALUNG>''';

void main() {
  group('AqualungZarDialect.parse', () {
    test('returns null for a non-Aqualung ZAR block', () {
      expect(
        AqualungZarDialect.parse(
          'More Mobile Software, DiveLogDT, version 4.144',
        ),
        isNull,
      );
      expect(AqualungZarDialect.parse(''), isNull);
    });

    test('extracts identity, rating, title, and DUID', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.app, 'DiverLog+');
      expect(zar.duid, '4321_98765_20240612093000_42');
      expect(zar.title, 'Morning Reef Drift');
      expect(zar.rating, 4);
      expect(zar.diveMode, 0);
      expect(zar.pdcModel, 'I330R');
      expect(zar.pdcSerial, '98765');
      expect(zar.pdcFirmware, '1.003.000');
    });

    test('extracts location with bracket-aware GPS parsing', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.latitude, closeTo(20.877432, 1e-6));
      expect(zar.longitude, closeTo(-156.679867, 1e-6));
      expect(zar.locationName, 'Molokini Crater');
      expect(zar.city, 'Kihei');
      expect(zar.stateProvince, 'Hawaii');
      expect(zar.country, 'United States');
    });

    test('extracts dive stats with hhmmss durations', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.diveNumber, 42);
      expect(zar.elapsedDiveTime, const Duration(minutes: 6));
      expect(zar.surfaceInterval, const Duration(hours: 1));
      expect(zar.maxDepthMeters, closeTo(18.288, 0.001));
      expect(zar.minTempCelsius, closeTo(26.5, 0.001));
    });

    test('converts TANK pressures from PSI when GEAR_UNITS is imperial', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.tanks, hasLength(1));
      final tank = zar.tanks.first;
      expect(tank.name, 'AL80');
      expect(tank.o2Percent, 32.0);
      expect(tank.startPressureBar, closeTo(206.84, 0.01));
      expect(tank.endPressureBar, closeTo(124.11, 0.01));
      expect(tank.workingPressureBar, closeTo(206.84, 0.01));
      // 80 cu ft free gas at 206.84 bar working pressure ~= 10.95 L water
      // capacity (cuft * 28.3168 / workingPressureBar).
      expect(tank.volumeLiters, closeTo(10.95, 0.01));
    });

    test('treats zero tank pressures and sizes as absent', () {
      final zar = AqualungZarDialect.parse('''
<AQUALUNG>
<TANK>NUMBER=1,TID=0,ON=N,CYLNAME=[],CYLSIZE=0.0CU FT,WORKINGPRESSURE=0PSI,STARTPRESSURE=0,ENDPRESSURE=0,FO2=20,AVGDEPTH=9.1,DIVETIME=57,SAC=0</TANK>
</AQUALUNG>''')!;
      final tank = zar.tanks.first;
      expect(tank.o2Percent, 20.0);
      expect(tank.startPressureBar, isNull);
      expect(tank.endPressureBar, isNull);
      expect(tank.workingPressureBar, isNull);
      expect(tank.volumeLiters, isNull);
    });

    test('parses DECOTIME sample array', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.decoTimePerSample, hasLength(12));
      expect(zar.decoTimePerSample[4], 2);
    });

    test('applies imperial ZRH units to depth and temperature stats', () {
      const imperialUnits = Dl7Units(depthIsFeet: true, tempIsFahrenheit: true);
      final zar = AqualungZarDialect.parse('''
<AQUALUNG>
<DIVESTATS>DIVENO=7,EDT=001000,MAXDEPTH=60.0,MINTEMP=80.0</DIVESTATS>
</AQUALUNG>''', units: imperialUnits)!;
      expect(zar.maxDepthMeters, closeTo(18.288, 0.001));
      expect(zar.minTempCelsius, closeTo(26.667, 0.001));
    });
  });
}
