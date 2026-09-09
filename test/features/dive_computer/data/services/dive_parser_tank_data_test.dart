import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/dive_parser.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

void main() {
  test('tankDataFrom copies every DownloadedTank field', () {
    const tank = DownloadedTank(
      index: 1,
      o2Percent: 32,
      hePercent: 0,
      startPressure: 200,
      endPressure: 50,
      volumeLiters: 11.1,
      role: 'deco',
      transmitterSerial: '180777',
    );

    final data = DiveParser.tankDataFrom(tank);

    expect(data.index, 1);
    expect(data.o2Percent, 32);
    expect(data.startPressure, 200);
    expect(data.endPressure, 50);
    expect(data.volumeLiters, 11.1);
    expect(data.role, 'deco');
    expect(data.transmitterSerial, '180777');
    expect(data.equipmentId, isNull);
    expect(data.tankName, isNull);
  });

  test('copyWith replaces only the given fields', () {
    final data = DiveParser.tankDataFrom(
      const DownloadedTank(index: 0, o2Percent: 21),
    );

    final changed = data.copyWith(equipmentId: 'g1', tankName: 'O2');

    expect(changed.equipmentId, 'g1');
    expect(changed.tankName, 'O2');
    expect(changed.index, 0);
    expect(changed.o2Percent, 21);
  });
}
