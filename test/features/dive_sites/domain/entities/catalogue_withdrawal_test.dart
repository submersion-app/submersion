import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_row_mapper.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_withdrawal.dart';

void main() {
  group('catalogueWithdrawalFromJson', () {
    test('reads a full entry', () {
      expect(
        catalogueWithdrawalFromJson('research_my_x', {
          'reason': 'duplicate',
          'date': '2026-12-01',
          'replaced_by': 'osm_node_1',
        }),
        const CatalogueWithdrawal(
          id: 'research_my_x',
          reason: CatalogueWithdrawalReason.duplicate,
          date: '2026-12-01',
          replacedBy: 'osm_node_1',
        ),
      );
    });

    test('a reason this build does not know reads as other', () {
      final read = catalogueWithdrawalFromJson('x', {
        'reason': 'tidal',
        'date': '2026-12-01',
      });
      expect(read?.reason, CatalogueWithdrawalReason.other);
      expect(read?.replacedBy, isNull);
    });

    test('an entry that is not an object, or has no date, is not read', () {
      expect(catalogueWithdrawalFromJson('x', 'position'), isNull);
      expect(catalogueWithdrawalFromJson('x', {'reason': 'position'}), isNull);
      expect(
        catalogueWithdrawalFromJson('x', {'reason': 'position', 'date': ''}),
        isNull,
      );
    });

    test('an empty replacement is none', () {
      final read = catalogueWithdrawalFromJson('x', {
        'reason': 'position',
        'date': '2026-12-01',
        'replaced_by': '',
      });
      expect(read?.replacedBy, isNull);
    });
  });

  test('every reason survives the stored form', () {
    for (final reason in CatalogueWithdrawalReason.values) {
      expect(
        catalogueWithdrawalReasonFromName(
          catalogueWithdrawalReasonName(reason),
        ),
        reason,
      );
    }
  });

  group('stored withdrawals', () {
    test('round-trip', () {
      const withdrawn = [
        CatalogueWithdrawal(
          id: 'a',
          reason: CatalogueWithdrawalReason.position,
          date: '2026-12-01',
          replacedBy: 'b',
        ),
        CatalogueWithdrawal(
          id: 'c',
          reason: CatalogueWithdrawalReason.notASite,
          date: '2026-12-02',
        ),
      ];
      expect(
        decodeCatalogueWithdrawals(encodeCatalogueWithdrawals(withdrawn)),
        withdrawn,
      );
    });

    test('anything unreadable is none', () {
      expect(decodeCatalogueWithdrawals(null), isEmpty);
      expect(decodeCatalogueWithdrawals('not json'), isEmpty);
      expect(decodeCatalogueWithdrawals('{"a": 1}'), isEmpty);
      expect(decodeCatalogueWithdrawals('[{"reason": "position"}]'), isEmpty);
    });
  });
}
