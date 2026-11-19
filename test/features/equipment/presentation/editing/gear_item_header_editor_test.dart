import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_header_editor.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/scoped_tags_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The gear item's header block edited in place (issue #4527, phase 3,
/// plan 6): its name, type, tags and the purchase of wishlist gear.
void main() {
  const apex = EquipmentItem(
    id: 'g1',
    name: 'Apex',
    type: EquipmentType.regulator,
  );

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await EquipmentRepository().createEquipment(apex);
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Spare', 0, 0, 0, 0, 1)",
    );
    await EquipmentTagRepository().replaceTags('g1', ['t1']);
  });
  tearDown(tearDownTestDatabase);

  Future<EditSession<EquipmentItem>> pumpEditor(
    WidgetTester tester, {
    EquipmentItem item = apex,
    Future<bool> Function()? hasDevice,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    final session = EditSession(item);
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentHasDeviceProvider(
            item.id,
          ).overrideWith((ref) => hasDevice?.call() ?? Future.value(false)),
          activeEquipmentProvider.overrideWith((ref) async => const []),
        ].cast(),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: GearItemHeaderEditor(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  DropdownButton<EquipmentType> typeDropdown(WidgetTester tester) =>
      tester.widget<DropdownButton<EquipmentType>>(
        find.byType(DropdownButton<EquipmentType>),
      );

  testWidgets('a tag read that failed says so and offers to read again', (
    tester,
  ) async {
    await DatabaseService.instance.database.customStatement(
      'DROP TABLE equipment_tags',
    );
    final session = await pumpEditor(tester);

    expect(gearItemTagsList.failed(session), isTrue);
    expect(find.byType(SittingLoadFailed), findsOneWidget);
  });

  testWidgets('the type is locked for an item a computer names', (
    tester,
  ) async {
    await pumpEditor(tester, hasDevice: () async => true);

    expect(typeDropdown(tester).onChanged, isNull);
  });

  testWidgets('an item with no device can change type', (tester) async {
    final session = await pumpEditor(tester);

    expect(typeDropdown(tester).onChanged, isNotNull);
    typeDropdown(tester).onChanged!(EquipmentType.bcd);
    await tester.pumpAndSettle();

    expect(session.working.type, EquipmentType.bcd);
    expect(session.changedCardIds, contains('header'));
  });

  testWidgets('the type stays locked while the device lookup loads', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      hasDevice: () => Future<bool>.delayed(const Duration(days: 1)),
    );

    expect(typeDropdown(tester).onChanged, isNull);
  });

  for (final locale in const [Locale('en'), Locale('de'), Locale('fr')]) {
    testWidgets('the type list is alphabetical in $locale', (tester) async {
      await pumpEditor(tester, locale: locale);
      final l10n = lookupAppLocalizations(locale);

      final labels = [
        for (final item in typeDropdown(tester).items!)
          item.value!.localizedName(l10n),
      ];

      expect(labels, [
        for (final type in EquipmentType.values.sortedByLocalizedName(l10n))
          type.localizedName(l10n),
      ]);
      expect(labels, hasLength(EquipmentType.values.length));
    });
  }

  testWidgets('the header editor shows the stored tags', (tester) async {
    await pumpEditor(tester);

    expect(find.text('Travel kit'), findsOneWidget);
  });

  testWidgets('tag suggestions are equipment tags only', (tester) async {
    await pumpEditor(tester);

    expect(
      tester.widget<ScopedTagsField>(find.byType(ScopedTagsField)).scope,
      TagScope.equipment,
    );
  });

  testWidgets('the tags field is inert until the sitting\'s list has loaded', (
    tester,
  ) async {
    final session = EditSession(apex);
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentHasDeviceProvider('g1').overrideWith((ref) async => false),
          activeEquipmentProvider.overrideWith((ref) async => const []),
        ].cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: GearItemHeaderEditor(session: session)),
        ),
      ),
    );

    // The first frame, before the read has answered.
    expect(
      tester.widget<ScopedTagsField>(find.byType(ScopedTagsField)).enabled,
      isFalse,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScopedTagsField>(find.byType(ScopedTagsField)).enabled,
      isTrue,
    );
  });

  testWidgets('Mark purchased sets Active and today\'s date, keeping a set '
      'date', (tester) async {
    final wanted = apex.copyWith(
      status: EquipmentStatus.wanted,
      isActive: false,
    );
    final session = await pumpEditor(tester, item: wanted);

    await tester.tap(find.byKey(const ValueKey('gear-edit-mark-purchased')));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(session.working.status, EquipmentStatus.active);
    expect(session.working.isActive, isTrue);
    expect(
      session.working.purchaseDate,
      DateTime(now.year, now.month, now.day),
    );
    expect(session.changedCardIds, {'details'});
    expect(
      find.byKey(const ValueKey('gear-edit-mark-purchased')),
      findsNothing,
    );
  });

  testWidgets('Mark purchased keeps a purchase date already set', (
    tester,
  ) async {
    final wanted = apex.copyWith(
      status: EquipmentStatus.wanted,
      isActive: false,
      purchaseDate: DateTime(2025, 2, 3),
    );
    final session = await pumpEditor(tester, item: wanted);

    await tester.tap(find.byKey(const ValueKey('gear-edit-mark-purchased')));
    await tester.pumpAndSettle();

    expect(session.working.purchaseDate, DateTime(2025, 2, 3));
  });

  testWidgets('a blank name shows its error', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byKey(const ValueKey('gear-edit-name')), '  ');
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.equipment_edit_nameValidation), findsOneWidget);
  });

  group('the held tags', () {
    Future<List<String>> storedTagIds() async => [
      for (final t in await EquipmentTagRepository().getTagsForEquipment('g1'))
        t.id,
    ];

    Future<EditSession<EquipmentItem>> loaded() async {
      final session = EditSession(apex);
      addTearDown(session.dispose);
      await gearItemTagsList.load(session);
      return session;
    }

    test('a tag removed is written at Save', () async {
      final session = await loaded();
      gearItemTagsList.set(session, const []);

      expect(await storedTagIds(), ['t1']);
      await session.runHeldWrites();

      expect(await storedTagIds(), isEmpty);
    });

    test('untouched tags are not written', () async {
      final session = await loaded();
      session.set(gearNameField, 'Renamed');

      expect(session.isHeld(gearItemTagsList.key), isFalse);
    });

    test('a tag another device added meanwhile stays', () async {
      final session = await loaded();
      final travel = gearItemTagsList.current(session)!.single;
      gearItemTagsList.set(session, [travel, _tag('t2')]);
      gearItemTagsList.set(session, const []);
      await EquipmentTagRepository().replaceTags('g1', ['t1', 't2']);

      await session.runHeldWrites();

      expect(await storedTagIds(), ['t2']);
    });
  });
}

Tag _tag(String id) => Tag(
  id: id,
  name: id,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
