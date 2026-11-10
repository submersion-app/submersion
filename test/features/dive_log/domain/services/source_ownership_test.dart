import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/services/source_ownership.dart';

void main() {
  final importedAt = DateTime.utc(2026, 1, 15);

  DiveDataSourcesData row(
    String id, {
    bool isPrimary = false,
    String? computerId,
    int? mergeSourceSlot,
  }) => DiveDataSourcesData(
    id: id,
    diveId: 'dive-1',
    computerId: computerId,
    isPrimary: isPrimary,
    importedAt: importedAt,
    createdAt: importedAt,
    mergeSourceSlot: mergeSourceSlot,
  );

  group('sourceOwnsProfileStrand', () {
    test('a sole source on a dive with a primary owns its strand', () {
      final primary = row('a', isPrimary: true, computerId: 'comp-a');
      expect(sourceOwnsProfileStrand(primary, [primary]), isTrue);
    });

    test(
      'a dive with no primary row is a combine, so nobody owns a strand',
      () {
        final a = row('a', computerId: 'comp-a');
        expect(sourceOwnsProfileStrand(a, [a]), isFalse);
      },
    );

    test('a row a combine carried does not own its strand even once the dive '
        'has a primary again (issue #4367)', () {
      final primary = row('uddf', isPrimary: true);
      final carried = row('b', computerId: 'comp-b', mergeSourceSlot: 1);
      expect(sourceOwnsProfileStrand(carried, [primary, carried]), isFalse);
    });
  });
}
