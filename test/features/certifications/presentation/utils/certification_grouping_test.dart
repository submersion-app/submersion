import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 1, 1);

  Certification cert(
    String id, {
    String agency = 'padi',
    String? level,
    DateTime? issueDate,
    DateTime? expiryDate,
  }) => Certification(
    id: id,
    name: id,
    agency: agency,
    level: level,
    issueDate: issueDate,
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
  );

  group('groupCertificationsFor status', () {
    test('groups into Expired, Expiring Soon, Valid in that order', () {
      final expired = cert('e', expiryDate: DateTime(2020, 1, 1));
      final soon = cert(
        'soon',
        expiryDate: DateTime.now().add(const Duration(days: 10)),
      );
      final valid = cert(
        'valid',
        expiryDate: DateTime.now().add(const Duration(days: 400)),
      );

      final groups = groupCertificationsFor(CertificationGroupBy.status, [
        valid,
        soon,
        expired,
      ], l10n: l10n);

      expect(groups.map((g) => g.key), ['expired', 'expiringSoon', 'valid']);
      expect(groups.map((g) => g.certifications.single.id), [
        'e',
        'soon',
        'valid',
      ]);
    });

    test('hides a status group with no certifications in it', () {
      final valid = cert(
        'valid',
        expiryDate: DateTime.now().add(const Duration(days: 400)),
      );

      final groups = groupCertificationsFor(CertificationGroupBy.status, [
        valid,
      ], l10n: l10n);

      expect(groups.map((g) => g.key), ['valid']);
    });

    test('keeps the incoming order of certifications inside a group', () {
      final a = cert('a', issueDate: DateTime(2020));
      final b = cert('b', issueDate: DateTime(2021));

      final groups = groupCertificationsFor(CertificationGroupBy.status, [
        b,
        a,
      ], l10n: l10n);

      expect(groups.single.certifications.map((c) => c.id), ['b', 'a']);
    });
  });

  group('groupCertificationsFor agency', () {
    test(
      'groups by the primary agency only, ignoring additionalCredentials',
      () {
        final padiWithCrossover = Certification(
          id: 'padi-cmas',
          name: 'padi-cmas',
          agency: CertificationAgency.padi.name,
          additionalCredentials: const [
            CertificationCredential(agency: 'cmas'),
          ],
          createdAt: now,
          updatedAt: now,
        );
        final ssi = cert('ssi-only', agency: CertificationAgency.ssi.name);

        final groups = groupCertificationsFor(CertificationGroupBy.agency, [
          padiWithCrossover,
          ssi,
        ], l10n: l10n);

        expect(groups, hasLength(2));
        expect(
          groups
              .firstWhere((g) => g.key == CertificationAgency.padi.name)
              .certifications
              .map((c) => c.id),
          ['padi-cmas'],
        );
        expect(groups.any((g) => g.key == 'cmas'), isFalse);
      },
    );

    test('orders groups alphabetically by localized agency name', () {
      final groups = groupCertificationsFor(CertificationGroupBy.agency, [
        cert('ssi', agency: CertificationAgency.ssi.name),
        cert('padi', agency: CertificationAgency.padi.name),
      ], l10n: l10n);

      expect(
        groups.map((g) => g.label),
        [for (final g in groups) g.label]..sort(),
      );
      expect(groups.first.label.compareTo(groups.last.label), lessThan(0));
    });
  });

  group('groupCertificationsFor agency, professional ratings (#730)', () {
    final padi = CertificationAgency.padi.name;
    final tdi = CertificationAgency.tdi.name;

    test('puts an agency\'s pro ratings in their own group right after it', () {
      final groups = groupCertificationsFor(CertificationGroupBy.agency, [
        cert('tdi-instr', agency: tdi, level: 'tdiInstructor'),
        cert('padi-dm', agency: padi, level: 'diveMaster'),
        cert('padi-ow', agency: padi, level: 'openWater'),
        cert('tdi-deco', agency: tdi, level: 'tdiDecompressionProceduresDiver'),
        cert('padi-instr', agency: padi, level: 'instructor'),
      ], l10n: l10n);

      expect(groups.map((g) => g.key), [
        padi,
        certificationProfessionalGroupKey(padi),
        tdi,
        certificationProfessionalGroupKey(tdi),
      ]);
      expect(groups.map((g) => g.certifications.map((c) => c.id).toList()), [
        ['padi-ow'],
        ['padi-dm', 'padi-instr'],
        ['tdi-deco'],
        ['tdi-instr'],
      ]);
    });

    test('labels a pro group with its agency name', () {
      final groups = groupCertificationsFor(CertificationGroupBy.agency, [
        cert('padi-ow', agency: padi, level: 'openWater'),
        cert('padi-dm', agency: padi, level: 'diveMaster'),
      ], l10n: l10n);

      expect(groups.map((g) => g.label), ['PADI', 'PADI Professional']);
    });

    test('an agency with only pro ratings shows only its pro group', () {
      final groups = groupCertificationsFor(CertificationGroupBy.agency, [
        cert('padi-instr', agency: padi, level: 'instructor'),
      ], l10n: l10n);

      expect(groups.map((g) => g.key), [
        certificationProfessionalGroupKey(padi),
      ]);
    });

    test('custom, unknown and missing levels stay in the agency group', () {
      final groups = groupCertificationsFor(CertificationGroupBy.agency, [
        cert('custom', agency: padi, level: 'custom-level-id'),
        cert('none', agency: padi),
      ], l10n: l10n);

      expect(groups.map((g) => g.key), [padi]);
      expect(groups.single.certifications.map((c) => c.id), ['custom', 'none']);
    });

    test('a pro cross-over credential does not move the card', () {
      final card = Certification(
        id: 'padi-ow-cmas',
        name: 'padi-ow-cmas',
        agency: padi,
        level: 'openWater',
        additionalCredentials: const [
          CertificationCredential(agency: 'cmas', level: 'cmas1StarInstructor'),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final groups = groupCertificationsFor(CertificationGroupBy.agency, [
        card,
      ], l10n: l10n);

      expect(groups.map((g) => g.key), [padi]);
    });

    test('status grouping ignores professional ratings', () {
      final groups = groupCertificationsFor(CertificationGroupBy.status, [
        cert('padi-ow', agency: padi, level: 'openWater'),
        cert('padi-instr', agency: padi, level: 'instructor'),
      ], l10n: l10n);

      expect(groups.map((g) => g.key), ['valid']);
    });

    test('flattening keeps the pro group after its agency', () {
      expect(
        flattenCertificationGroups(CertificationGroupBy.agency, [
          cert('padi-instr', agency: padi, level: 'instructor'),
          cert('padi-ow', agency: padi, level: 'openWater'),
        ], l10n: l10n).map((c) => c.id),
        ['padi-ow', 'padi-instr'],
      );
    });
  });

  group('groupCertificationsFor none', () {
    test('returns no groups at all', () {
      final groups = groupCertificationsFor(CertificationGroupBy.none, [
        cert('a'),
      ], l10n: l10n);

      expect(groups, isEmpty);
    });
  });

  group('flattenCertificationGroups', () {
    test('returns the sorted list unchanged for none', () {
      final certs = [cert('b'), cert('a')];

      expect(
        flattenCertificationGroups(
          CertificationGroupBy.none,
          certs,
          l10n: l10n,
        ).map((c) => c.id),
        ['b', 'a'],
      );
    });

    test('concatenates groups in group order for status', () {
      final expired = cert('e', expiryDate: DateTime(2020, 1, 1));
      final valid = cert(
        'valid',
        expiryDate: DateTime.now().add(const Duration(days: 400)),
      );

      expect(
        flattenCertificationGroups(CertificationGroupBy.status, [
          valid,
          expired,
        ], l10n: l10n).map((c) => c.id),
        ['e', 'valid'],
      );
    });
  });
}
