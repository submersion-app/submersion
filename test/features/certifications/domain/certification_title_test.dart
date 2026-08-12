import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

Certification cert({
  required String name,
  CertificationAgency agency = CertificationAgency.padi,
  CertificationLevel? level = CertificationLevel.openWater,
}) {
  final now = DateTime(2026);
  return Certification(
    id: 'c1',
    name: name,
    agency: agency,
    level: level,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('derivedCertificationTitle', () {
    test('is the certification alone, with no agency prefix', () {
      expect(
        derivedCertificationTitle(
          CertificationAgency.padi,
          CertificationLevel.openWater,
        ),
        'Open Water',
      );
    });

    test('falls back to the agency when level is null', () {
      expect(derivedCertificationTitle(CertificationAgency.ssi, null), 'SSI');
    });
  });

  group('hasDerivedName', () {
    test('recognises the legacy spaced-colon format', () {
      expect(hasDerivedName(cert(name: 'PADI : Open Water')), isTrue);
    });

    test('recognises the tight-colon format', () {
      expect(hasDerivedName(cert(name: 'PADI: Open Water')), isTrue);
    });

    test('recognises the new space-joined format', () {
      expect(hasDerivedName(cert(name: 'PADI Open Water')), isTrue);
    });

    test('recognises the bare level name', () {
      expect(hasDerivedName(cert(name: 'Open Water')), isTrue);
    });

    test('recognises the bare agency name', () {
      expect(hasDerivedName(cert(name: 'PADI')), isTrue);
    });

    test('ignores case and collapses whitespace', () {
      expect(hasDerivedName(cert(name: '  padi   :   OPEN WATER ')), isTrue);
    });

    test('treats an empty name as derived', () {
      expect(hasDerivedName(cert(name: '')), isTrue);
      expect(hasDerivedName(cert(name: '   ')), isTrue);
    });

    test('keeps a genuinely custom name', () {
      expect(hasDerivedName(cert(name: 'Bali OW w/ Made')), isFalse);
    });

    test('does not match another agency derivation', () {
      expect(hasDerivedName(cert(name: 'SSI Open Water')), isFalse);
    });

    test('with a null level, only the agency name is derived', () {
      expect(hasDerivedName(cert(name: 'PADI', level: null)), isTrue);
      expect(hasDerivedName(cert(name: 'Open Water', level: null)), isFalse);
    });
  });

  group('customNameOrNull', () {
    test('is null for a derived name', () {
      expect(customNameOrNull(cert(name: 'PADI : Open Water')), isNull);
    });

    test('is the trimmed custom name otherwise', () {
      expect(customNameOrNull(cert(name: '  Bali OW  ')), 'Bali OW');
    });
  });

  group('certificationTitle', () {
    test('derives when the stored name adds nothing', () {
      expect(certificationTitle(cert(name: 'PADI : Open Water')), 'Open Water');
    });

    test('prefers a custom name', () {
      expect(
        certificationTitle(cert(name: 'Bali OW w/ Made')),
        'Bali OW w/ Made',
      );
    });

    test('is never empty', () {
      expect(certificationTitle(cert(name: '', level: null)), isNotEmpty);
    });
  });

  group('certificationSubtitle', () {
    test('is null when the title already contains the level', () {
      expect(certificationSubtitle(cert(name: 'PADI : Open Water')), isNull);
    });

    test('is the level when the title is a custom name', () {
      expect(
        certificationSubtitle(cert(name: 'Bali OW w/ Made')),
        'Open Water',
      );
    });

    test('is null when a custom name has no level', () {
      expect(certificationSubtitle(cert(name: 'Bali OW', level: null)), isNull);
    });
  });

  group('custom agency/level (free-text "Other")', () {
    Certification customCert({
      String name = '',
      String? agencyCustom,
      String? levelCustom,
    }) {
      final now = DateTime(2026);
      return Certification(
        id: 'c1',
        name: name,
        agency: CertificationAgency.other,
        agencyCustom: agencyCustom,
        level: CertificationLevel.other,
        levelCustom: levelCustom,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('effectiveAgencyLabel uses the custom text for Other', () {
      expect(effectiveAgencyLabel(CertificationAgency.other, 'TSA'), 'TSA');
    });

    test('effectiveAgencyLabel falls back to display name without custom', () {
      expect(effectiveAgencyLabel(CertificationAgency.other, null), 'Other');
      expect(effectiveAgencyLabel(CertificationAgency.other, '  '), 'Other');
    });

    test('effectiveLevelLabel uses the custom text for Other', () {
      expect(
        effectiveLevelLabel(CertificationLevel.other, 'Full Cave'),
        'Full Cave',
      );
    });

    test('a known agency ignores any stray custom text', () {
      expect(effectiveAgencyLabel(CertificationAgency.padi, 'TSA'), 'PADI');
    });

    test('derived title is the custom level', () {
      expect(
        derivedCertificationTitle(
          CertificationAgency.other,
          CertificationLevel.other,
          agencyCustom: 'TSA',
          levelCustom: 'Full Cave',
        ),
        'Full Cave',
      );
    });

    test('title of a custom cert uses the custom level', () {
      expect(
        certificationTitle(
          customCert(agencyCustom: 'TSA', levelCustom: 'Full Cave'),
        ),
        'Full Cave',
      );
    });

    test('a name that just repeats the custom label is treated as derived', () {
      final c = customCert(
        name: 'Full Cave',
        agencyCustom: 'TSA',
        levelCustom: 'Full Cave',
      );
      expect(hasDerivedName(c), isTrue);
      expect(customNameOrNull(c), isNull);
    });

    test('a genuinely custom name is kept', () {
      final c = customCert(
        name: 'Full Cave (Mexico)',
        agencyCustom: 'TSA',
        levelCustom: 'Full Cave',
      );
      expect(hasDerivedName(c), isFalse);
      expect(certificationTitle(c), 'Full Cave (Mexico)');
    });
  });
}
