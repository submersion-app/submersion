import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';

/// Minimal [EntityField] enum used throughout these tests. It avoids pulling
/// in any application-specific field definitions.
enum _TestField implements EntityField {
  alpha,
  bravo,
  charlie;

  @override
  String get name => toString().split('.').last;

  @override
  String get displayName => name;

  @override
  String get shortLabel => name;

  @override
  IconData? get icon => null;

  @override
  double get defaultWidth => 100;

  @override
  double get minWidth => 50;

  @override
  bool get sortable => true;

  @override
  String get categoryName => 'test';

  @override
  bool get isRightAligned => false;
}

_TestField _fieldFromName(String name) {
  return _TestField.values.firstWhere((e) => e.name == name);
}

void main() {
  group('EntityCardSlotConfig', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      const slot = EntityCardSlotConfig<_TestField>(
        slotId: 'title',
        field: _TestField.alpha,
      );

      final json = slot.toJson();
      final restored = EntityCardSlotConfig.fromJson<_TestField>(
        json,
        _fieldFromName,
      );

      expect(restored.slotId, equals('title'));
      expect(restored.field, equals(_TestField.alpha));
    });

    test('copyWith replaces only the supplied fields', () {
      const original = EntityCardSlotConfig<_TestField>(
        slotId: 'title',
        field: _TestField.alpha,
      );

      final updated = original.copyWith(field: _TestField.bravo);

      expect(updated.slotId, equals('title'));
      expect(updated.field, equals(_TestField.bravo));
    });

    test('copyWith with no arguments returns equal instance', () {
      const original = EntityCardSlotConfig<_TestField>(
        slotId: 'stat1',
        field: _TestField.charlie,
      );

      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('Equatable equality for identical values', () {
      const a = EntityCardSlotConfig<_TestField>(
        slotId: 'title',
        field: _TestField.alpha,
      );
      const b = EntityCardSlotConfig<_TestField>(
        slotId: 'title',
        field: _TestField.alpha,
      );

      expect(a, equals(b));
    });

    test('Equatable inequality for different values', () {
      const a = EntityCardSlotConfig<_TestField>(
        slotId: 'title',
        field: _TestField.alpha,
      );
      const b = EntityCardSlotConfig<_TestField>(
        slotId: 'subtitle',
        field: _TestField.alpha,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('EntityCardViewConfig', () {
    EntityCardViewConfig<_TestField> makeConfig({
      List<_TestField> extraFields = const [],
    }) {
      return EntityCardViewConfig<_TestField>(
        slots: const [
          EntityCardSlotConfig(slotId: 'title', field: _TestField.alpha),
          EntityCardSlotConfig(slotId: 'subtitle', field: _TestField.bravo),
        ],
        extraFields: extraFields,
      );
    }

    test('toJson / fromJson roundtrip with slots and extraFields', () {
      final config = makeConfig(extraFields: [_TestField.charlie]);

      final json = config.toJson();
      final restored = EntityCardViewConfig.fromJson<_TestField>(
        json,
        _fieldFromName,
      );

      expect(restored.slots.length, equals(2));
      expect(restored.slots[0].slotId, equals('title'));
      expect(restored.slots[0].field, equals(_TestField.alpha));
      expect(restored.slots[1].slotId, equals('subtitle'));
      expect(restored.slots[1].field, equals(_TestField.bravo));
      expect(restored.extraFields, equals([_TestField.charlie]));
    });

    test('fromJson with missing extraFields defaults to empty list', () {
      final json = {
        'slots': [
          {'slotId': 'title', 'field': 'alpha'},
        ],
        // extraFields intentionally omitted
      };

      final config = EntityCardViewConfig.fromJson<_TestField>(
        json,
        _fieldFromName,
      );

      expect(config.extraFields, isEmpty);
    });

    test('copyWith preserves values when no arguments supplied', () {
      final config = makeConfig(extraFields: [_TestField.charlie]);
      final copy = config.copyWith();

      expect(copy, equals(config));
    });

    test('copyWith replaces slots', () {
      final config = makeConfig();
      final updated = config.copyWith(
        slots: const [
          EntityCardSlotConfig(slotId: 'only', field: _TestField.charlie),
        ],
      );

      expect(updated.slots.length, equals(1));
      expect(updated.slots[0].field, equals(_TestField.charlie));
      expect(updated.extraFields, isEmpty);
    });

    test('copyWith replaces extraFields', () {
      final config = makeConfig();
      final updated = config.copyWith(
        extraFields: [_TestField.alpha, _TestField.charlie],
      );

      expect(updated.extraFields.length, equals(2));
      expect(updated.slots.length, equals(2));
    });

    test('Equatable equality for identical configs', () {
      final a = makeConfig(extraFields: [_TestField.charlie]);
      final b = makeConfig(extraFields: [_TestField.charlie]);

      expect(a, equals(b));
    });

    test('Equatable inequality when slots differ', () {
      final a = makeConfig();
      const b = EntityCardViewConfig<_TestField>(
        slots: [
          EntityCardSlotConfig(slotId: 'title', field: _TestField.charlie),
        ],
      );

      expect(a, isNot(equals(b)));
    });

    test('Equatable inequality when extraFields differ', () {
      final a = makeConfig();
      final b = makeConfig(extraFields: [_TestField.charlie]);

      expect(a, isNot(equals(b)));
    });

    test('toJson / fromJson roundtrip with empty slots', () {
      const config = EntityCardViewConfig<_TestField>(slots: []);

      final json = config.toJson();
      final restored = EntityCardViewConfig.fromJson<_TestField>(
        json,
        _fieldFromName,
      );

      expect(restored.slots, isEmpty);
      expect(restored.extraFields, isEmpty);
    });

    test('toJson / fromJson roundtrip with empty extraFields', () {
      const config = EntityCardViewConfig<_TestField>(
        slots: [EntityCardSlotConfig(slotId: 'title', field: _TestField.alpha)],
        extraFields: [],
      );

      final json = config.toJson();
      final restored = EntityCardViewConfig.fromJson<_TestField>(
        json,
        _fieldFromName,
      );

      expect(restored.slots.length, 1);
      expect(restored.extraFields, isEmpty);
    });

    test('fromJson with null extraFields key defaults to empty', () {
      final json = {'slots': <Map<String, dynamic>>[], 'extraFields': null};

      final config = EntityCardViewConfig.fromJson<_TestField>(
        json,
        _fieldFromName,
      );

      expect(config.extraFields, isEmpty);
    });

    test('copyWith preserves slots when only extraFields changed', () {
      final config = makeConfig();
      final updated = config.copyWith(extraFields: [_TestField.charlie]);

      expect(updated.slots, equals(config.slots));
      expect(updated.extraFields, [_TestField.charlie]);
    });
  });
}
