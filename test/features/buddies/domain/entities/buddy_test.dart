import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

Buddy _buddy({
  CertificationLevel? level,
  CertificationAgency? agency,
  String? title,
}) {
  final now = DateTime(2026, 1, 1);
  return Buddy(
    id: 'b1',
    name: 'Alex',
    certificationLevel: level,
    certificationAgency: agency,
    certificationTitle: title,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Buddy.certificationLine (issue #1303)', () {
    test('no certification -> null', () {
      expect(_buddy().certificationLine, isNull);
    });

    test('agency but no level or title -> the agency name alone', () {
      expect(
        _buddy(agency: CertificationAgency.padi).certificationLine,
        'PADI',
      );
    });

    test('agency Other but no level or title -> null', () {
      expect(
        _buddy(agency: CertificationAgency.other).certificationLine,
        isNull,
      );
    });

    test('agency + level -> "level · agency"', () {
      final b = _buddy(
        level: CertificationLevel.advancedOpenWater,
        agency: CertificationAgency.padi,
        title: 'Advanced Open Water',
      );
      expect(b.certificationLine, 'Advanced Open Water · PADI');
    });

    test('custom name with a real agency keeps the agency', () {
      final b = _buddy(
        level: CertificationLevel.diveMaster,
        agency: CertificationAgency.padi,
        title: 'Bill Ansell',
      );
      expect(b.certificationLine, 'Bill Ansell · PADI');
    });

    test('agency Other with a custom title shows only the title', () {
      final b = _buddy(
        level: CertificationLevel.other,
        agency: CertificationAgency.other,
        title: 'FFESSM Niveau 2',
      );
      expect(b.certificationLine, 'FFESSM Niveau 2');
    });

    test(
      'agency Other, no custom name -> just the derived title, no "· Other"',
      () {
        final b = _buddy(
          level: CertificationLevel.other,
          agency: CertificationAgency.other,
          title: 'Other',
        );
        expect(b.certificationLine, 'Other');
      },
    );

    test('agency already inside the title is not repeated', () {
      final b = _buddy(
        agency: CertificationAgency.padi,
        title: 'PADI Rescue Diver',
      );
      expect(b.certificationLine, 'PADI Rescue Diver');
    });

    test('agency in the title with other casing/spacing is not repeated', () {
      expect(
        _buddy(
          agency: CertificationAgency.padi,
          title: 'Padi Rescue Diver',
        ).certificationLine,
        'Padi Rescue Diver',
      );
      expect(
        _buddy(
          agency: CertificationAgency.padi,
          title: 'PADI - Rescue Diver',
        ).certificationLine,
        'PADI - Rescue Diver',
      );
    });

    test('level only, no agency', () {
      final b = _buddy(
        level: CertificationLevel.openWater,
        title: 'Open Water',
      );
      expect(b.certificationLine, 'Open Water');
    });
  });

  group('Buddy.displayName', () {
    test('prefers the certification title over the bare level', () {
      final b = _buddy(
        level: CertificationLevel.other,
        agency: CertificationAgency.other,
        title: 'FFESSM Niveau 2',
      );
      expect(b.displayName, 'Alex (FFESSM Niveau 2)');
    });

    test('falls back to the level, then to the name alone', () {
      expect(
        _buddy(level: CertificationLevel.rescue).displayName,
        'Alex (Rescue Diver)',
      );
      expect(_buddy().displayName, 'Alex');
    });
  });
}
