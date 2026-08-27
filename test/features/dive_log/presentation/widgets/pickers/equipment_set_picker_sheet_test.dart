import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _regulator = EquipmentItem(
  id: 'e1',
  name: 'Apeks XTX50',
  type: EquipmentType.regulator,
);
const _mask = EquipmentItem(
  id: 'e2',
  name: 'Low Volume Mask',
  type: EquipmentType.mask,
);

EquipmentSet _set(String id, String name, List<EquipmentItem> items) {
  return EquipmentSet(
    id: id,
    name: name,
    description: '',
    equipmentIds: items.map((e) => e.id).toList(),
    items: items,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<EquipmentSet> sets,
  void Function(EquipmentSet, List<EquipmentItem>)? onSetSelected,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        equipmentSetsProvider.overrideWith((ref) async => sets),
        equipmentSetWithItemsProvider.overrideWith(
          (ref, id) async =>
              sets.where((s) => s.id == id).cast<EquipmentSet?>().firstOrNull,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EquipmentSetPickerSheet(
            scrollController: ScrollController(),
            onSetSelected: onSetSelected ?? (_, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists sets with localized item summaries', (tester) async {
    await _pump(
      tester,
      sets: [
        _set('s1', 'Tropical', [_regulator, _mask]),
        _set('s2', 'Single glove', [_regulator]),
      ],
    );
    expect(find.text('Use Equipment Set'), findsOneWidget);
    expect(find.text('Tropical'), findsOneWidget);
    expect(find.text('2 items: Apeks XTX50, Low Volume Mask'), findsOneWidget);
    expect(find.text('1 item: Apeks XTX50'), findsOneWidget);
  });

  testWidgets('tapping a set returns its items', (tester) async {
    EquipmentSet? pickedSet;
    List<EquipmentItem>? pickedItems;
    await _pump(
      tester,
      sets: [
        _set('s1', 'Tropical', [_regulator, _mask]),
      ],
      onSetSelected: (set, items) {
        pickedSet = set;
        pickedItems = items;
      },
    );
    await tester.tap(find.text('Tropical'));
    expect(pickedSet?.id, 's1');
    expect(pickedItems?.length, 2);
  });

  testWidgets('an empty set is rendered disabled', (tester) async {
    var called = false;
    await _pump(
      tester,
      sets: [_set('s1', 'Empty', const [])],
      onSetSelected: (_, _) => called = true,
    );
    expect(find.text('Empty set'), findsOneWidget);
    await tester.tap(find.text('Empty'));
    expect(called, isFalse);
  });

  testWidgets('shows empty state when no sets exist', (tester) async {
    await _pump(tester, sets: const []);
    expect(find.text('No equipment sets yet'), findsOneWidget);
    expect(find.text('Create sets in Equipment > Sets'), findsOneWidget);
  });

  testWidgets('tile shows the error state when its items fail to load', (
    tester,
  ) async {
    final set = _set('s1', 'Broken', [_regulator]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentSetsProvider.overrideWith((ref) async => [set]),
          equipmentSetWithItemsProvider.overrideWith(
            (ref, id) => Future<EquipmentSet?>.error(Exception('boom')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentSetPickerSheet(
              scrollController: ScrollController(),
              onSetSelected: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Error loading items'), findsOneWidget);
  });

  testWidgets('tile shows the loading state while items resolve', (
    tester,
  ) async {
    final set = _set('s1', 'Slow', [_regulator]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentSetsProvider.overrideWith((ref) async => [set]),
          equipmentSetWithItemsProvider.overrideWith(
            // Never completes: the tile stays in its loading state.
            (ref, id) => Completer<EquipmentSet?>().future,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentSetPickerSheet(
              scrollController: ScrollController(),
              onSetSelected: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Loading...'), findsOneWidget);
  });
}
