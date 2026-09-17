import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Tags on the equipment list (issue #1942).
void main() {
  final now = DateTime(2026);
  Tag tag(String id, String name) => Tag(
    id: id,
    name: name,
    colorHex: '#4CAF50',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.equipment},
  );
  final travel = tag('t1', 'Travel kit');
  final rental = tag('t2', 'Rental');
  const wing = EquipmentItem(id: 'e1', name: 'Wing', type: EquipmentType.bcd);
  const reg = EquipmentItem(
    id: 'e2',
    name: 'Reg',
    type: EquipmentType.regulator,
  );

  group('EquipmentListTile', () {
    Widget wrap(Widget child) => testApp(
      locale: const Locale('en'),
      overrides: [
        equipmentRollupClockProvider.overrideWith((ref) async => {}),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.empty,
        ),
        activeEquipmentProvider.overrideWith((ref) async => const [wing]),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: child,
    );

    testWidgets('shows up to three tags and a +N chip', (tester) async {
      final five = [
        tag('a', 'Travel kit'),
        tag('b', 'Rental'),
        tag('c', 'Cold water'),
        tag('d', 'Needs repair'),
        tag('e', 'Backup'),
      ];
      await tester.pumpWidget(wrap(EquipmentListTile(item: wing, tags: five)));
      await tester.pumpAndSettle();

      expect(find.text('Travel kit'), findsOneWidget);
      expect(find.text('Rental'), findsOneWidget);
      expect(find.text('Cold water'), findsOneWidget);
      expect(find.text('Needs repair'), findsNothing);
      expect(find.text('Backup'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('a tile given no tags draws no tag chips', (tester) async {
      await tester.pumpWidget(wrap(const EquipmentListTile(item: wing)));
      await tester.pumpAndSettle();

      expect(find.byType(TagChips), findsNothing);
    });
  });

  group('EquipmentListContent', () {
    Future<List<Override>> overrides({
      ListViewMode viewMode = ListViewMode.detailed,
      EquipmentFilterState filter = const EquipmentFilterState(),
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        activeEquipmentProvider.overrideWith((ref) async => const [wing, reg]),
        allEquipmentProvider.overrideWith((ref) async => const [wing, reg]),
        equipmentListViewModeProvider.overrideWith((ref) => viewMode),
        equipmentFilterProvider.overrideWith((ref) => filter),
        highlightedEquipmentIdProvider.overrideWith((ref) => null),
        tagsByEquipmentProvider.overrideWith(
          (ref) async => {
            'e1': [rental, travel],
          },
        ),
        tagsProvider.overrideWith((ref) async => [rental, travel]),
      ];
    }

    Future<void> pumpList(WidgetTester tester, List<Override> overrides) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('detailed tiles carry their tags', (tester) async {
      await pumpList(tester, await overrides());

      expect(find.text('Travel kit'), findsOneWidget);
      expect(find.text('Rental'), findsOneWidget);
    });

    testWidgets('compact tiles show no tags', (tester) async {
      await pumpList(tester, await overrides(viewMode: ListViewMode.compact));

      expect(find.text('Wing'), findsOneWidget);
      expect(find.text('Travel kit'), findsNothing);
    });

    testWidgets('a tag filter keeps only items carrying a selected tag', (
      tester,
    ) async {
      await pumpList(
        tester,
        await overrides(
          viewMode: ListViewMode.compact,
          filter: const EquipmentFilterState(tagIds: {'t1'}),
        ),
      );

      expect(find.text('Wing'), findsOneWidget);
      expect(find.text('Reg'), findsNothing);
    });

    testWidgets('the active filters bar names the tag and removes it', (
      tester,
    ) async {
      await pumpList(
        tester,
        await overrides(
          viewMode: ListViewMode.compact,
          filter: const EquipmentFilterState(tagIds: {'t1'}),
        ),
      );

      final chip = find.widgetWithText(InputChip, 'Travel kit');
      expect(chip, findsOneWidget);
      tester.widget<InputChip>(chip).onDeleted!();
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Reg'), findsOneWidget);
    });

    testWidgets('a tag filter that matches nothing says so', (tester) async {
      await pumpList(
        tester,
        await overrides(filter: const EquipmentFilterState(tagIds: {'unused'})),
      );

      expect(find.text('No equipment with these tags'), findsOneWidget);
    });

    testWidgets('a tag that empties a stocked category is what gets blamed', (
      tester,
    ) async {
      // There is a regulator, but it carries no Travel kit tag.
      await pumpList(
        tester,
        await overrides(
          filter: const EquipmentFilterState(
            type: EquipmentType.regulator,
            tagIds: {'t1'},
          ),
        ),
      );

      expect(find.text('No equipment with these tags'), findsOneWidget);
      expect(find.text('No equipment in this category'), findsNothing);
    });
  });
}
