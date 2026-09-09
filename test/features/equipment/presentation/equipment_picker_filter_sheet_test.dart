import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_picker_filter_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Captures what the sheet resolves to, which a plain return value cannot:
/// the button's onPressed is async, so the helper returns before the sheet
/// has closed.
class _Result {
  EquipmentPickerFilter? filter;
  bool returned = false;
}

void main() {
  Future<_Result> openSheet(
    WidgetTester tester, {
    EquipmentPickerFilter current = EquipmentPickerFilter.none,
    List<EquipmentType> types = const [
      EquipmentType.regulator,
      EquipmentType.tank,
    ],
    List<EquipmentStatus> statuses = const [
      EquipmentStatus.active,
      EquipmentStatus.loaned,
    ],
  }) async {
    final result = _Result();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result.filter = await showEquipmentPickerFilterSheet(
                  context,
                  current: current,
                  availableTypes: types,
                  availableStatuses: statuses,
                );
                result.returned = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('applying a type chip returns that filter', (tester) async {
    final result = await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('picker_filter_type_tank')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('picker_filter_apply')));
    await tester.pumpAndSettle();

    expect(result.returned, isTrue);
    expect(
      result.filter,
      const EquipmentPickerFilter(type: EquipmentType.tank),
    );
  });

  testWidgets('applying both axes returns both', (tester) async {
    final result = await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('picker_filter_status_loaned')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('picker_filter_type_tank')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('picker_filter_apply')));
    await tester.pumpAndSettle();

    expect(
      result.filter,
      const EquipmentPickerFilter(
        status: EquipmentStatus.loaned,
        type: EquipmentType.tank,
      ),
    );
  });

  testWidgets('cancelling returns null so the caller keeps its filter', (
    tester,
  ) async {
    final result = await openSheet(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result.returned, isTrue);
    expect(result.filter, isNull);
  });

  testWidgets('only the offered types and statuses get chips', (tester) async {
    await openSheet(
      tester,
      types: const [EquipmentType.tank],
      statuses: const [EquipmentStatus.active],
    );

    expect(
      find.byKey(const ValueKey('picker_filter_type_tank')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('picker_filter_type_regulator')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('picker_filter_status_loaned')),
      findsNothing,
    );
  });

  testWidgets('clear all deselects both axes without closing the sheet', (
    tester,
  ) async {
    await openSheet(
      tester,
      current: const EquipmentPickerFilter(
        status: EquipmentStatus.loaned,
        type: EquipmentType.tank,
      ),
    );

    final tankChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('picker_filter_type_tank')),
    );
    expect(tankChip.selected, isTrue);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('picker_filter_type_tank')),
          )
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('picker_filter_status_loaned')),
          )
          .selected,
      isFalse,
    );
    // Still open: clearing edits the draft, it does not apply.
    expect(find.byKey(const ValueKey('picker_filter_apply')), findsOneWidget);
  });

  testWidgets('the filter header survives a narrow phone in French', (
    tester,
  ) async {
    // Title plus a translated Clear All action on one row.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEquipmentPickerFilterSheet(
                context,
                current: EquipmentPickerFilter.none,
                availableTypes: const [EquipmentType.tank],
                availableStatuses: const [EquipmentStatus.active],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
