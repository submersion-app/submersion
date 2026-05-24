import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

void main() {
  test('DiveDataSource carries GPS and copyWith preserves it', () {
    final s = DiveDataSource(
      id: 's1',
      diveId: 'd1',
      isPrimary: true,
      entryLatitude: 12.34567,
      entryLongitude: 98.76543,
      importedAt: DateTime(2026),
      createdAt: DateTime(2026),
    );
    expect(s.entryLatitude, 12.34567);
    expect(s.copyWith(maxDepth: 30).entryLongitude, 98.76543);
  });
}
