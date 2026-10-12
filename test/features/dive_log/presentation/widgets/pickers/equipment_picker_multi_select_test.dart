import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

const _reg = EquipmentItem(
  id: 'reg',
  name: 'Apeks Reg',
  type: EquipmentType.regulator,
);
const _mask = EquipmentItem(
  id: 'mask',
  name: 'Frameless Mask',
  type: EquipmentType.mask,
);
const _fins = EquipmentItem(
  id: 'fins',
  name: 'Jet Fins',
  type: EquipmentType.fins,
);

/// What the caller was handed: null until Add is pressed.
class _Result {
  List<EquipmentItem>? confirmed;
}

/// Opens the picker in multi-select mode as a real modal sheet, so Cancel
/// and Add close a route the way they do in the dive editor (issue #2175).
Future<_Result> _open(
  WidgetTester tester, {
  List<EquipmentItem> equipment = const [_reg, _mask, _fins],
  Size size = const Size(900, 2400),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final result = _Result();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeEquipmentProvider.overrideWith((ref) async => equipment),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        allDiversProvider.overrideWith((ref) async => const []),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (sheetContext) => EquipmentPickerSheet(
                  scrollController: ScrollController(),
                  selectedEquipmentIds: const {},
                  onEquipmentConfirmed: (items) {
                    Navigator.of(sheetContext).pop();
                    result.confirmed = items;
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

FilledButton _addButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  group('multi-select (issue #2175)', () {
    testWidgets('asks to add equipment, with a checkbox on every item', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Add Equipment'), findsOneWidget);
      expect(find.text('Add components'), findsNothing);
      expect(find.byType(Checkbox), findsNWidgets(3));
    });

    testWidgets('ticking an item neither adds it nor closes the sheet', (
      tester,
    ) async {
      final result = await _open(tester);

      await tester.tap(find.text('Apeks Reg'));
      await tester.pumpAndSettle();

      expect(result.confirmed, isNull);
      expect(find.byType(EquipmentPickerSheet), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Apeks Reg'),
            )
            .value,
        isTrue,
      );
    });

    testWidgets('Add is disabled until something is ticked, then counts', (
      tester,
    ) async {
      await _open(tester);
      expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
      expect(_addButton(tester).onPressed, isNull);

      await tester.tap(find.text('Apeks Reg'));
      await tester.tap(find.text('Jet Fins'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Add 2'), findsOneWidget);
      expect(_addButton(tester).onPressed, isNotNull);

      // Unticking takes it back out of the count.
      await tester.tap(find.text('Jet Fins'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Add 1'), findsOneWidget);
    });

    testWidgets('Add hands over every ticked item and closes the sheet', (
      tester,
    ) async {
      final result = await _open(tester);

      await tester.tap(find.text('Jet Fins'));
      await tester.tap(find.text('Apeks Reg'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add 2'));
      await tester.pumpAndSettle();

      expect(result.confirmed?.map((e) => e.id), ['fins', 'reg']);
      expect(find.byType(EquipmentPickerSheet), findsNothing);
    });

    testWidgets('Cancel closes the sheet and adds nothing', (tester) async {
      final result = await _open(tester);

      await tester.tap(find.text('Apeks Reg'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(result.confirmed, isNull);
      expect(find.byType(EquipmentPickerSheet), findsNothing);
    });

    testWidgets('Cancel sits beside Add and replaces the close icon', (
      tester,
    ) async {
      await _open(tester);

      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      final add = tester.getRect(find.byType(FilledButton));
      expect(cancel.right, lessThanOrEqualTo(add.left));
      expect(cancel.center.dy, moreOrLessEquals(add.center.dy, epsilon: 1));
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('filter and sort share the title row with Cancel and Add', (
      tester,
    ) async {
      await _open(tester);

      final title = tester.getRect(find.text('Add Equipment'));
      final filter = tester.getRect(find.byIcon(Icons.filter_list));
      final sort = tester.getRect(find.byIcon(Icons.sort));
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      for (final icon in [filter, sort]) {
        expect(icon.center.dy, moreOrLessEquals(title.center.dy, epsilon: 1));
        expect(icon.left, greaterThanOrEqualTo(title.right));
        expect(icon.right, lessThanOrEqualTo(cancel.left));
      }
    });

    testWidgets('on a phone too narrow for one row, filter and sort drop '
        'below Cancel and Add rather than cutting the title short', (
      tester,
    ) async {
      await _open(tester, size: const Size(360, 800));

      final add = tester.getRect(find.byType(FilledButton));
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      final title = tester.getRect(find.text('Add Equipment'));
      expect(cancel.center.dy, moreOrLessEquals(add.center.dy, epsilon: 1));
      expect(title.right, lessThanOrEqualTo(cancel.left));
      for (final icon in [Icons.filter_list, Icons.sort]) {
        final rect = tester.getRect(find.byIcon(icon));
        expect(rect.top, greaterThanOrEqualTo(add.bottom));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tick survives the item being filtered out of view', (
      tester,
    ) async {
      final result = await _open(tester);
      await tester.tap(find.text('Apeks Reg'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(EquipmentPickerSheet)),
      );
      container.read(equipmentPickerFilterProvider.notifier).state =
          const EquipmentPickerFilter(type: EquipmentType.mask);
      await tester.pumpAndSettle();
      expect(find.text('Apeks Reg'), findsNothing);

      await tester.tap(find.text('Frameless Mask'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add 2'));
      await tester.pumpAndSettle();

      expect(result.confirmed?.map((e) => e.id), ['reg', 'mask']);
    });

    testWidgets('the header fits a 320dp phone in French', (tester) async {
      await _open(
        tester,
        size: const Size(320, 640),
        locale: const Locale('fr'),
      );
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The buttons scale down rather than overflow, so no exception alone
      // proves little: check every control is on screen and none overlaps.
      final title = tester.getRect(find.text("Ajouter de l'équipement"));
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Annuler'));
      final add = tester.getRect(find.byType(FilledButton));
      final filter = tester.getRect(find.byIcon(Icons.filter_list));
      final sort = tester.getRect(find.byIcon(Icons.sort));
      for (final rect in [title, cancel, add, filter, sort]) {
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      expect(title.right, lessThanOrEqualTo(cancel.left));
      expect(cancel.right, lessThanOrEqualTo(add.left));
      expect(filter.right, lessThanOrEqualTo(sort.left));
      expect(filter.top, greaterThanOrEqualTo(add.bottom));
    });
  });
}
