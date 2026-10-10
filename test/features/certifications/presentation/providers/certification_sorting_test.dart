import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

void main() {
  Certification cert(String id, {String name = '', String? level}) =>
      Certification(
        id: id,
        name: name,
        agency: CertificationAgency.padi.name,
        level: level,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

  List<String> titleOrder(List<Certification> certs, SortDirection direction) =>
      applyCertificationSorting(
        certs,
        SortState(field: CertificationSortField.name, direction: direction),
      ).map((c) => c.id).toList();

  // The list shows certificationTitle (the custom name, else the
  // certification), so the title sort must order by that, not by the raw
  // stored name, which is blank for certifications saved without one and
  // "PADI : ..." for legacy rows (#3195).
  group('title sort', () {
    final certs = [
      cert('rescue', level: CertificationLevel.rescue.name),
      cert('custom', name: 'Bali OW w/ Made'),
      cert(
        'legacy',
        name: 'PADI : Advanced Open Water',
        level: CertificationLevel.advancedOpenWater.name,
      ),
      cert('ow', level: CertificationLevel.openWater.name),
    ];

    test('orders by the displayed title, A to Z', () {
      expect(titleOrder(certs, SortDirection.descending), [
        'legacy', // Advanced Open Water
        'custom', // Bali OW w/ Made
        'ow', // Open Water
        'rescue', // Rescue Diver
      ]);
    });

    test('reverses for the other direction', () {
      expect(titleOrder(certs, SortDirection.ascending), [
        'rescue',
        'ow',
        'custom',
        'legacy',
      ]);
    });
  });
}
