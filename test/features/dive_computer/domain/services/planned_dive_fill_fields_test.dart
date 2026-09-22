import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/domain/services/planned_dive_fill_fields.dart';

/// Every Dive constructor parameter must be classified as measured (the
/// computer wins on a fill) or human (the plan keeps it), so a new column
/// cannot be silently overwritten or silently kept.
void main() {
  test('every Dive field is classified exactly once', () {
    final source = File(
      'lib/features/dive_log/domain/entities/dive.dart',
    ).readAsStringSync();
    final start = source.indexOf('  const Dive({');
    final end = source.indexOf('\n  });', start);
    final ctor = source.substring(start, end);
    final params = RegExp(
      r'this\.(\w+)',
    ).allMatches(ctor).map((m) => m.group(1)!).toSet();
    expect(params.length, greaterThan(60));

    final classified = kMeasuredDiveFields.union(kHumanDiveFields);
    expect(kMeasuredDiveFields.intersection(kHumanDiveFields), isEmpty);
    expect(
      params.difference(classified),
      isEmpty,
      reason: 'unclassified Dive fields',
    );
    expect(
      classified.difference(params),
      isEmpty,
      reason: 'classified names that are not Dive fields',
    );
  });
}
