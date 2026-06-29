import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

void main() {
  test('extractFromDive joins all dive-type names', () {
    final dive = Dive(
      id: 'd',
      dateTime: DateTime(2026, 1, 1),
      diveTypeIds: const ['shore', 'wreck'],
    );
    expect(DiveField.diveTypeName.extractFromDive(dive), 'Shore, Wreck');
  });

  test('extractFromSummary joins all dive-type names', () {
    final summary = DiveSummary(
      id: 'd',
      dateTime: DateTime(2026, 1, 1),
      sortTimestamp: 0,
      diveTypeIds: const ['night', 'deep_wreck'],
    );
    expect(
      DiveField.diveTypeName.extractFromSummary(summary),
      'Night, Deep wreck',
    );
  });
}
