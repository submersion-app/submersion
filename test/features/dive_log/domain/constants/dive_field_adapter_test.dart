import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/constants/dive_field_adapter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/constants/entity_field.dart';

void main() {
  const units = UnitFormatter(AppSettings());
  final now = DateTime(2024, 6, 15, 10, 30);

  group('DiveEntityField - wrapper delegation', () {
    test('name delegates to DiveField.name', () {
      for (final field in DiveField.values) {
        final wrapper = DiveEntityField(field);
        expect(wrapper.name, field.name);
      }
    });

    test('displayName delegates to DiveField.displayName', () {
      const wrapper = DiveEntityField(DiveField.maxDepth);
      expect(wrapper.displayName, 'Max Depth');
    });

    test('shortLabel delegates to DiveField.shortLabel', () {
      const wrapper = DiveEntityField(DiveField.bottomTime);
      expect(wrapper.shortLabel, 'BT');
    });

    test('icon delegates to DiveField.icon', () {
      const wrapper = DiveEntityField(DiveField.maxDepth);
      expect(wrapper.icon, Icons.arrow_downward);
    });

    test('icon returns null for fields without icons', () {
      const wrapper = DiveEntityField(DiveField.sacRate);
      expect(wrapper.icon, isNull);
    });

    test('defaultWidth delegates to DiveField.defaultWidth', () {
      const wrapper = DiveEntityField(DiveField.diveNumber);
      expect(wrapper.defaultWidth, 60);
    });

    test('minWidth delegates to DiveField.minWidth', () {
      const wrapper = DiveEntityField(DiveField.diveNumber);
      expect(wrapper.minWidth, 40);
    });

    test('sortable delegates to DiveField.sortable', () {
      const sortableWrapper = DiveEntityField(DiveField.maxDepth);
      expect(sortableWrapper.sortable, isTrue);

      const nonSortableWrapper = DiveEntityField(DiveField.notes);
      expect(nonSortableWrapper.sortable, isFalse);
    });

    test('categoryName delegates to DiveField.category.name', () {
      const wrapper = DiveEntityField(DiveField.waterTemp);
      expect(wrapper.categoryName, 'environment');

      const coreWrapper = DiveEntityField(DiveField.diveNumber);
      expect(coreWrapper.categoryName, 'core');
    });
  });

  group('DiveEntityField - implements EntityField', () {
    test('DiveEntityField implements EntityField interface', () {
      const wrapper = DiveEntityField(DiveField.maxDepth);
      expect(wrapper, isA<EntityField>());
    });
  });

  group('DiveEntityField - isRightAligned', () {
    const rightAlignedFields = {
      DiveField.diveNumber,
      DiveField.maxDepth,
      DiveField.avgDepth,
      DiveField.bottomTime,
      DiveField.runtime,
      DiveField.waterTemp,
      DiveField.airTemp,
      DiveField.swellHeight,
      DiveField.altitude,
      DiveField.surfacePressure,
      DiveField.windSpeed,
      DiveField.humidity,
      DiveField.tankCount,
      DiveField.startPressure,
      DiveField.endPressure,
      DiveField.sacRate,
      DiveField.gasConsumed,
      DiveField.totalWeight,
      DiveField.gradientFactorLow,
      DiveField.gradientFactorHigh,
      DiveField.cnsStart,
      DiveField.cnsEnd,
      DiveField.otu,
      DiveField.setpointLow,
      DiveField.setpointHigh,
      DiveField.setpointDeco,
      DiveField.ratingStars,
      DiveField.surfaceInterval,
      DiveField.siteLatitude,
      DiveField.siteLongitude,
    };

    test('numeric fields are right-aligned', () {
      for (final field in rightAlignedFields) {
        final wrapper = DiveEntityField(field);
        expect(
          wrapper.isRightAligned,
          isTrue,
          reason: '${field.name} should be right-aligned',
        );
      }
    });

    test('non-numeric fields are left-aligned', () {
      final leftAlignedFields = DiveField.values
          .where((f) => !rightAlignedFields.contains(f))
          .toSet();
      for (final field in leftAlignedFields) {
        final wrapper = DiveEntityField(field);
        expect(
          wrapper.isRightAligned,
          isFalse,
          reason: '${field.name} should be left-aligned',
        );
      }
    });
  });

  group('DiveEntityField - equality and hashCode', () {
    test('two wrappers of same field are equal', () {
      const a = DiveEntityField(DiveField.maxDepth);
      const b = DiveEntityField(DiveField.maxDepth);
      expect(a, equals(b));
    });

    test('two wrappers of different fields are not equal', () {
      const a = DiveEntityField(DiveField.maxDepth);
      const b = DiveEntityField(DiveField.avgDepth);
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent for same field', () {
      const a = DiveEntityField(DiveField.maxDepth);
      const b = DiveEntityField(DiveField.maxDepth);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('wrapper is not equal to non-DiveEntityField', () {
      const a = DiveEntityField(DiveField.maxDepth);
      expect(a, isNot(equals('maxDepth')));
      expect(a, isNot(equals(42)));
    });

    test('can be used as map key', () {
      final map = <DiveEntityField, String>{};
      map[const DiveEntityField(DiveField.maxDepth)] = 'depth';
      expect(map[const DiveEntityField(DiveField.maxDepth)], 'depth');
    });

    test('can be used in set (duplicates deduplicated)', () {
      const a = DiveEntityField(DiveField.maxDepth);
      const c = DiveEntityField(DiveField.avgDepth);
      // ignore: equal_elements_in_set
      final set = <DiveEntityField>{a, a, c};
      expect(set.length, 2);
    });
  });

  group('DiveFieldAdapter - allFields', () {
    test('contains all DiveField values wrapped', () {
      final adapter = DiveFieldAdapter.instance;
      expect(adapter.allFields.length, DiveField.values.length);
    });

    test('each field wraps the corresponding DiveField', () {
      final adapter = DiveFieldAdapter.instance;
      for (var i = 0; i < DiveField.values.length; i++) {
        expect(adapter.allFields[i].field, DiveField.values[i]);
      }
    });

    test('allFields elements implement EntityField', () {
      final adapter = DiveFieldAdapter.instance;
      for (final field in adapter.allFields) {
        expect(field, isA<EntityField>());
      }
    });
  });

  group('DiveFieldAdapter - fieldsByCategory', () {
    test('groups fields correctly', () {
      final adapter = DiveFieldAdapter.instance;
      final categories = adapter.fieldsByCategory;

      expect(categories.containsKey('core'), isTrue);
      expect(categories.containsKey('environment'), isTrue);
      expect(categories.containsKey('gas'), isTrue);
      expect(categories.containsKey('tank'), isTrue);
      expect(categories.containsKey('weight'), isTrue);
      expect(categories.containsKey('equipment'), isTrue);
      expect(categories.containsKey('deco'), isTrue);
      expect(categories.containsKey('physiology'), isTrue);
      expect(categories.containsKey('rebreather'), isTrue);
      expect(categories.containsKey('people'), isTrue);
      expect(categories.containsKey('location'), isTrue);
      expect(categories.containsKey('trip'), isTrue);
      expect(categories.containsKey('rating'), isTrue);
      expect(categories.containsKey('metadata'), isTrue);
    });

    test('core category contains expected fields', () {
      final adapter = DiveFieldAdapter.instance;
      final coreFields = adapter.fieldsByCategory['core']!;
      final coreNames = coreFields.map((f) => f.field).toSet();

      expect(coreNames, contains(DiveField.diveNumber));
      expect(coreNames, contains(DiveField.dateTime));
      expect(coreNames, contains(DiveField.siteName));
      expect(coreNames, contains(DiveField.maxDepth));
      expect(coreNames, contains(DiveField.bottomTime));
    });

    test('all fields appear in exactly one category', () {
      final adapter = DiveFieldAdapter.instance;
      final allCategorized = adapter.fieldsByCategory.values
          .expand((list) => list)
          .toList();
      expect(allCategorized.length, DiveField.values.length);

      // Check no duplicates
      final fieldSet = allCategorized.map((f) => f.field).toSet();
      expect(fieldSet.length, DiveField.values.length);
    });
  });

  group('DiveFieldAdapter - extractValue', () {
    const testSite = DiveSite(
      id: 'site-1',
      name: 'Test Site',
      country: 'US',
      region: 'California',
      location: GeoPoint(34.0, -118.0),
    );

    final tag = Tag(id: 't1', name: 'night', createdAt: now, updatedAt: now);

    final testDive = Dive(
      id: 'dive-1',
      diveNumber: 10,
      dateTime: now,
      maxDepth: 25.0,
      avgDepth: 15.0,
      bottomTime: const Duration(minutes: 40),
      runtime: const Duration(minutes: 47),
      waterTemp: 22.0,
      isFavorite: true,
      tags: [tag],
      site: testSite,
      weights: [
        const DiveWeight(
          id: 'w1',
          diveId: 'dive-1',
          weightType: WeightType.integrated,
          amountKg: 4.0,
        ),
      ],
      buddy: 'Alice',
    );

    test('delegates to extractFromDive', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.diveNumber);
      expect(adapter.extractValue(field, testDive), 10);
    });

    test('extracts site name through wrapper', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.siteName);
      expect(adapter.extractValue(field, testDive), 'Test Site');
    });

    test('extracts maxDepth through wrapper', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.maxDepth);
      expect(adapter.extractValue(field, testDive), 25.0);
    });

    test('extracts tags as list of names', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.tags);
      expect(adapter.extractValue(field, testDive), ['night']);
    });

    test('extracts isFavorite boolean', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.isFavorite);
      expect(adapter.extractValue(field, testDive), true);
    });

    test('extracts buddy string', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.buddy);
      expect(adapter.extractValue(field, testDive), 'Alice');
    });
  });

  group('DiveFieldAdapter - formatValue', () {
    test('delegates to field.formatValue', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.maxDepth);
      final formatted = adapter.formatValue(field, 25.0, units);
      expect(formatted, DiveField.maxDepth.formatValue(25.0, units));
    });

    test('formats null as "--"', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.maxDepth);
      expect(adapter.formatValue(field, null, units), '--');
    });

    test('formats dive number with #', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.diveNumber);
      expect(adapter.formatValue(field, 42, units), '#42');
    });

    test('formats boolean field', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.isFavorite);
      expect(adapter.formatValue(field, true, units), 'Yes');
      expect(adapter.formatValue(field, false, units), 'No');
    });

    test('formats duration field', () {
      final adapter = DiveFieldAdapter.instance;
      const field = DiveEntityField(DiveField.bottomTime);
      expect(
        adapter.formatValue(field, const Duration(minutes: 45), units),
        '45min',
      );
    });
  });

  group('DiveFieldAdapter - fieldFromName', () {
    test('resolves field by name', () {
      final adapter = DiveFieldAdapter.instance;

      for (final field in DiveField.values) {
        final resolved = adapter.fieldFromName(field.name);
        expect(resolved.field, field);
      }
    });

    test('returns wrapped DiveEntityField', () {
      final adapter = DiveFieldAdapter.instance;
      final result = adapter.fieldFromName('maxDepth');
      expect(result, isA<DiveEntityField>());
      expect(result.field, DiveField.maxDepth);
    });

    test('throws StateError for invalid name', () {
      final adapter = DiveFieldAdapter.instance;
      expect(() => adapter.fieldFromName('nonExistentField'), throwsStateError);
    });
  });

  group('DiveFieldAdapter - singleton', () {
    test('instance is a singleton', () {
      final a = DiveFieldAdapter.instance;
      final b = DiveFieldAdapter.instance;
      expect(identical(a, b), isTrue);
    });

    test('instance is an EntityFieldAdapter', () {
      expect(
        DiveFieldAdapter.instance,
        isA<EntityFieldAdapter<Dive, DiveEntityField>>(),
      );
    });
  });

  group('DiveFieldAdapter - round-trip extraction and formatting', () {
    final testDive = Dive(
      id: 'dive-rt',
      diveNumber: 99,
      dateTime: now,
      maxDepth: 35.0,
      bottomTime: const Duration(minutes: 55),
      waterTemp: 20.0,
      isFavorite: false,
      rating: 5,
    );

    test('extract then format produces valid display string', () {
      final adapter = DiveFieldAdapter.instance;

      for (final entityField in adapter.allFields) {
        final raw = adapter.extractValue(entityField, testDive);
        final formatted = adapter.formatValue(entityField, raw, units);
        expect(
          formatted,
          isA<String>(),
          reason: '${entityField.name} round-trip should produce a String',
        );
      }
    });

    test('extract then format for diveNumber produces "#99"', () {
      final adapter = DiveFieldAdapter.instance;
      final field = adapter.fieldFromName('diveNumber');
      final raw = adapter.extractValue(field, testDive);
      final formatted = adapter.formatValue(field, raw, units);
      expect(formatted, '#99');
    });

    test('extract then format for maxDepth matches UnitFormatter', () {
      final adapter = DiveFieldAdapter.instance;
      final field = adapter.fieldFromName('maxDepth');
      final raw = adapter.extractValue(field, testDive);
      final formatted = adapter.formatValue(field, raw, units);
      expect(formatted, units.formatDepth(35.0));
    });

    test('extract then format for isFavorite produces "No"', () {
      final adapter = DiveFieldAdapter.instance;
      final field = adapter.fieldFromName('isFavorite');
      final raw = adapter.extractValue(field, testDive);
      final formatted = adapter.formatValue(field, raw, units);
      expect(formatted, 'No');
    });
  });
}
