import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // A UnitFormatter backed by metric default settings.
  const units = UnitFormatter(AppSettings());

  // A representative BuddyWithCount entity for adapter tests.
  final testBuddy = Buddy(
    id: 'buddy-1',
    name: 'John Doe',
    email: 'john@example.com',
    phone: '+1234567890',
    certificationLevel: CertificationLevel.advancedOpenWater,
    certificationAgency: CertificationAgency.padi,
    notes: 'Great dive buddy',
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
  final testEntity = (buddy: testBuddy, diveCount: 15);

  group('BuddyFieldAdapter.allFields', () {
    test('has expected count matching BuddyField.values', () {
      expect(
        BuddyFieldAdapter.instance.allFields.length,
        equals(BuddyField.values.length),
      );
    });

    test('contains all BuddyField values', () {
      expect(
        BuddyFieldAdapter.instance.allFields,
        containsAll(BuddyField.values),
      );
    });
  });

  group('BuddyFieldAdapter.fieldsByCategory', () {
    test('groups core fields together', () {
      final byCategory = BuddyFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['core'],
        containsAll([BuddyField.buddyName, BuddyField.diveCount]),
      );
    });

    test('groups contact fields together', () {
      final byCategory = BuddyFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['contact'],
        containsAll([BuddyField.email, BuddyField.phone]),
      );
    });

    test('groups certification fields together', () {
      final byCategory = BuddyFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['certification'],
        containsAll([
          BuddyField.certificationLevel,
          BuddyField.certificationAgency,
        ]),
      );
    });

    test('groups other fields together', () {
      final byCategory = BuddyFieldAdapter.instance.fieldsByCategory;
      expect(byCategory['other'], containsAll([BuddyField.notes]));
    });

    test('covers all BuddyField values across categories', () {
      final byCategory = BuddyFieldAdapter.instance.fieldsByCategory;
      final allGrouped = byCategory.values.expand((v) => v).toList();
      expect(allGrouped.length, equals(BuddyField.values.length));
    });
  });

  group('BuddyFieldAdapter.extractValue', () {
    final adapter = BuddyFieldAdapter.instance;

    test('returns buddy name', () {
      expect(
        adapter.extractValue(BuddyField.buddyName, testEntity),
        equals('John Doe'),
      );
    });

    test('returns email', () {
      expect(
        adapter.extractValue(BuddyField.email, testEntity),
        equals('john@example.com'),
      );
    });

    test('returns phone', () {
      expect(
        adapter.extractValue(BuddyField.phone, testEntity),
        equals('+1234567890'),
      );
    });

    test('returns certification level', () {
      expect(
        adapter.extractValue(BuddyField.certificationLevel, testEntity),
        equals(CertificationLevel.advancedOpenWater),
      );
    });

    test('returns certification agency', () {
      expect(
        adapter.extractValue(BuddyField.certificationAgency, testEntity),
        equals(CertificationAgency.padi),
      );
    });

    test('returns dive count', () {
      expect(
        adapter.extractValue(BuddyField.diveCount, testEntity),
        equals(15),
      );
    });

    test('returns notes when non-empty', () {
      expect(
        adapter.extractValue(BuddyField.notes, testEntity),
        equals('Great dive buddy'),
      );
    });

    test('returns null for email when buddy has no email', () {
      // copyWith won't clear a non-null field to null, so build fresh.
      final buddy = Buddy(
        id: 'buddy-2',
        name: 'No Email',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final entity = (buddy: buddy, diveCount: 0);
      expect(adapter.extractValue(BuddyField.email, entity), isNull);
    });

    test('returns null for phone when buddy has no phone', () {
      final buddy = Buddy(
        id: 'buddy-3',
        name: 'No Phone',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final entity = (buddy: buddy, diveCount: 0);
      expect(adapter.extractValue(BuddyField.phone, entity), isNull);
    });

    test('returns null for certification level when not set', () {
      final buddy = Buddy(
        id: 'buddy-4',
        name: 'No Cert',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final entity = (buddy: buddy, diveCount: 0);
      expect(
        adapter.extractValue(BuddyField.certificationLevel, entity),
        isNull,
      );
    });

    test('returns null for certification agency when not set', () {
      final buddy = Buddy(
        id: 'buddy-5',
        name: 'No Agency',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final entity = (buddy: buddy, diveCount: 0);
      expect(
        adapter.extractValue(BuddyField.certificationAgency, entity),
        isNull,
      );
    });

    test('returns empty string for notes when buddy has default notes', () {
      final buddy = Buddy(
        id: 'buddy-6',
        name: 'Empty Notes',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final entity = (buddy: buddy, diveCount: 0);
      expect(adapter.extractValue(BuddyField.notes, entity), equals(''));
    });
  });

  group('BuddyFieldAdapter.formatValue', () {
    final adapter = BuddyFieldAdapter.instance;

    test('returns -- for null value', () {
      expect(
        adapter.formatValue(BuddyField.buddyName, null, units),
        equals('--'),
      );
    });

    test('formats buddy name as string', () {
      expect(
        adapter.formatValue(BuddyField.buddyName, 'John Doe', units),
        equals('John Doe'),
      );
    });

    test('formats email as string', () {
      expect(
        adapter.formatValue(BuddyField.email, 'john@example.com', units),
        equals('john@example.com'),
      );
    });

    test('formats phone as string', () {
      expect(
        adapter.formatValue(BuddyField.phone, '+1234567890', units),
        equals('+1234567890'),
      );
    });

    test('formats certification level using enum name', () {
      expect(
        adapter.formatValue(
          BuddyField.certificationLevel,
          CertificationLevel.advancedOpenWater,
          units,
        ),
        equals('advancedOpenWater'),
      );
    });

    test('formats certification agency using enum name', () {
      expect(
        adapter.formatValue(
          BuddyField.certificationAgency,
          CertificationAgency.padi,
          units,
        ),
        equals('padi'),
      );
    });

    test('formats dive count as integer string', () {
      expect(
        adapter.formatValue(BuddyField.diveCount, 15, units),
        equals('15'),
      );
    });

    test('formats notes as string', () {
      expect(
        adapter.formatValue(BuddyField.notes, 'Great dive buddy', units),
        equals('Great dive buddy'),
      );
    });

    test('returns -- for empty string value', () {
      expect(adapter.formatValue(BuddyField.notes, '', units), equals('--'));
    });

    test('returns -- for null certification level', () {
      expect(
        adapter.formatValue(BuddyField.certificationLevel, null, units),
        equals('--'),
      );
    });

    test('returns -- for null certification agency', () {
      expect(
        adapter.formatValue(BuddyField.certificationAgency, null, units),
        equals('--'),
      );
    });
  });

  group('BuddyFieldAdapter.fieldFromName', () {
    final adapter = BuddyFieldAdapter.instance;

    test('resolves buddyName', () {
      expect(adapter.fieldFromName('buddyName'), equals(BuddyField.buddyName));
    });

    test('resolves email', () {
      expect(adapter.fieldFromName('email'), equals(BuddyField.email));
    });

    test('resolves phone', () {
      expect(adapter.fieldFromName('phone'), equals(BuddyField.phone));
    });

    test('resolves certificationLevel', () {
      expect(
        adapter.fieldFromName('certificationLevel'),
        equals(BuddyField.certificationLevel),
      );
    });

    test('resolves certificationAgency', () {
      expect(
        adapter.fieldFromName('certificationAgency'),
        equals(BuddyField.certificationAgency),
      );
    });

    test('resolves diveCount', () {
      expect(adapter.fieldFromName('diveCount'), equals(BuddyField.diveCount));
    });

    test('resolves notes', () {
      expect(adapter.fieldFromName('notes'), equals(BuddyField.notes));
    });

    test('throws for unknown field name', () {
      expect(() => adapter.fieldFromName('nonExistentField'), throwsStateError);
    });
  });

  group('BuddyField EntityField properties', () {
    test('displayName returns human-readable labels', () {
      expect(BuddyField.buddyName.displayName, equals('Name'));
      expect(BuddyField.email.displayName, equals('Email'));
      expect(BuddyField.phone.displayName, equals('Phone'));
      expect(
        BuddyField.certificationLevel.displayName,
        equals('Certification Level'),
      );
      expect(
        BuddyField.certificationAgency.displayName,
        equals('Certification Agency'),
      );
      expect(BuddyField.diveCount.displayName, equals('Dive Count'));
      expect(BuddyField.notes.displayName, equals('Notes'));
    });

    test('shortLabel returns abbreviated labels', () {
      expect(BuddyField.buddyName.shortLabel, equals('Name'));
      expect(BuddyField.email.shortLabel, equals('Email'));
      expect(BuddyField.phone.shortLabel, equals('Phone'));
      expect(BuddyField.certificationLevel.shortLabel, equals('Cert Level'));
      expect(BuddyField.certificationAgency.shortLabel, equals('Agency'));
      expect(BuddyField.diveCount.shortLabel, equals('Dives'));
      expect(BuddyField.notes.shortLabel, equals('Notes'));
    });

    test('icon returns expected icons', () {
      expect(BuddyField.buddyName.icon, equals(Icons.person));
      expect(BuddyField.email.icon, equals(Icons.email));
      expect(BuddyField.phone.icon, equals(Icons.phone));
      expect(BuddyField.certificationLevel.icon, equals(Icons.card_membership));
      expect(BuddyField.certificationAgency.icon, equals(Icons.business));
      expect(BuddyField.diveCount.icon, equals(Icons.scuba_diving));
      expect(BuddyField.notes.icon, equals(Icons.notes));
    });

    test('defaultWidth returns positive values', () {
      expect(BuddyField.buddyName.defaultWidth, equals(150));
      expect(BuddyField.email.defaultWidth, equals(180));
      expect(BuddyField.phone.defaultWidth, equals(120));
      expect(BuddyField.certificationLevel.defaultWidth, equals(130));
      expect(BuddyField.certificationAgency.defaultWidth, equals(110));
      expect(BuddyField.diveCount.defaultWidth, equals(80));
      expect(BuddyField.notes.defaultWidth, equals(150));
    });

    test(
      'minWidth returns positive values less than or equal to defaultWidth',
      () {
        for (final field in BuddyField.values) {
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

    test('sortable is false only for notes', () {
      expect(BuddyField.buddyName.sortable, isTrue);
      expect(BuddyField.email.sortable, isTrue);
      expect(BuddyField.phone.sortable, isTrue);
      expect(BuddyField.certificationLevel.sortable, isTrue);
      expect(BuddyField.certificationAgency.sortable, isTrue);
      expect(BuddyField.diveCount.sortable, isTrue);
      expect(BuddyField.notes.sortable, isFalse);
    });

    test('categoryName returns expected categories', () {
      expect(BuddyField.buddyName.categoryName, equals('core'));
      expect(BuddyField.diveCount.categoryName, equals('core'));
      expect(BuddyField.email.categoryName, equals('contact'));
      expect(BuddyField.phone.categoryName, equals('contact'));
      expect(
        BuddyField.certificationLevel.categoryName,
        equals('certification'),
      );
      expect(
        BuddyField.certificationAgency.categoryName,
        equals('certification'),
      );
      expect(BuddyField.notes.categoryName, equals('other'));
    });

    test('isRightAligned is true only for diveCount', () {
      expect(BuddyField.diveCount.isRightAligned, isTrue);
      for (final field in BuddyField.values) {
        if (field != BuddyField.diveCount) {
          expect(
            field.isRightAligned,
            isFalse,
            reason: '${field.name} should not be right-aligned',
          );
        }
      }
    });
  });
}
