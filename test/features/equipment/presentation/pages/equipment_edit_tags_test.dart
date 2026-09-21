import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The Tags field on the equipment edit page (issue #1942).
void main() {
  late EquipmentRepository repository;
  late EquipmentTagRepository tagRepository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
    tagRepository = EquipmentTagRepository();
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('d1', 'Night', 0, 0, 1, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpEditor(
    WidgetTester tester,
    String? equipmentId, {
    List<Object> extraOverrides = const [],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentRepositoryProvider.overrideWithValue(repository),
          ...extraOverrides,
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentEditPage(equipmentId: equipmentId, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final tagField = find.descendant(
    of: find.byType(TagInputWidget),
    matching: find.byType(TextField),
  );

  testWidgets('the Tags field follows Notes and shows the stored tags', (
    tester,
  ) async {
    final item = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
    );
    await tagRepository.replaceTags(item.id, ['t1']);

    await pumpEditor(tester, item.id);

    expect(find.text('Tags'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Tags')).dy,
      greaterThan(tester.getTopLeft(find.text('Notes')).dy),
    );
    expect(find.widgetWithText(TagChip, 'Travel kit'), findsOneWidget);
  });

  testWidgets('removing a tag and saving writes the new set', (tester) async {
    final item = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
    );
    await tagRepository.replaceTags(item.id, ['t1']);
    await pumpEditor(tester, item.id);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(TagChip, 'Travel kit'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await tagRepository.getTagsForEquipment(item.id), isEmpty);
  });

  group('while the stored tags are still loading', () {
    late EquipmentItem item;
    late Completer<List<Tag>> pending;

    setUp(() async {
      item = await repository.createEquipment(
        const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
      );
      await tagRepository.replaceTags(item.id, ['t1']);
    });

    /// The completer is made inside the test body: one made in setUp lives
    /// outside the test's fake-async zone, so pumping never delivers it.
    Future<void> pumpLoading(WidgetTester tester) {
      pending = Completer<List<Tag>>();
      return pumpEditor(
        tester,
        item.id,
        extraOverrides: [
          tagsForEquipmentProvider(
            item.id,
          ).overrideWith((ref) => pending.future),
        ],
      );
    }

    testWidgets('the Tags field is disabled until they arrive', (tester) async {
      await pumpLoading(tester);
      // A disabled TagInputWidget drops its text field.
      expect(tagField, findsNothing);

      pending.complete(await tagRepository.getTagsForEquipment(item.id));
      await tester.pumpAndSettle();

      expect(tagField, findsOneWidget);
      expect(find.widgetWithText(TagChip, 'Travel kit'), findsOneWidget);
    });

    testWidgets('a read that fails leaves the field locked and the stored '
        'tags untouched', (tester) async {
      await pumpEditor(
        tester,
        item.id,
        extraOverrides: [
          tagsForEquipmentProvider(
            item.id,
          ).overrideWith((ref) => Future<List<Tag>>.error(StateError('gone'))),
        ],
      );

      expect(tagField, findsNothing, reason: 'the field stays disabled');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        [
          for (final t in await tagRepository.getTagsForEquipment(item.id))
            t.id,
        ],
        ['t1'],
      );
    });

    testWidgets('a save leaves the stored tags alone', (tester) async {
      await pumpLoading(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        [
          for (final t in await tagRepository.getTagsForEquipment(item.id))
            t.id,
        ],
        ['t1'],
      );
    });
  });

  testWidgets('suggestions list equipment tags only', (tester) async {
    await pumpEditor(tester, null);

    await tester.enterText(tagField, 'i');
    await tester.pumpAndSettle();

    expect(find.text('Travel kit'), findsOneWidget);
    expect(find.text('Night'), findsNothing);
  });

  testWidgets('a tag typed on a new item applies to equipment and is saved '
      'with it', (tester) async {
    await pumpEditor(tester, null);
    await tester.enterText(find.byType(TextFormField).first, 'Wing');
    await tester.enterText(tagField, 'Rental');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TagChip, 'Rental'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repository.getAllEquipment()).single;
    final tags = await tagRepository.getTagsForEquipment(saved.id);
    expect(tags.single.name, 'Rental');
    expect(tags.single.appliesTo(TagScope.equipment), isTrue);
    expect(tags.single.appliesTo(TagScope.dives), isFalse);
  });
}
