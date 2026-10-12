import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_query_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The default view is the diver's to choose (#2628), so it can hide every
/// item they own; the list must not then invite them to add their first.
///
/// The id-set stand-in reads the configured default, so these tests fail if
/// the list ignores the setting (the shared fake reads the active list).
Future<void> _pump(
  WidgetTester tester,
  List<EquipmentItem> visible, {
  Set<EquipmentStatus> defaults = factoryDefaultEquipmentStatuses,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            AppSettings(equipmentDefaultStatuses: defaults),
          ),
        ),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        allEquipmentProvider.overrideWith((ref) async => visible),
        queryFilteredEquipmentIdsProvider.overrideWith((ref, key) async {
          final f = key.filter;
          final shown = ref.watch(equipmentDefaultStatusesProvider);
          return {
            for (final e in await ref.watch(allEquipmentProvider.future))
              if (f.allStatuses ||
                  (f.status == null
                      ? shown.contains(e.status)
                      : e.status == f.status))
                e.id,
          };
        }),
        equipmentListViewModeProvider.overrideWith(
          (ref) => ListViewMode.detailed,
        ),
      ],
      child: const EquipmentListContent(showAppBar: true),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const spareReg = EquipmentItem(
    id: 'reg',
    name: 'Spare Regulator',
    type: EquipmentType.regulator,
    status: EquipmentStatus.spare,
  );

  testWidgets('a default view hiding owned gear says so and offers it all', (
    tester,
  ) async {
    await _pump(tester, const [spareReg], defaults: {EquipmentStatus.active});
    expect(find.text('No equipment in your default view'), findsOneWidget);
    expect(
      find.text('Your default view hides the rest of your gear.'),
      findsOneWidget,
    );
    expect(find.text('Add Your First Equipment'), findsNothing);
    expect(find.text('Spare Regulator'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('equipment_list_showAll')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EquipmentListContent)),
    );
    expect(container.read(equipmentFilterProvider).allStatuses, isTrue);
    expect(find.text('Spare Regulator'), findsWidgets);
  });

  testWidgets('a default view that includes the status lists the item', (
    tester,
  ) async {
    await _pump(
      tester,
      const [spareReg],
      defaults: {EquipmentStatus.active, EquipmentStatus.spare},
    );
    expect(find.text('Spare Regulator'), findsWidgets);
    expect(find.text('No equipment in your default view'), findsNothing);
  });

  testWidgets('wishlist gear alone is not owned gear: the add prompt stays', (
    tester,
  ) async {
    await _pump(tester, const [
      EquipmentItem(
        id: 'wish',
        name: 'Dream Computer',
        type: EquipmentType.computer,
        status: EquipmentStatus.wanted,
      ),
    ]);
    expect(find.text('No equipment in your default view'), findsNothing);
    expect(find.text('Add Your First Equipment'), findsOneWidget);
  });

  testWidgets('gear shared by another diver is not owned: the add prompt '
      'stays', (tester) async {
    await _pump(
      tester,
      const [
        EquipmentItem(
          id: 'lent',
          name: 'Borrowed Regulator',
          type: EquipmentType.regulator,
          status: EquipmentStatus.spare,
          diverId: 'other',
        ),
      ],
      defaults: {EquipmentStatus.active},
    );
    expect(find.text('No equipment in your default view'), findsNothing);
    expect(find.text('Add Your First Equipment'), findsOneWidget);
  });

  testWidgets('with no gear at all the add prompt stays', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No equipment in your default view'), findsNothing);
    expect(find.text('Add Your First Equipment'), findsOneWidget);
  });
}
