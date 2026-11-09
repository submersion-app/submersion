import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// The Add Equipment picker folds its type groups (issue #3364): closed at
/// open except the only group, never saved.
void main() {
  const bcd1 = EquipmentItem(id: 'b1', name: 'Zeagle', type: EquipmentType.bcd);
  const bcd2 = EquipmentItem(
    id: 'b2',
    name: 'Halcyon',
    type: EquipmentType.bcd,
  );
  const tank = EquipmentItem(id: 't1', name: 'Faber', type: EquipmentType.tank);
  const reg = EquipmentItem(
    id: 'r1',
    name: 'Apeks',
    type: EquipmentType.regulator,
  );
  const shared = EquipmentItem(
    id: 's1',
    name: 'Borrowed wing',
    type: EquipmentType.bcd,
    diverId: 'd2',
  );

  Future<void> pumpPicker(
    WidgetTester tester, {
    List<EquipmentItem> gear = const [bcd1, bcd2, tank, reg],
    EquipmentType? typeFilter,
    EquipmentPickerFilter filter = EquipmentPickerFilter.none,
    bool multiSelect = true,
    bool twoDivers = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          activeEquipmentProvider.overrideWith((ref) async => gear),
          equipmentPickerFilterProvider.overrideWith((ref) => filter),
          if (twoDivers) ...[
            hasMultipleDiversProvider.overrideWithValue(true),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
            diverNamesByIdProvider.overrideWith(
              (ref) async => {'d1': 'Me', 'd2': 'Sam'},
            ),
          ],
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentPickerSheet(
              scrollController: ScrollController(),
              selectedEquipmentIds: const {},
              typeFilter: typeFilter,
              onEquipmentSelected: multiSelect ? null : (_) {},
              onEquipmentConfirmed: multiSelect ? (_) {} : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder typeHeader(String foldKey) =>
      find.byKey(ValueKey('equipment-type-fold-$foldKey'));

  testWidgets('groups start closed when nothing is ticked', (tester) async {
    await pumpPicker(tester);
    expect(typeHeader('type:bcd'), findsOneWidget);
    expect(typeHeader('type:tank'), findsOneWidget);
    expect(find.text('Zeagle'), findsNothing);
    expect(find.text('Faber'), findsNothing);
  });

  testWidgets('a caller type filter gives one open group', (tester) async {
    await pumpPicker(tester, typeFilter: EquipmentType.bcd);
    expect(find.text('Zeagle'), findsOneWidget);
    expect(find.text('Halcyon'), findsOneWidget);
  });

  testWidgets('tapping a header opens and closes it', (tester) async {
    await pumpPicker(tester);
    await tester.tap(typeHeader('type:bcd'));
    await tester.pumpAndSettle();
    expect(find.text('Zeagle'), findsOneWidget);

    await tester.tap(typeHeader('type:bcd'));
    await tester.pumpAndSettle();
    expect(find.text('Zeagle'), findsNothing);
  });

  testWidgets('closed header shows N of M selected', (tester) async {
    await pumpPicker(tester);
    await tester.tap(typeHeader('type:bcd'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zeagle'));
    await tester.pumpAndSettle();
    await tester.tap(typeHeader('type:bcd'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 selected'), findsOneWidget);
  });

  testWidgets('an active filter opens every group', (tester) async {
    await pumpPicker(
      tester,
      filter: const EquipmentPickerFilter(status: EquipmentStatus.active),
    );
    expect(find.text('Zeagle'), findsOneWidget);
    expect(find.text('Faber'), findsOneWidget);
  });

  testWidgets('owner sections fold with their types inside', (tester) async {
    await pumpPicker(tester, gear: const [bcd1, tank, shared], twoDivers: true);
    final owner = find.byKey(const ValueKey('equipment-owner-fold-owner:d2'));
    expect(owner, findsOneWidget);
    expect(typeHeader('owner:d2/type:bcd'), findsNothing);

    await tester.tap(owner);
    await tester.pumpAndSettle();
    expect(typeHeader('owner:d2/type:bcd'), findsOneWidget);
    expect(find.text('Borrowed wing'), findsNothing);

    await tester.tap(typeHeader('owner:d2/type:bcd'));
    await tester.pumpAndSettle();
    expect(find.text('Borrowed wing'), findsOneWidget);
  });
}
