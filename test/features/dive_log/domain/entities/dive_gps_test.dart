import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  test('Dive carries entry/exit GeoPoints and copyWith preserves them', () {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026, 5, 22, 9, 14),
      entryLocation: const GeoPoint(12.34567, 98.76543),
      exitLocation: const GeoPoint(12.34612, 98.76489),
    );
    expect(dive.entryLocation, const GeoPoint(12.34567, 98.76543));
    expect(dive.exitLocation, const GeoPoint(12.34612, 98.76489));

    final copy = dive.copyWith(maxDepth: 30);
    expect(copy.entryLocation, const GeoPoint(12.34567, 98.76543));
    expect(copy.exitLocation, const GeoPoint(12.34612, 98.76489));
  });
}
