import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';

void main() {
  test('a preset tank writes its rated capacity and reads back exactly', () {
    const al80 = TankPresets.al80;
    final cuft = ratedCapacityCuft(al80.volumeLiters, al80.workingPressureBar);
    expect(cuft, al80.ratedCapacityCuft);
    expect(
      volumeLitersFromCapacity(cuft, al80.workingPressureBar),
      al80.volumeLiters,
    );
  });

  test('every rated preset round trips', () {
    for (final p in TankPresets.all) {
      if (p.ratedCapacityCuft == null) continue;
      final cuft = ratedCapacityCuft(p.volumeLiters, p.workingPressureBar);
      final back = volumeLitersFromCapacity(cuft, p.workingPressureBar);
      // Presets indistinguishable by specs share a volume (see matchBySpecs).
      expect(back, closeTo(p.volumeLiters, 1e-9), reason: p.name);
    }
  });

  test('a non-preset tank uses ideal gas both ways', () {
    final cuft = ratedCapacityCuft(13.0, 232);
    expect(cuft, closeTo(13.0 * 232 / 28.3168, 1e-9));
    expect(volumeLitersFromCapacity(cuft, 232), closeTo(13.0, 1e-9));
  });

  test('a blank working pressure assumes 200 bar both ways', () {
    final cuft = ratedCapacityCuft(11.1, null);
    expect(cuft, closeTo(11.1 * 200 / 28.3168, 1e-9));
    expect(volumeLitersFromCapacity(cuft, null), closeTo(11.1, 1e-9));
  });

  test('the value written to one decimal still reads back within 0.01 L', () {
    final written = double.parse(
      ratedCapacityCuft(13.0, 232).toStringAsFixed(1),
    );
    expect(volumeLitersFromCapacity(written, 232), closeTo(13.0, 0.01));
  });

  test('matchByCapacity needs both the rating and the pressure', () {
    expect(TankPresets.matchByCapacity(77.4, 206.843), TankPresets.al80);
    expect(TankPresets.matchByCapacity(77.4, 232), isNull);
    expect(TankPresets.matchByCapacity(78.0, 206.843), isNull);
  });
}
