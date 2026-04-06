import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // A UnitFormatter backed by metric default settings.
  const units = UnitFormatter(AppSettings());

  // A representative Certification entity for adapter tests.
  final testCert = Certification(
    id: 'cert-1',
    name: 'Advanced Open Water',
    agency: CertificationAgency.padi,
    level: CertificationLevel.advancedOpenWater,
    cardNumber: 'AOW-12345',
    issueDate: DateTime(2023, 6, 15),
    expiryDate: DateTime(2026, 6, 15),
    instructorName: 'Jane Smith',
    instructorNumber: 'INST-789',
    notes: 'Completed in Malta',
    createdAt: DateTime(2023, 6, 15),
    updatedAt: DateTime(2023, 6, 15),
  );

  // DateFormat used by the adapter for formatting dates.
  final dateFormat = DateFormat.yMMMd();

  group('CertificationFieldAdapter.allFields', () {
    test('has expected count matching CertificationField.values', () {
      expect(
        CertificationFieldAdapter.instance.allFields.length,
        equals(CertificationField.values.length),
      );
    });

    test('contains all CertificationField values', () {
      expect(
        CertificationFieldAdapter.instance.allFields,
        containsAll(CertificationField.values),
      );
    });
  });

  group('CertificationFieldAdapter.fieldsByCategory', () {
    test('groups core fields together', () {
      final byCategory = CertificationFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['core'],
        containsAll([
          CertificationField.certName,
          CertificationField.agency,
          CertificationField.level,
          CertificationField.cardNumber,
        ]),
      );
    });

    test('groups dates fields together', () {
      final byCategory = CertificationFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['dates'],
        containsAll([
          CertificationField.issueDate,
          CertificationField.expiryDate,
          CertificationField.expiryStatus,
        ]),
      );
    });

    test('groups instructor fields together', () {
      final byCategory = CertificationFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['instructor'],
        containsAll([
          CertificationField.instructorName,
          CertificationField.instructorNumber,
        ]),
      );
    });

    test('groups other fields together', () {
      final byCategory = CertificationFieldAdapter.instance.fieldsByCategory;
      expect(byCategory['other'], containsAll([CertificationField.notes]));
    });

    test('covers all CertificationField values across categories', () {
      final byCategory = CertificationFieldAdapter.instance.fieldsByCategory;
      final allGrouped = byCategory.values.expand((v) => v).toList();
      expect(allGrouped.length, equals(CertificationField.values.length));
    });
  });

  group('CertificationFieldAdapter.extractValue', () {
    final adapter = CertificationFieldAdapter.instance;

    test('returns certification name', () {
      expect(
        adapter.extractValue(CertificationField.certName, testCert),
        equals('Advanced Open Water'),
      );
    });

    test('returns agency', () {
      expect(
        adapter.extractValue(CertificationField.agency, testCert),
        equals(CertificationAgency.padi),
      );
    });

    test('returns level', () {
      expect(
        adapter.extractValue(CertificationField.level, testCert),
        equals(CertificationLevel.advancedOpenWater),
      );
    });

    test('returns card number', () {
      expect(
        adapter.extractValue(CertificationField.cardNumber, testCert),
        equals('AOW-12345'),
      );
    });

    test('returns issue date', () {
      expect(
        adapter.extractValue(CertificationField.issueDate, testCert),
        equals(DateTime(2023, 6, 15)),
      );
    });

    test('returns expiry date', () {
      expect(
        adapter.extractValue(CertificationField.expiryDate, testCert),
        equals(DateTime(2026, 6, 15)),
      );
    });

    test('returns instructor name', () {
      expect(
        adapter.extractValue(CertificationField.instructorName, testCert),
        equals('Jane Smith'),
      );
    });

    test('returns instructor number', () {
      expect(
        adapter.extractValue(CertificationField.instructorNumber, testCert),
        equals('INST-789'),
      );
    });

    test('returns expiry status as computed string', () {
      // The expiryStatus is a computed property on the Certification entity.
      final status = adapter.extractValue(
        CertificationField.expiryStatus,
        testCert,
      );
      expect(status, isA<String>());
      // The testCert has expiryDate 2026-06-15; the exact status depends on
      // the current date but it should be a non-null string.
      expect(status, isNotNull);
    });

    test('returns notes when non-empty', () {
      expect(
        adapter.extractValue(CertificationField.notes, testCert),
        equals('Completed in Malta'),
      );
    });

    test('returns null for level when not set', () {
      final noLevelCert = Certification(
        id: 'cert-no-level',
        name: 'Basic',
        agency: CertificationAgency.ssi,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(
        adapter.extractValue(CertificationField.level, noLevelCert),
        isNull,
      );
    });

    test('returns null for card number when not set', () {
      final noCardCert = Certification(
        id: 'cert-no-card',
        name: 'Basic',
        agency: CertificationAgency.ssi,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(
        adapter.extractValue(CertificationField.cardNumber, noCardCert),
        isNull,
      );
    });

    test('returns null for issue date when not set', () {
      final noDateCert = Certification(
        id: 'cert-no-date',
        name: 'Basic',
        agency: CertificationAgency.ssi,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(
        adapter.extractValue(CertificationField.issueDate, noDateCert),
        isNull,
      );
    });

    test('returns null for expiry date when not set', () {
      final noExpiryCert = Certification(
        id: 'cert-no-expiry',
        name: 'Basic',
        agency: CertificationAgency.ssi,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(
        adapter.extractValue(CertificationField.expiryDate, noExpiryCert),
        isNull,
      );
    });

    test('returns null for instructor name when not set', () {
      final noInstructorCert = Certification(
        id: 'cert-no-inst',
        name: 'Basic',
        agency: CertificationAgency.ssi,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(
        adapter.extractValue(
          CertificationField.instructorName,
          noInstructorCert,
        ),
        isNull,
      );
    });

    test('returns null for instructor number when not set', () {
      final noInstNumCert = Certification(
        id: 'cert-no-instnum',
        name: 'Basic',
        agency: CertificationAgency.ssi,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(
        adapter.extractValue(
          CertificationField.instructorNumber,
          noInstNumCert,
        ),
        isNull,
      );
    });

    test('returns "No expiry" status when no expiry date set', () {
      final noExpiryCert = Certification(
        id: 'cert-no-expiry',
        name: 'Basic',
        agency: CertificationAgency.ssi,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(
        adapter.extractValue(CertificationField.expiryStatus, noExpiryCert),
        equals('No expiry'),
      );
    });

    test('returns "Expired" status when expiry date is in the past', () {
      final expiredCert = Certification(
        id: 'cert-expired',
        name: 'Expired Cert',
        agency: CertificationAgency.padi,
        expiryDate: DateTime(2020, 1, 1),
        createdAt: DateTime(2019, 1, 1),
        updatedAt: DateTime(2019, 1, 1),
      );
      expect(
        adapter.extractValue(CertificationField.expiryStatus, expiredCert),
        equals('Expired'),
      );
    });

    test('returns empty string for notes when default', () {
      final noNotesCert = Certification(
        id: 'cert-no-notes',
        name: 'Basic',
        agency: CertificationAgency.ssi,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(
        adapter.extractValue(CertificationField.notes, noNotesCert),
        equals(''),
      );
    });
  });

  group('CertificationFieldAdapter.formatValue', () {
    final adapter = CertificationFieldAdapter.instance;

    test('returns -- for null value', () {
      expect(
        adapter.formatValue(CertificationField.certName, null, units),
        equals('--'),
      );
    });

    test('formats certification name as string', () {
      expect(
        adapter.formatValue(
          CertificationField.certName,
          'Advanced Open Water',
          units,
        ),
        equals('Advanced Open Water'),
      );
    });

    test('formats agency using enum name', () {
      expect(
        adapter.formatValue(
          CertificationField.agency,
          CertificationAgency.padi,
          units,
        ),
        equals('padi'),
      );
    });

    test('formats level using enum name', () {
      expect(
        adapter.formatValue(
          CertificationField.level,
          CertificationLevel.advancedOpenWater,
          units,
        ),
        equals('advancedOpenWater'),
      );
    });

    test('formats card number as string', () {
      expect(
        adapter.formatValue(CertificationField.cardNumber, 'AOW-12345', units),
        equals('AOW-12345'),
      );
    });

    test('formats issue date using DateFormat.yMMMd()', () {
      final date = DateTime(2023, 6, 15);
      expect(
        adapter.formatValue(CertificationField.issueDate, date, units),
        equals(dateFormat.format(date)),
      );
    });

    test('formats expiry date using DateFormat.yMMMd()', () {
      final date = DateTime(2026, 6, 15);
      expect(
        adapter.formatValue(CertificationField.expiryDate, date, units),
        equals(dateFormat.format(date)),
      );
    });

    test('formats instructor name as string', () {
      expect(
        adapter.formatValue(
          CertificationField.instructorName,
          'Jane Smith',
          units,
        ),
        equals('Jane Smith'),
      );
    });

    test('formats instructor number as string', () {
      expect(
        adapter.formatValue(
          CertificationField.instructorNumber,
          'INST-789',
          units,
        ),
        equals('INST-789'),
      );
    });

    test('formats expiry status as string', () {
      expect(
        adapter.formatValue(CertificationField.expiryStatus, 'Valid', units),
        equals('Valid'),
      );
    });

    test('formats notes as string', () {
      expect(
        adapter.formatValue(
          CertificationField.notes,
          'Completed in Malta',
          units,
        ),
        equals('Completed in Malta'),
      );
    });

    test('returns -- for empty string value', () {
      expect(
        adapter.formatValue(CertificationField.notes, '', units),
        equals('--'),
      );
    });

    test('returns -- for null agency', () {
      expect(
        adapter.formatValue(CertificationField.agency, null, units),
        equals('--'),
      );
    });

    test('returns -- for null level', () {
      expect(
        adapter.formatValue(CertificationField.level, null, units),
        equals('--'),
      );
    });

    test('returns -- for null issue date', () {
      expect(
        adapter.formatValue(CertificationField.issueDate, null, units),
        equals('--'),
      );
    });

    test('returns -- for null expiry date', () {
      expect(
        adapter.formatValue(CertificationField.expiryDate, null, units),
        equals('--'),
      );
    });
  });

  group('CertificationFieldAdapter.fieldFromName', () {
    final adapter = CertificationFieldAdapter.instance;

    test('resolves certName', () {
      expect(
        adapter.fieldFromName('certName'),
        equals(CertificationField.certName),
      );
    });

    test('resolves agency', () {
      expect(
        adapter.fieldFromName('agency'),
        equals(CertificationField.agency),
      );
    });

    test('resolves level', () {
      expect(adapter.fieldFromName('level'), equals(CertificationField.level));
    });

    test('resolves cardNumber', () {
      expect(
        adapter.fieldFromName('cardNumber'),
        equals(CertificationField.cardNumber),
      );
    });

    test('resolves issueDate', () {
      expect(
        adapter.fieldFromName('issueDate'),
        equals(CertificationField.issueDate),
      );
    });

    test('resolves expiryDate', () {
      expect(
        adapter.fieldFromName('expiryDate'),
        equals(CertificationField.expiryDate),
      );
    });

    test('resolves instructorName', () {
      expect(
        adapter.fieldFromName('instructorName'),
        equals(CertificationField.instructorName),
      );
    });

    test('resolves instructorNumber', () {
      expect(
        adapter.fieldFromName('instructorNumber'),
        equals(CertificationField.instructorNumber),
      );
    });

    test('resolves expiryStatus', () {
      expect(
        adapter.fieldFromName('expiryStatus'),
        equals(CertificationField.expiryStatus),
      );
    });

    test('resolves notes', () {
      expect(adapter.fieldFromName('notes'), equals(CertificationField.notes));
    });

    test('throws for unknown field name', () {
      expect(() => adapter.fieldFromName('nonExistentField'), throwsStateError);
    });
  });

  group('CertificationField EntityField properties', () {
    test('displayName returns human-readable labels', () {
      expect(CertificationField.certName.displayName, equals('Name'));
      expect(CertificationField.agency.displayName, equals('Agency'));
      expect(CertificationField.level.displayName, equals('Level'));
      expect(CertificationField.cardNumber.displayName, equals('Card Number'));
      expect(CertificationField.issueDate.displayName, equals('Issue Date'));
      expect(CertificationField.expiryDate.displayName, equals('Expiry Date'));
      expect(
        CertificationField.instructorName.displayName,
        equals('Instructor Name'),
      );
      expect(
        CertificationField.instructorNumber.displayName,
        equals('Instructor Number'),
      );
      expect(
        CertificationField.expiryStatus.displayName,
        equals('Expiry Status'),
      );
      expect(CertificationField.notes.displayName, equals('Notes'));
    });

    test('shortLabel returns abbreviated labels', () {
      expect(CertificationField.certName.shortLabel, equals('Name'));
      expect(CertificationField.agency.shortLabel, equals('Agency'));
      expect(CertificationField.level.shortLabel, equals('Level'));
      expect(CertificationField.cardNumber.shortLabel, equals('Card #'));
      expect(CertificationField.issueDate.shortLabel, equals('Issued'));
      expect(CertificationField.expiryDate.shortLabel, equals('Expires'));
      expect(
        CertificationField.instructorName.shortLabel,
        equals('Instructor'),
      );
      expect(
        CertificationField.instructorNumber.shortLabel,
        equals('Instr. #'),
      );
      expect(CertificationField.expiryStatus.shortLabel, equals('Status'));
      expect(CertificationField.notes.shortLabel, equals('Notes'));
    });

    test('icon returns expected icons', () {
      expect(CertificationField.certName.icon, equals(Icons.card_membership));
      expect(CertificationField.agency.icon, equals(Icons.business));
      expect(CertificationField.level.icon, equals(Icons.workspace_premium));
      expect(CertificationField.cardNumber.icon, equals(Icons.tag));
      expect(CertificationField.issueDate.icon, equals(Icons.calendar_today));
      expect(CertificationField.expiryDate.icon, equals(Icons.event));
      expect(CertificationField.instructorName.icon, equals(Icons.person));
      expect(CertificationField.instructorNumber.icon, equals(Icons.badge));
      expect(CertificationField.expiryStatus.icon, equals(Icons.info_outline));
      expect(CertificationField.notes.icon, equals(Icons.notes));
    });

    test('defaultWidth returns positive values', () {
      expect(CertificationField.certName.defaultWidth, equals(150));
      expect(CertificationField.agency.defaultWidth, equals(100));
      expect(CertificationField.level.defaultWidth, equals(120));
      expect(CertificationField.cardNumber.defaultWidth, equals(110));
      expect(CertificationField.issueDate.defaultWidth, equals(100));
      expect(CertificationField.expiryDate.defaultWidth, equals(100));
      expect(CertificationField.instructorName.defaultWidth, equals(120));
      expect(CertificationField.instructorNumber.defaultWidth, equals(110));
      expect(CertificationField.expiryStatus.defaultWidth, equals(100));
      expect(CertificationField.notes.defaultWidth, equals(150));
    });

    test(
      'minWidth returns positive values less than or equal to defaultWidth',
      () {
        for (final field in CertificationField.values) {
          expect(
            field.minWidth,
            lessThanOrEqualTo(field.defaultWidth),
            reason: '${field.name} minWidth should be <= defaultWidth',
          );
          expect(
            field.minWidth,
            greaterThan(0),
            reason: '${field.name} minWidth should be > 0',
          );
        }
      },
    );

    test('sortable returns expected values', () {
      expect(CertificationField.certName.sortable, isTrue);
      expect(CertificationField.agency.sortable, isTrue);
      expect(CertificationField.level.sortable, isTrue);
      expect(CertificationField.cardNumber.sortable, isTrue);
      expect(CertificationField.issueDate.sortable, isTrue);
      expect(CertificationField.expiryDate.sortable, isTrue);
      expect(CertificationField.instructorName.sortable, isTrue);
      expect(CertificationField.instructorNumber.sortable, isFalse);
      expect(CertificationField.expiryStatus.sortable, isFalse);
      expect(CertificationField.notes.sortable, isFalse);
    });

    test('categoryName returns expected categories', () {
      expect(CertificationField.certName.categoryName, equals('core'));
      expect(CertificationField.agency.categoryName, equals('core'));
      expect(CertificationField.level.categoryName, equals('core'));
      expect(CertificationField.cardNumber.categoryName, equals('core'));
      expect(CertificationField.issueDate.categoryName, equals('dates'));
      expect(CertificationField.expiryDate.categoryName, equals('dates'));
      expect(CertificationField.expiryStatus.categoryName, equals('dates'));
      expect(
        CertificationField.instructorName.categoryName,
        equals('instructor'),
      );
      expect(
        CertificationField.instructorNumber.categoryName,
        equals('instructor'),
      );
      expect(CertificationField.notes.categoryName, equals('other'));
    });

    test('isRightAligned is false for all fields', () {
      for (final field in CertificationField.values) {
        expect(
          field.isRightAligned,
          isFalse,
          reason: '${field.name} should not be right-aligned',
        );
      }
    });
  });
}
