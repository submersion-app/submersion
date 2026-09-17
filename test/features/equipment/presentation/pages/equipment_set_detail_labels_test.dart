import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The set detail page labels its members as one list (issue #1549), so two
/// identical items in a set read differently from each other.
void main() {
  EquipmentItem pouch(String id, String serial) => EquipmentItem(
    id: id,
    name: 'Pouches',
    type: EquipmentType.other,
    brand: 'Palantic',
    model: 'Drop-Bottom',
    serialNumber: serial,
  );

  Future<void> pump(WidgetTester tester, List<EquipmentItem> items) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final set = EquipmentSet(
      id: 's1',
      name: 'Cold Water',
      equipmentIds: [for (final item in items) item.id],
      items: items,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentSetProvider.overrideWith((ref, id) async => set),
          equipmentSetGeofencesProvider.overrideWith((ref, id) async => []),
          // Flat, so a type name on screen can only be a row's own subtitle
          // and not a group heading.
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(groupByType: false),
          ),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) => Future.value(ComponentsIndex.fromRows(const [])),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentSetDetailPage(setId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('identical members gain the serial number that differs', (
    tester,
  ) async {
    // Descending serial order, so input order cannot produce the result.
    await pump(tester, [pouch('b', 'X2'), pouch('a', 'X1')]);
    expect(find.text('Palantic Drop-Bottom · S/N X1'), findsOneWidget);
    expect(find.text('Palantic Drop-Bottom · S/N X2'), findsOneWidget);
  });

  testWidgets('a member with nothing to add still names its type', (
    tester,
  ) async {
    await pump(tester, const [
      EquipmentItem(id: 'm', name: 'Blue one', type: EquipmentType.mask),
    ]);
    // No brand, model or identifier: the row falls back to the type name.
    expect(find.text('Blue one'), findsOneWidget);
    expect(find.text('Mask'), findsOneWidget);
  });

  testWidgets('ungrouped, an identifier alone does not push out the type', (
    tester,
  ) async {
    // With no type heading, "ID P2" on its own would not say what the item
    // is; the old brand-or-type subtitle always did.
    await pump(tester, [
      EquipmentItem(
        id: 'm',
        name: 'Blue one',
        type: EquipmentType.mask,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'm',
            key: EquipmentAttrKeys.identifier,
            valueText: 'P2',
          ),
        ],
      ),
    ]);
    expect(find.text('Mask · ID P2'), findsOneWidget);
  });
}
