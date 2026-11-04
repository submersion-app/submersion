import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold Water Reg',
    type: EquipmentType.regulator,
  );
  const first = EquipmentItem(
    id: 'first',
    name: 'DIN First Stage',
    type: EquipmentType.firstStage,
  );
  const second = EquipmentItem(
    id: 'second',
    name: 'Primary Second Stage',
    type: EquipmentType.secondStage,
  );
  const bcd = EquipmentItem(
    id: 'bcd',
    name: 'Hollis SMS75',
    type: EquipmentType.bcd,
  );
  const showLabel = 'Show components of assemblies';

  final t0 = DateTime(2026);
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: '$parent>$child',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    required List<EquipmentItem> members,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final set = EquipmentSet(
      id: 'set-1',
      name: 'Cold set',
      equipmentIds: [for (final m in members) m.id],
      items: members,
      showFigure: false,
      createdAt: t0,
      updatedAt: t0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentSetProvider('set-1').overrideWith((ref) async => set),
          activeEquipmentProvider.overrideWith(
            (ref) async => const [reg, first, second, bcd],
          ),
          allEquipmentProvider.overrideWith(
            (ref) async => const [reg, first, second, bcd],
          ),
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(groupByType: false),
          ),
          equipmentComponentsIndexProvider.overrideWithValue(
            AsyncValue.data(
              ComponentsIndex.fromRows([
                edge('reg', 'first'),
                edge('reg', 'second'),
              ]),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentSetEditPage(setId: 'set-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('components of a listed assembly (#2514)', () {
    testWidgets('wait behind a switch', (tester) async {
      await pumpPage(tester, members: const [bcd]);

      expect(find.text('Cold Water Reg'), findsOneWidget);
      expect(find.text('DIN First Stage'), findsNothing);
      expect(find.text('Primary Second Stage'), findsNothing);

      await tester.tap(find.text(showLabel));
      await tester.pumpAndSettle();

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsOneWidget);
    });

    testWidgets('stay listed when ticked, so they can be unticked', (
      tester,
    ) async {
      await pumpPage(tester, members: const [first]);

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsNothing);
      expect(find.text(showLabel), findsOneWidget);
    });

    testWidgets('stay listed once unticked, so the untick can be undone', (
      tester,
    ) async {
      await pumpPage(tester, members: const [first]);

      await tester.tap(find.text('DIN First Stage'));
      await tester.pumpAndSettle();

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'DIN First Stage'),
            )
            .value,
        isFalse,
      );
      expect(find.text('Primary Second Stage'), findsNothing);
    });
  });
}
