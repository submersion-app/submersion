import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

enum TestField implements EntityField {
  fieldA,
  fieldB,
  fieldC;

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
  String localizedDisplayName(AppLocalizations l10n) => displayName;
  @override
  String localizedShortLabel(AppLocalizations l10n) => shortLabel;
  @override
  bool get isRightAligned => false;
}

TestField _fieldFromName(String name) =>
    TestField.values.firstWhere((e) => e.name == name);

const _defaultConfig = EntityCardViewConfig<TestField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: TestField.fieldA),
    EntityCardSlotConfig(slotId: 'stat1', field: TestField.fieldB),
  ],
);

EntityCardConfigNotifier<TestField> _makeNotifier() {
  return EntityCardConfigNotifier<TestField>(
    defaultConfig: _defaultConfig,
    fieldFromName: _fieldFromName,
  );
}

void main() {
  group('EntityCardConfigNotifier mutations', () {
    late EntityCardConfigNotifier<TestField> notifier;

    setUp(() => notifier = _makeNotifier());
    tearDown(() => notifier.dispose());

    test('starts with the default config', () {
      expect(notifier.state, _defaultConfig);
    });

    test('setSlotField swaps one slot and leaves the rest', () {
      notifier.setSlotField('stat1', TestField.fieldC);
      expect(notifier.state.slots[0].field, TestField.fieldA);
      expect(notifier.state.slots[1].field, TestField.fieldC);
    });

    test('setSlotField on an unknown slot leaves the state identical', () {
      final before = notifier.state;
      notifier.setSlotField('nosuchslot', TestField.fieldC);
      expect(identical(notifier.state, before), isTrue);
    });

    test('setSlotField with the field already in the slot is a no-op', () {
      final before = notifier.state;
      notifier.setSlotField('stat1', TestField.fieldB);
      expect(identical(notifier.state, before), isTrue);
    });

    test('addExtraField appends and ignores duplicates', () {
      notifier.addExtraField(TestField.fieldC);
      notifier.addExtraField(TestField.fieldC);
      expect(notifier.state.extraFields, [TestField.fieldC]);
    });

    test('removeExtraField drops the field', () {
      notifier.setExtraFields([TestField.fieldB, TestField.fieldC]);
      notifier.removeExtraField(TestField.fieldB);
      expect(notifier.state.extraFields, [TestField.fieldC]);
    });

    test('reorderExtraFields moves an item', () {
      notifier.setExtraFields([
        TestField.fieldA,
        TestField.fieldB,
        TestField.fieldC,
      ]);
      notifier.reorderExtraFields(0, 2);
      expect(notifier.state.extraFields, [
        TestField.fieldB,
        TestField.fieldC,
        TestField.fieldA,
      ]);
    });

    test('replace swaps the whole config and resetToDefault restores', () {
      const other = EntityCardViewConfig<TestField>(
        slots: [EntityCardSlotConfig(slotId: 'title', field: TestField.fieldC)],
        extraFields: [TestField.fieldA],
      );
      notifier.replace(other);
      expect(notifier.state, other);
      notifier.resetToDefault();
      expect(notifier.state, _defaultConfig);
    });
  });

  group('EntityCardConfigNotifier persistence', () {
    late AppDatabase db;
    late ViewConfigRepository repository;
    const diverId = 'diver-test-1';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = ViewConfigRepository(db);
      DatabaseService.instance.setTestDatabase(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: const Value(diverId),
              name: const Value('Test Diver'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });

    tearDown(() async {
      DatabaseService.instance.resetForTesting();
      await db.close();
    });

    test('init loads a saved config', () async {
      const saved = EntityCardViewConfig<TestField>(
        slots: [EntityCardSlotConfig(slotId: 'title', field: TestField.fieldC)],
        extraFields: [TestField.fieldB],
      );
      await repository.saveRawConfig(
        diverId,
        'card_test',
        jsonEncode(saved.toJson()),
      );
      final notifier = _makeNotifier();
      addTearDown(notifier.dispose);

      await notifier.init(repository, diverId, 'card_test');

      expect(notifier.state, saved);
    });

    test('init keeps the default when a saved field name is unknown', () async {
      await repository.saveRawConfig(
        diverId,
        'card_test',
        jsonEncode({
          'slots': [
            {'slotId': 'title', 'field': 'fieldFromTheFuture'},
          ],
          'extraFields': <String>[],
        }),
      );
      final notifier = _makeNotifier();
      addTearDown(notifier.dispose);

      await notifier.init(repository, diverId, 'card_test');

      expect(notifier.state, _defaultConfig);
    });

    test('a no-op setSlotField never writes', () async {
      final notifier = _makeNotifier();
      addTearDown(notifier.dispose);
      await notifier.init(repository, diverId, 'card_test');

      notifier.setSlotField('nosuchslot', TestField.fieldC);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(await repository.getRawConfig(diverId, 'card_test'), isNull);
    });

    test('a mutation is persisted after the debounce', () async {
      final notifier = _makeNotifier();
      addTearDown(notifier.dispose);
      await notifier.init(repository, diverId, 'card_test');

      notifier.setSlotField('title', TestField.fieldB);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      final json = await repository.getRawConfig(diverId, 'card_test');
      final reloaded = EntityCardViewConfig.fromJson<TestField>(
        jsonDecode(json!) as Map<String, dynamic>,
        _fieldFromName,
      );
      expect(reloaded.slots.first.field, TestField.fieldB);
    });
  });
}
