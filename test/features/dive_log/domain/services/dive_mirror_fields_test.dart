import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_mirror_fields.dart';

/// Every Dive constructor parameter must be classified as mirrored or not,
/// so a new column cannot silently leak into (or vanish from) a sibling.
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

    final classified = kMirroredDiveFields.union(kUnmirroredDiveFields);
    expect(kMirroredDiveFields.intersection(kUnmirroredDiveFields), isEmpty);
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

  test('mirroredDiveFrom copies shared facts and drops private ones', () {
    final source = Dive(
      id: 'src',
      diverId: 'eric',
      diveNumber: 12,
      name: 'my name',
      dateTime: DateTime(2026, 6, 1, 9),
      entryTime: DateTime(2026, 6, 1, 9, 2),
      exitTime: DateTime(2026, 6, 1, 9, 50),
      waterTemp: 18,
      airTemp: 25,
      maxDepth: 30,
      notes: 'private',
      rating: 5,
      isFavorite: true,
    );
    final mirrored = mirroredDiveFrom(
      source,
      targetDiverId: 'chris',
      outingId: 'o',
      includeSite: true,
      tripId: null,
      includeDiveCenter: false,
      diveTypeIds: const ['wreck'],
      tags: const [],
      diverRoleId: 'buddy',
    );
    expect(mirrored.id, '');
    expect(mirrored.diverId, 'chris');
    expect(mirrored.outingId, 'o');
    expect(mirrored.isPlanned, isTrue);
    expect(mirrored.diveNumber, isNull);
    expect(mirrored.entryTime, DateTime(2026, 6, 1, 9, 2));
    expect(mirrored.waterTemp, 18);
    expect(mirrored.airTemp, 25);
    expect(mirrored.diveTypeIds, ['wreck']);
    expect(mirrored.diverRoleId, 'buddy');
    expect(mirrored.name, isNull);
    expect(mirrored.maxDepth, isNull);
    expect(mirrored.notes, '');
    expect(mirrored.rating, isNull);
    expect(mirrored.isFavorite, isFalse);
  });
}
