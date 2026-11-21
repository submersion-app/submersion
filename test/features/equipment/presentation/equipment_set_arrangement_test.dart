import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

/// Equipment sets list the same gear as a dive does, so they follow the same
/// arrangement (#1486, #1576). The Members editor's groups follow it too:
/// equipment_set_members_editor_test.dart.
void main() {
  const zeagle = EquipmentItem(
    id: 'bcd-1',
    name: 'Zeagle',
    type: EquipmentType.bcd,
  );
  const faber = EquipmentItem(
    id: 'tank-1',
    name: 'Faber',
    type: EquipmentType.tank,
  );
  const apeks = EquipmentItem(
    id: 'reg-1',
    name: 'Apeks',
    type: EquipmentType.regulator,
  );

  final set = EquipmentSet(
    id: 'set-1',
    diverId: 'diver-1',
    name: 'Cold Water',
    equipmentIds: const ['bcd-1', 'tank-1', 'reg-1'],
    items: const [zeagle, faber, apeks],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    required EquipmentArrangement arrangement,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentSetProvider('set-1').overrideWith((ref) async => set),
          activeEquipmentProvider.overrideWith(
            (ref) async => const [zeagle, faber, apeks],
          ),
          allEquipmentProvider.overrideWith(
            (ref) async => const [zeagle, faber, apeks],
          ),
          equipmentArrangementProvider.overrideWithValue(arrangement),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The set detail page keeps plain headings.
  List<EquipmentType> detailHeaders(WidgetTester tester) => tester
      .widgetList<EquipmentGroupHeader>(find.byType(EquipmentGroupHeader))
      .map((h) => h.type)
      .toList();

  testWidgets('set detail groups its members in the chosen type order', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const EquipmentSetDetailPage(setId: 'set-1'),
      arrangement: EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
    );

    expect(detailHeaders(tester), [
      EquipmentType.tank,
      EquipmentType.regulator,
      EquipmentType.bcd,
    ]);
  });
}
