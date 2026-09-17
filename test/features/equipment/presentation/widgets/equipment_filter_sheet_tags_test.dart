import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_filter_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _SheetLauncher extends ConsumerWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showEquipmentFilterSheet(context, ref),
          child: const Text('open'),
        ),
      ),
    );
  }
}

/// The Tags group of the equipment filter panel (issue #1942).
void main() {
  final now = DateTime(2026);
  final travel = Tag(
    id: 't1',
    name: 'Travel kit',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.equipment},
  );
  final night = Tag(
    id: 'd1',
    name: 'Night',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.dives},
  );

  Future<ProviderContainer> open(
    WidgetTester tester, {
    required List<Tag> tags,
    EquipmentFilterState filter = const EquipmentFilterState(),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        allEquipmentProvider.overrideWith(
          (ref) async => const [
            EquipmentItem(id: 'e1', name: 'Wing', type: EquipmentType.bcd),
          ],
        ),
        equipmentFilterProvider.overrideWith((ref) => filter),
        tagsProvider.overrideWith((ref) async => tags),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _SheetLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  final travelChip = find.byKey(const ValueKey('equipment_filter_tag_t1'));

  testWidgets('lists equipment tags only; Apply writes the picked ones', (
    tester,
  ) async {
    final container = await open(tester, tags: [night, travel]);

    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Night'), findsNothing);
    await tester.ensureVisible(travelChip);
    await tester.tap(travelChip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
    await tester.pumpAndSettle();

    expect(container.read(equipmentFilterProvider).tagIds, {'t1'});
  });

  testWidgets('opens with the tags in force; Clear All empties them', (
    tester,
  ) async {
    final container = await open(
      tester,
      tags: [travel],
      filter: const EquipmentFilterState(tagIds: {'t1'}),
    );

    await tester.ensureVisible(travelChip);
    expect(tester.widget<FilterChip>(travelChip).selected, isTrue);
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
    await tester.pumpAndSettle();

    expect(container.read(equipmentFilterProvider).tagIds, isEmpty);
  });

  testWidgets('no equipment tags hides the group', (tester) async {
    await open(tester, tags: [night]);

    expect(find.text('Tags'), findsNothing);
  });
}
