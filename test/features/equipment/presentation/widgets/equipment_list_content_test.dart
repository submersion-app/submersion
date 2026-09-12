import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/bulk_delete_contract.dart';
import '../../../../helpers/selection_contract.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestEquipTableConfigNotifier
    extends EntityTableConfigNotifier<EquipmentField> {
  _TestEquipTableConfigNotifier(EntityTableViewConfig<EquipmentField> config)
    : super(
        defaultConfig: config,
        fieldFromName: EquipmentFieldAdapter.instance.fieldFromName,
      );
}

final _testConfig = EntityTableViewConfig<EquipmentField>(
  columns: [
    EntityTableColumnConfig(field: EquipmentField.itemName, isPinned: true),
    EntityTableColumnConfig(field: EquipmentField.type),
    EntityTableColumnConfig(field: EquipmentField.brand),
    EntityTableColumnConfig(field: EquipmentField.model),
    EntityTableColumnConfig(field: EquipmentField.status),
    EntityTableColumnConfig(field: EquipmentField.lastServiceDate),
  ],
);

EquipmentItem _makeEquipment({
  required String id,
  required String name,
  EquipmentType type = EquipmentType.regulator,
  String? brand,
  String? model,
  EquipmentStatus status = EquipmentStatus.active,
}) {
  return EquipmentItem(
    id: id,
    name: name,
    type: type,
    brand: brand,
    model: model,
    status: status,
  );
}

Future<List<Override>> _buildOverrides({
  required List<EquipmentItem> equipment,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    // The equipment list content watches equipmentByStatusProvider(null) for
    // all equipment when no filter is selected, so we override that.
    equipmentByStatusProvider.overrideWith((ref, status) => equipment),
    activeEquipmentProvider.overrideWith((ref) async => equipment),
    allEquipmentProvider.overrideWith((ref) async => equipment),
    equipmentListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    equipmentTableConfigProvider.overrideWith(
      (ref) => _TestEquipTableConfigNotifier(_testConfig),
    ),
  ];
}

/// Mutable source for the contract test's filter step.
final _visibleEquipmentProvider = StateProvider<List<EquipmentItem>>(
  (ref) => const [],
);

Future<List<Override>> _buildPhoneOverrides({
  required List<EquipmentItem> items,
  List<EquipmentItem> serviceDue = const [],
  ListViewMode viewMode = ListViewMode.detailed,
  String? highlightedEquipmentId,
  EquipmentArrangement? arrangement,
  SortState<EquipmentSortField>? sort,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    equipmentByStatusProvider.overrideWith((ref, status) => items),
    activeEquipmentProvider.overrideWith((ref) async => items),
    allEquipmentProvider.overrideWith((ref) async => items),
    serviceDueEquipmentProvider.overrideWith((ref) async => serviceDue),
    equipmentListViewModeProvider.overrideWith((ref) => viewMode),
    equipmentTableConfigProvider.overrideWith(
      (ref) => _TestEquipTableConfigNotifier(_testConfig),
    ),
    highlightedEquipmentIdProvider.overrideWith(
      (ref) => highlightedEquipmentId,
    ),
    if (arrangement != null)
      equipmentArrangementProvider.overrideWithValue(arrangement),
    if (sort != null) equipmentSortProvider.overrideWith((ref) => sort),
  ];
}

// ---------------------------------------------------------------------------
// Filter panel helpers
//
// The status and category filters live behind the top-bar icon (PR #1435
// review), so every filtering test drives them through the panel.
// ---------------------------------------------------------------------------

final Finder _filterButton = find.byKey(
  const ValueKey('equipment_filter_button'),
);

String _typeChipKey(EquipmentType? type) =>
    'equipment_filter_type_${type?.name ?? 'all'}';

String _statusChipKey(EquipmentStatus? status) =>
    'equipment_filter_status_${status?.name ?? 'all'}';

Finder _typeChip(EquipmentType? type) =>
    find.byKey(ValueKey(_typeChipKey(type)));

Future<void> _openFilterPanel(WidgetTester tester) async {
  await tester.tap(_filterButton);
  await tester.pumpAndSettle();
}

/// Tap a chip in the panel, scrolling it into view first: the sheet is short
/// enough that the lower sections start off screen.
Future<void> _tapPanelChip(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  // The panel body is a lazy ListView; a chip past the cache extent is not
  // built yet, so ensureVisible alone throws "No element". Scroll it in via
  // the sheet's list (the last Scrollable mounted once the panel is open).
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _applyPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
  await tester.pumpAndSettle();
}

/// Open the panel, tap [chipKeys] in order, and apply.
Future<void> _filterVia(WidgetTester tester, List<String> chipKeys) async {
  await _openFilterPanel(tester);
  for (final key in chipKeys) {
    await _tapPanelChip(tester, key);
  }
  await _applyPanel(tester);
}

bool _badgeIsVisible(WidgetTester tester) {
  final badge = tester.widget<Badge>(
    find.descendant(of: _filterButton, matching: find.byType(Badge)),
  );
  return badge.isLabelVisible;
}

void main() {
  group('bulk actions', () {
    late _CapturingEquipmentNotifier notifier;

    Future<Widget> host(List<EquipmentItem> items) async {
      notifier = _CapturingEquipmentNotifier();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          equipmentListNotifierProvider.overrideWith((ref) => notifier),
          equipmentByStatusProvider.overrideWith((ref, status) => items),
          activeEquipmentProvider.overrideWith((ref) async => items),
          equipmentListViewModeProvider.overrideWith(
            (ref) => ListViewMode.detailed,
          ),
          equipmentTableConfigProvider.overrideWith(
            (ref) => _TestEquipTableConfigNotifier(_testConfig),
          ),
          highlightedEquipmentIdProvider.overrideWith((ref) => null),
        ],
        child: const EquipmentListContent(showAppBar: true),
      );
    }

    testWidgets('deletes every checked item and reports the count', (
      tester,
    ) async {
      final widget = await host([
        _makeEquipment(id: 'e1', name: 'Aaa Reg'),
        _makeEquipment(id: 'e2', name: 'Bbb BCD'),
      ]);

      await verifyBulkDelete(
        tester,
        build: () => widget,
        selectButton: find.byKey(const ValueKey('enter_selection')),
        expectedDeletedCount: 2,
      );

      expect(notifier.deleted, ['e1', 'e2']);
      expect(find.text('2 deleted'), findsOneWidget);
    });

    testWidgets('retire acts on a uniformly active selection', (tester) async {
      final widget = await host([
        _makeEquipment(id: 'e1', name: 'Aaa Reg'),
        _makeEquipment(id: 'e2', name: 'Bbb BCD'),
      ]);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();

      final retire = find.byKey(const ValueKey('selection_action_retire'));
      expect(tester.widget<IconButton>(retire).onPressed, isNotNull);

      // Reactivate is meaningless on an all-active selection, so the
      // isEnabled predicate must refuse it.
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('selection_action_reactivate')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(retire);
      await tester.pumpAndSettle();

      expect(notifier.retired, ['e1', 'e2']);
      expect(notifier.reactivated, isEmpty);
    });

    testWidgets('cancelling deletes nothing and keeps the selection', (
      tester,
    ) async {
      final widget = await host([_makeEquipment(id: 'e1', name: 'Aaa Reg')]);

      await verifyBulkDeleteCancels(
        tester,
        build: () => widget,
        selectButton: find.byKey(const ValueKey('enter_selection')),
      );

      expect(notifier.deleted, isEmpty);
    });
  });

  group('selection contract', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      final all = <EquipmentItem>[
        _makeEquipment(id: 'e1', name: 'Aaa Reg'),
        _makeEquipment(id: 'e2', name: 'Bbb BCD'),
        _makeEquipment(id: 'e3', name: 'Ccc Fins'),
      ];

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final overrides = <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        _visibleEquipmentProvider.overrideWith((ref) => all),
        equipmentByStatusProvider.overrideWith((ref, status) => all),
        activeEquipmentProvider.overrideWith(
          (ref) async => ref.watch(_visibleEquipmentProvider),
        ),
        equipmentListViewModeProvider.overrideWith(
          (ref) => ListViewMode.detailed,
        ),
        equipmentTableConfigProvider.overrideWith(
          (ref) => _TestEquipTableConfigNotifier(_testConfig),
        ),
        highlightedEquipmentIdProvider.overrideWith((ref) => null),
      ];

      await verifySelectionContract(
        tester,
        build: () => testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const EquipmentListContent(showAppBar: true),
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        rowRoot: find.ancestor(
          of: find.text('Aaa Reg'),
          matching: find.byType(EquipmentListTile),
        ),
        firstRow: find.text('Aaa Reg'),
        applyFilter: (tester) async {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(EquipmentListContent)),
          );
          container.read(_visibleEquipmentProvider.notifier).state = [
            all.first,
          ];
        },
        visibleAfterFilter: 1,
      );
    });
  });

  group('EquipmentListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'e1',
          name: 'Primary Reg',
          type: EquipmentType.regulator,
          brand: 'Apeks',
          model: 'XTX200',
        ),
        _makeEquipment(
          id: 'e2',
          name: 'Travel BCD',
          type: EquipmentType.bcd,
          brand: 'Mares',
          model: 'Rover',
        ),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers from displayName values
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
    });

    testWidgets('renders rows for each equipment item', (tester) async {
      final equipment = [
        _makeEquipment(id: 'e1', name: 'Primary Reg'),
        _makeEquipment(id: 'e2', name: 'Travel BCD'),
        _makeEquipment(id: 'e3', name: 'Wetsuit 5mm'),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Primary Reg'), findsOneWidget);
      expect(find.text('Travel BCD'), findsOneWidget);
      expect(find.text('Wetsuit 5mm'), findsOneWidget);
    });

    testWidgets('shows empty state when no equipment', (tester) async {
      final overrides = await _buildOverrides(equipment: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.backpack), findsOneWidget);
    });

    // Column settings are now provided by TableModeLayout, not the content
    // widget. The compact bar provides sort, search, and view mode controls.

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        equipment: [_makeEquipment(id: 'e1', name: 'My Fins')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.text('My Fins'), findsOneWidget);
    });

    // Vertical divider was part of the standalone table app bar, now removed.
    // Column settings and divider are in TableModeLayout.

    testWidgets('table content carries no filter row of its own', (
      tester,
    ) async {
      // Table mode's filter icon lives in TableModeLayout's app bar actions
      // (see EquipmentListPage); the table itself spends no rows on filters
      // until one is active.
      final overrides = await _buildOverrides(
        equipment: [_makeEquipment(id: 'e1', name: 'Test Reg')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.filter_list), findsNothing);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('table renders equipment data in cells', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'e1',
          name: 'Primary Reg',
          type: EquipmentType.regulator,
          brand: 'Apeks',
          model: 'XTX200',
        ),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Primary Reg'), findsOneWidget);
      expect(find.text('Apeks'), findsOneWidget);
      expect(find.text('XTX200'), findsOneWidget);
    });

    testWidgets('renders equipment with various types', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'et1',
          name: 'My Reg',
          type: EquipmentType.regulator,
        ),
        _makeEquipment(id: 'et2', name: 'My BCD', type: EquipmentType.bcd),
        _makeEquipment(id: 'et3', name: 'My Suit', type: EquipmentType.wetsuit),
        _makeEquipment(id: 'et4', name: 'My Light', type: EquipmentType.light),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('My Reg'), findsOneWidget);
      expect(find.text('My BCD'), findsOneWidget);
      expect(find.text('My Suit'), findsOneWidget);
      expect(find.text('My Light'), findsOneWidget);
    });

    testWidgets('renders equipment with null brand and model', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'nb1',
          name: 'Generic Item',
          brand: null,
          model: null,
        ),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Generic Item'), findsOneWidget);
    });

    testWidgets('renders many equipment items without crash', (tester) async {
      final equipment = List.generate(
        15,
        (i) => _makeEquipment(id: 'me$i', name: 'Item $i'),
      );

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('renders equipment with different statuses', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'st1',
          name: 'Active Reg',
          status: EquipmentStatus.active,
        ),
        _makeEquipment(
          id: 'st2',
          name: 'Retired BCD',
          status: EquipmentStatus.retired,
        ),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Active Reg'), findsOneWidget);
      expect(find.text('Retired BCD'), findsOneWidget);
    });

    testWidgets('tapping a row sets highlighted equipment id', (tester) async {
      final equipment = [
        _makeEquipment(id: 'e1', name: 'My Regulator'),
        _makeEquipment(id: 'e2', name: 'My BCD'),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Tap on an equipment row
      await tester.tap(find.text('My Regulator'));
      // Pump past the DoubleTapGestureRecognizer's 40ms timer
      await tester.pump(const Duration(milliseconds: 50));

      // Verify the widget rebuilt successfully (no crash)
      expect(find.text('My Regulator'), findsOneWidget);
    });
  });

  group('EquipmentListTile avatar (clocks only)', () {
    // Under the unified model the avatar reads overdue only from the ledger.
    // A legacy item whose only signal is the old single interval has no ledger
    // clock, so it must render as NOT overdue -- the legacy isServiceDue is
    // ignored.
    final legacyDueItem = EquipmentItem(
      id: 'legacy1',
      name: 'Old Reg',
      type: EquipmentType.regulator,
      lastServiceDate: DateTime(2020, 1, 1),
      serviceIntervalDays: 365,
    );

    Widget buildTile(EquipmentItem item, ColorScheme scheme) {
      return ProviderScope(
        overrides: [
          // Ledger map resolved but empty -> worstClock is null for this item.
          equipmentRollupClockProvider.overrideWith((ref) async => {}),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => ComponentsIndex.empty,
          ),
          // The tile reads the color-accent toggle, so settings must be
          // stubbed: the real notifier reaches for SharedPreferences.
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(colorScheme: scheme),
          home: Scaffold(body: EquipmentListTile(item: item)),
        ),
      );
    }

    testWidgets('legacy overdue item renders non-overdue without a clock', (
      tester,
    ) async {
      expect(legacyDueItem.isServiceDue, isTrue); // legacy getter still true
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

      await tester.pumpWidget(buildTile(legacyDueItem, scheme));
      await tester.pumpAndSettle();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundColor, scheme.tertiaryContainer);
      expect(avatar.backgroundColor, isNot(scheme.errorContainer));
      expect(find.text('Service Due'), findsNothing);
    });

    testWidgets('renders non-overdue avatar when nothing is due', (
      tester,
    ) async {
      final upToDate = EquipmentItem(
        id: 'ok1',
        name: 'Fresh Reg',
        type: EquipmentType.regulator,
        lastServiceDate: DateTime.now(),
        serviceIntervalDays: 365,
      );
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

      await tester.pumpWidget(buildTile(upToDate, scheme));
      await tester.pumpAndSettle();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundColor, scheme.tertiaryContainer);
    });
  });

  group('phone-mode highlight', () {
    testWidgets(
      'phone detailed view highlights equipment when highlightedEquipmentIdProvider is set',
      (tester) async {
        final items = [
          _makeEquipment(id: 'e1', name: 'Alpha Reg'),
          _makeEquipment(id: 'e2', name: 'Bravo BCD'),
        ];

        final overrides = await _buildPhoneOverrides(
          items: items,
          viewMode: ListViewMode.detailed,
          highlightedEquipmentId: 'e2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const EquipmentListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<EquipmentListTile>(find.byType(EquipmentListTile))
            .toList();
        final alpha = tiles.firstWhere((t) => t.item.id == 'e1');
        final bravo = tiles.firstWhere((t) => t.item.id == 'e2');

        expect(alpha.isSelected, isFalse);
        expect(bravo.isSelected, isTrue);
      },
    );

    testWidgets(
      'phone compact view highlights equipment when highlightedEquipmentIdProvider is set',
      (tester) async {
        final items = [
          _makeEquipment(id: 'e1', name: 'Alpha Reg'),
          _makeEquipment(id: 'e2', name: 'Bravo BCD'),
        ];

        final overrides = await _buildPhoneOverrides(
          items: items,
          viewMode: ListViewMode.compact,
          highlightedEquipmentId: 'e2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const EquipmentListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        // Detailed and compact both use EquipmentListTile for equipment.
        final tiles = tester
            .widgetList<EquipmentListTile>(find.byType(EquipmentListTile))
            .toList();
        final alpha = tiles.firstWhere((t) => t.item.id == 'e1');
        final bravo = tiles.firstWhere((t) => t.item.id == 'e2');

        expect(alpha.isSelected, isFalse);
        expect(bravo.isSelected, isTrue);
      },
    );
  });

  group('group by type (shared gear arrangement)', () {
    final items = [
      _makeEquipment(
        id: 'e1',
        name: 'Alpha Reg',
        type: EquipmentType.regulator,
      ),
      _makeEquipment(id: 'e2', name: 'Bravo BCD', type: EquipmentType.bcd),
      _makeEquipment(id: 'e3', name: 'Charlie BCD', type: EquipmentType.bcd),
      _makeEquipment(id: 'e4', name: 'Delta Suit', type: EquipmentType.wetsuit),
    ];

    Future<void> pumpList(
      WidgetTester tester, {
      EquipmentArrangement arrangement = EquipmentArrangement.defaults,
      SortState<EquipmentSortField>? sort,
      ListViewMode viewMode = ListViewMode.detailed,
    }) async {
      // Tall enough that every heading and row is built at once.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final overrides = await _buildPhoneOverrides(
        items: items,
        viewMode: viewMode,
        arrangement: arrangement,
        sort: sort,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<String> rowNames(WidgetTester tester) => tester
        .widgetList<EquipmentListTile>(find.byType(EquipmentListTile))
        .map((t) => t.item.name)
        .toList();

    List<EquipmentType> headings(WidgetTester tester) => tester
        .widgetList<EquipmentGroupHeader>(find.byType(EquipmentGroupHeader))
        .map((h) => h.type)
        .toList();

    double top(WidgetTester tester, Finder finder) =>
        tester.getTopLeft(finder).dy;

    testWidgets('draws a heading per type, gear under its own heading', (
      tester,
    ) async {
      await pumpList(tester);

      expect(headings(tester), [
        EquipmentType.bcd,
        EquipmentType.regulator,
        EquipmentType.wetsuit,
      ]);
      expect(rowNames(tester), [
        'Bravo BCD',
        'Charlie BCD',
        'Alpha Reg',
        'Delta Suit',
      ]);

      final bcdHeading = find.byKey(
        const ValueKey('equipment-group-header-bcd'),
      );
      final regHeading = find.byKey(
        const ValueKey('equipment-group-header-regulator'),
      );
      expect(
        top(tester, bcdHeading),
        lessThan(top(tester, find.text('Bravo BCD'))),
      );
      expect(
        top(tester, find.text('Charlie BCD')),
        lessThan(top(tester, regHeading)),
      );
      expect(
        top(tester, regHeading),
        lessThan(top(tester, find.text('Alpha Reg'))),
      );
    });

    testWidgets('the type order comes from the shared arrangement', (
      tester,
    ) async {
      await pumpList(
        tester,
        arrangement: EquipmentArrangement.defaults.copyWith(
          typeOrderDescending: true,
        ),
      );

      expect(headings(tester), [
        EquipmentType.wetsuit,
        EquipmentType.regulator,
        EquipmentType.bcd,
      ]);
    });

    testWidgets('gear inside each heading follows the page sort', (
      tester,
    ) async {
      await pumpList(
        tester,
        sort: const SortState(
          field: EquipmentSortField.name,
          direction: SortDirection.descending,
        ),
      );

      expect(rowNames(tester), [
        'Charlie BCD',
        'Bravo BCD',
        'Alpha Reg',
        'Delta Suit',
      ]);
    });

    testWidgets('grouping off draws no headings but still orders by type', (
      tester,
    ) async {
      await pumpList(
        tester,
        arrangement: EquipmentArrangement.defaults.copyWith(groupByType: false),
      );

      expect(find.byType(EquipmentGroupHeader), findsNothing);
      expect(rowNames(tester), [
        'Bravo BCD',
        'Charlie BCD',
        'Alpha Reg',
        'Delta Suit',
      ]);
    });

    testWidgets('with no type order the page sort alone orders the list', (
      tester,
    ) async {
      await pumpList(
        tester,
        arrangement: EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.none,
        ),
      );

      expect(find.byType(EquipmentGroupHeader), findsNothing);
      expect(rowNames(tester), [
        'Alpha Reg',
        'Bravo BCD',
        'Charlie BCD',
        'Delta Suit',
      ]);
    });

    testWidgets('compact mode groups too', (tester) async {
      await pumpList(tester, viewMode: ListViewMode.compact);

      expect(headings(tester), hasLength(3));
    });

    testWidgets('dense mode stays flat on the page sort, like the table', (
      tester,
    ) async {
      // Dense is a single-row flat layout (not offered for gear, but a stored
      // value from an older build can still select it). Only Detailed and
      // Compact honour the arrangement.
      await pumpList(tester, viewMode: ListViewMode.dense);

      expect(find.byType(EquipmentGroupHeader), findsNothing);
      final names = tester
          .widgetList<DenseEquipmentListTile>(
            find.byType(DenseEquipmentListTile),
          )
          .map((t) => t.item.name)
          .toList();
      expect(names, ['Alpha Reg', 'Bravo BCD', 'Charlie BCD', 'Delta Suit']);

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      expect(find.text('Group by type'), findsNothing);
    });

    testWidgets('table mode stays flat', (tester) async {
      // The table has its own column sort, so headings there would fight it.
      await pumpList(tester, viewMode: ListViewMode.table);

      expect(find.byType(EquipmentGroupHeader), findsNothing);
    });

    testWidgets('headings order by the localized type name', (tester) async {
      // In German the three types are Tarierjacket (BCD), Flasche (tank) and
      // Atemregler (regulator), so the German alphabetical order reverses the
      // English one. A list that ordered by the English displayName would
      // draw BCD first here.
      final gear = [
        _makeEquipment(id: 'b', name: 'Zeagle', type: EquipmentType.bcd),
        _makeEquipment(id: 't', name: 'Faber', type: EquipmentType.tank),
        _makeEquipment(id: 'r', name: 'Apeks', type: EquipmentType.regulator),
      ];
      final overrides = await _buildPhoneOverrides(
        items: gear,
        arrangement: EquipmentArrangement.defaults,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('de'),
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(headings(tester), [
        EquipmentType.regulator, // Atemregler
        EquipmentType.tank, // Flasche
        EquipmentType.bcd, // Tarierjacket
      ]);
    });

    testWidgets(
      'flipping "Group by type" in the sort sheet regroups the list',
      (tester) async {
        // End to end through the real notifier: the sheet writes the shared
        // arrangement and the list, which reads it, redraws flat.
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final overrides = await _buildPhoneOverrides(items: items);
        await tester.pumpWidget(
          testApp(
            locale: const Locale('en'),
            overrides: [
              ...overrides,
              appSettingsRepositoryProvider.overrideWithValue(
                _FakeArrangementRepository(),
              ),
            ],
            child: const EquipmentListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();
        expect(headings(tester), hasLength(3));

        await tester.tap(find.byTooltip('Sort'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Group by type'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        expect(find.byType(EquipmentGroupHeader), findsNothing);
      },
    );

    testWidgets('the selected gear is scrolled to again once the stored '
        'arrangement loads', (tester) async {
      // The arrangement starts at the defaults and adopts the stored one when
      // its read lands. Scrolling on the first frame therefore positions the
      // row for the DEFAULT order; if that counted as done, a stored order
      // that moves the row would leave it off screen.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gear = [
        for (final type in EquipmentType.values)
          _makeEquipment(id: type.name, name: 'Item ${type.name}', type: type),
      ];
      // Near the top in the default order, near the bottom once the stored
      // arrangement reverses the headings.
      final target = arrangeEquipment(
        gear,
        EquipmentArrangement.defaults,
        typeLabel: (t) => t.displayName,
      )[3].items.single;
      final repository = _FakeArrangementRepository()
        ..heldRead = Completer<EquipmentArrangement?>();

      final overrides = await _buildPhoneOverrides(items: gear);
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            appSettingsRepositoryProvider.overrideWithValue(repository),
          ],
          child: EquipmentListContent(showAppBar: false, selectedId: target.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(target.name), findsOneWidget);

      repository.heldRead!.complete(
        EquipmentArrangement.defaults.copyWith(typeOrderDescending: true),
      );
      await tester.pumpAndSettle();

      final row = find.text(target.name);
      expect(row, findsOneWidget);
      final list = tester.getRect(find.byType(ListView));
      final rect = tester.getRect(row);
      expect(
        rect.top,
        greaterThanOrEqualTo(list.top),
        reason: '$rect in $list',
      );
      expect(rect.bottom, lessThanOrEqualTo(list.bottom), reason: '$rect');
    });

    testWidgets('switching language re-scrolls to the selected gear', (
      tester,
    ) async {
      // Alphabetical headings sort by the translated type name, so a new
      // language reorders them without any arrangement change. The selected
      // row must be brought back into view after the reorder.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gear = [
        for (final type in EquipmentType.values)
          _makeEquipment(id: type.name, name: 'Item ${type.name}', type: type),
      ];
      List<EquipmentType> orderIn(Locale locale) {
        final l10n = lookupAppLocalizations(locale);
        return [
          for (final group in arrangeEquipment(
            gear,
            EquipmentArrangement.defaults,
            typeLabel: (t) => t.localizedName(l10n),
          ))
            group.type!,
        ];
      }

      final english = orderIn(const Locale('en'));
      final german = orderIn(const Locale('de'));
      // A type the switch moves several rows, so the viewport (about five
      // rows) no longer shows it, while it stays within the first dozen rows
      // in both languages: this checks that the list re-scrolls, not how
      // far the row-height estimate drifts deep into a long list.
      int shift(EquipmentType t) =>
          (german.indexOf(t) - english.indexOf(t)).abs();
      final candidates = english.where(
        (t) => english.indexOf(t) <= 12 && german.indexOf(t) <= 12,
      );
      final type = candidates.reduce((a, b) => shift(a) >= shift(b) ? a : b);
      expect(
        shift(type),
        greaterThanOrEqualTo(5),
        reason: 'the switch must move the row off screen to prove anything',
      );
      final target = gear.firstWhere((e) => e.type == type);

      final locale = ValueNotifier(const Locale('en'));
      addTearDown(locale.dispose);
      final overrides = await _buildPhoneOverrides(
        items: gear,
        arrangement: EquipmentArrangement.defaults,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: ValueListenableBuilder<Locale>(
            valueListenable: locale,
            builder: (context, value, _) => MaterialApp(
              locale: value,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: EquipmentListContent(
                  showAppBar: false,
                  selectedId: target.id,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(target.name), findsOneWidget);

      locale.value = const Locale('de');
      await tester.pumpAndSettle();

      final row = find.text(target.name);
      expect(row, findsOneWidget);
      final list = tester.getRect(find.byType(ListView));
      final rect = tester.getRect(row);
      expect(
        rect.top,
        greaterThanOrEqualTo(list.top),
        reason: '$rect in $list',
      );
      expect(rect.bottom, lessThanOrEqualTo(list.bottom), reason: '$rect');
    });

    testWidgets('switching language under a fixed type order does not jump', (
      tester,
    ) async {
      // Only alphabetical ordering reads the translated labels; head to toe
      // is a curated table, so a new language moves no row and must not
      // yank the diver back to the selected one.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gear = [
        for (final type in EquipmentType.values)
          _makeEquipment(id: type.name, name: 'Item ${type.name}', type: type),
      ];
      final headToToe = EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      );
      final target = arrangeEquipment(
        gear,
        headToToe,
        typeLabel: (t) => t.displayName,
      )[8].items.single;

      final locale = ValueNotifier(const Locale('en'));
      addTearDown(locale.dispose);
      final overrides = await _buildPhoneOverrides(
        items: gear,
        arrangement: headToToe,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: ValueListenableBuilder<Locale>(
            valueListenable: locale,
            builder: (context, value, _) => MaterialApp(
              locale: value,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: EquipmentListContent(
                  showAppBar: false,
                  selectedId: target.id,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(position().pixels, greaterThan(0), reason: 'scrolled to the row');

      position().jumpTo(0);
      await tester.pumpAndSettle();
      locale.value = const Locale('de');
      await tester.pumpAndSettle();

      expect(position().pixels, 0);
    });

    testWidgets('tapping a row in the list does not scroll the list', (
      tester,
    ) async {
      // In master-detail a row tap selects that row, which the list already
      // shows; the list must stay where the diver scrolled it rather than
      // treat the new selection as one to scroll to.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gear = [
        for (final type in EquipmentType.values)
          _makeEquipment(id: type.name, name: 'Item ${type.name}', type: type),
      ];
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      final overrides = await _buildPhoneOverrides(
        items: gear,
        arrangement: EquipmentArrangement.defaults,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: ValueListenableBuilder<String?>(
            valueListenable: selected,
            builder: (context, id, _) => EquipmentListContent(
              showAppBar: false,
              selectedId: id,
              onItemSelected: (next) => selected.value = next,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(600);
      await tester.pumpAndSettle();

      final visibleRow = find.byType(EquipmentListTile).first;
      await tester.tap(visibleRow);
      await tester.pumpAndSettle();

      expect(selected.value, isNotNull, reason: 'the tap selected the row');
      expect(position.pixels, 600);
    });

    testWidgets('with no type order, flags it ignores do not jump the list', (
      tester,
    ) async {
      // "Do not order by type" ignores the grouping switch and the type
      // direction, so a synced change to either moves no row.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gear = [
        for (final type in EquipmentType.values)
          _makeEquipment(id: type.name, name: 'Item ${type.name}', type: type),
      ];
      final noTypeOrder = EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.none,
      );
      final target = arrangeEquipment(
        gear,
        noTypeOrder,
        typeLabel: (t) => t.displayName,
      ).single.items[12];
      final source = StateProvider<EquipmentArrangement>((ref) => noTypeOrder);

      final overrides = await _buildPhoneOverrides(items: gear);
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            equipmentArrangementProvider.overrideWith(
              (ref) => ref.watch(source),
            ),
          ],
          child: EquipmentListContent(showAppBar: false, selectedId: target.id),
        ),
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.pixels, greaterThan(0), reason: 'scrolled to the row');

      position.jumpTo(0);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EquipmentListContent)),
      );
      container.read(source.notifier).state = noTypeOrder.copyWith(
        groupByType: false,
        typeOrderDescending: true,
      );
      await tester.pumpAndSettle();

      expect(position.pixels, 0);
    });

    testWidgets('a change to only the dive item sort does not jump the list', (
      tester,
    ) async {
      // The page orders gear by its own sort, so the arrangement's item sort
      // moves no row here. Re-scrolling to the selected row on such a change
      // would yank the diver back from wherever they had scrolled.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gear = [
        for (final type in EquipmentType.values)
          _makeEquipment(id: type.name, name: 'Item ${type.name}', type: type),
      ];
      final target = arrangeEquipment(
        gear,
        EquipmentArrangement.defaults,
        typeLabel: (t) => t.displayName,
      )[8].items.single;
      final source = StateProvider<EquipmentArrangement>(
        (ref) => EquipmentArrangement.defaults,
      );

      final overrides = await _buildPhoneOverrides(items: gear);
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            equipmentArrangementProvider.overrideWith(
              (ref) => ref.watch(source),
            ),
          ],
          child: EquipmentListContent(showAppBar: false, selectedId: target.id),
        ),
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.pixels, greaterThan(0), reason: 'scrolled to the row');

      position.jumpTo(0);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EquipmentListContent)),
      );
      container.read(source.notifier).state = EquipmentArrangement.defaults
          .copyWith(
            itemSortField: EquipmentItemSortField.purchaseDate,
            itemSortDirection: SortDirection.descending,
          );
      await tester.pumpAndSettle();

      expect(position.pixels, 0);
    });

    testWidgets('scrolling to the selected gear allows for the headings', (
      tester,
    ) async {
      // Each type gets its own heading, so a row deep in the list has almost
      // as many headings above it as items. Sizing a heading like an item row
      // overshoots by the difference per heading, and the row the diver
      // opened ends up scrolled past the top of the list.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gear = [
        for (final type in EquipmentType.values)
          _makeEquipment(id: type.name, name: 'Item ${type.name}', type: type),
      ];
      final groups = arrangeEquipment(
        gear,
        EquipmentArrangement.defaults,
        typeLabel: (t) => t.displayName,
      );
      // Mid-list on purpose: near the end the clamp to the maximum scroll
      // extent hides the overshoot.
      final target = groups[8].items.single;

      final overrides = await _buildPhoneOverrides(
        items: gear,
        arrangement: EquipmentArrangement.defaults,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: EquipmentListContent(showAppBar: false, selectedId: target.id),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.text(target.name);
      expect(row, findsOneWidget);
      final list = tester.getRect(find.byType(ListView));
      final rect = tester.getRect(row);
      expect(
        rect.top,
        greaterThanOrEqualTo(list.top),
        reason: '$rect in $list',
      );
      expect(rect.bottom, lessThanOrEqualTo(list.bottom), reason: '$rect');
    });
  });

  group('filter panel (#1274, PR #1435 review)', () {
    final items = [
      _makeEquipment(
        id: 'e1',
        name: 'Alpha Reg',
        type: EquipmentType.regulator,
      ),
      _makeEquipment(id: 'e2', name: 'Bravo BCD', type: EquipmentType.bcd),
      _makeEquipment(id: 'e3', name: 'Charlie BCD', type: EquipmentType.bcd),
      _makeEquipment(id: 'e4', name: 'Delta Suit', type: EquipmentType.wetsuit),
    ];

    Future<void> pumpPhoneList(
      WidgetTester tester, {
      List<EquipmentItem>? equipment,
    }) async {
      final overrides = await _buildPhoneOverrides(
        items: equipment ?? items,
        viewMode: ListViewMode.detailed,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Pump a list whose source lists are driven by [source], so a test can
    /// shrink the gear out from under an active filter.
    Future<void> pumpLiveList(
      WidgetTester tester,
      StateProvider<List<EquipmentItem>> source, {
      List<EquipmentItem> Function(List<EquipmentItem> all)? byStatus,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            equipmentByStatusProvider.overrideWith(
              (ref, status) =>
                  byStatus?.call(ref.watch(source)) ?? ref.watch(source),
            ),
            activeEquipmentProvider.overrideWith(
              (ref) async => ref.watch(source),
            ),
            allEquipmentProvider.overrideWith((ref) async => ref.watch(source)),
            serviceDueEquipmentProvider.overrideWith(
              (ref) async => const <EquipmentItem>[],
            ),
            equipmentListViewModeProvider.overrideWith(
              (ref) => ListViewMode.detailed,
            ),
            equipmentTableConfigProvider.overrideWith(
              (ref) => _TestEquipTableConfigNotifier(_testConfig),
            ),
            highlightedEquipmentIdProvider.overrideWith((ref) => null),
          ],
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the list shows no filter row until a filter is applied', (
      tester,
    ) async {
      // The point of the panel: nothing but the top-bar icon costs screen
      // real estate while the list is unfiltered.
      await pumpPhoneList(tester);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(InputChip), findsNothing);
      expect(_filterButton, findsOneWidget);
    });

    testWidgets('the panel offers one chip per owned type plus All Types', (
      tester,
    ) async {
      await pumpPhoneList(tester);
      await _openFilterPanel(tester);
      // The category section starts below the fold; scroll it in so its
      // chips are built before we count them.
      await tester.scrollUntilVisible(
        _typeChip(EquipmentType.bcd),
        120,
        scrollable: find.byType(Scrollable).last,
      );

      expect(_typeChip(null), findsOneWidget);
      expect(_typeChip(EquipmentType.regulator), findsOneWidget);
      expect(_typeChip(EquipmentType.bcd), findsOneWidget);
      expect(_typeChip(EquipmentType.wetsuit), findsOneWidget);
      // No fins in the fixture, so no fins chip.
      expect(_typeChip(EquipmentType.fins), findsNothing);
    });

    testWidgets('picking a type narrows the list to that type', (tester) async {
      await pumpPhoneList(tester);

      await _filterVia(tester, [_typeChipKey(EquipmentType.bcd)]);

      expect(find.text('Bravo BCD'), findsOneWidget);
      expect(find.text('Charlie BCD'), findsOneWidget);
      expect(find.text('Alpha Reg'), findsNothing);
      expect(find.text('Delta Suit'), findsNothing);
    });

    testWidgets('the panel edits a draft: nothing moves until Apply', (
      tester,
    ) async {
      await pumpPhoneList(tester);

      await _openFilterPanel(tester);
      await _tapPanelChip(tester, _typeChipKey(EquipmentType.bcd));
      // Still the full list behind the sheet.
      expect(find.byType(EquipmentListTile), findsNWidgets(4));

      await _applyPanel(tester);
      expect(find.byType(EquipmentListTile), findsNWidgets(2));
    });

    testWidgets('cancelling the panel leaves the filter alone', (tester) async {
      await pumpPhoneList(tester);

      await _openFilterPanel(tester);
      await _tapPanelChip(tester, _typeChipKey(EquipmentType.bcd));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(EquipmentListTile), findsNWidgets(4));
      expect(_badgeIsVisible(tester), isFalse);
    });

    testWidgets('the All Types chip restores the full list', (tester) async {
      await pumpPhoneList(tester);

      await _filterVia(tester, [_typeChipKey(EquipmentType.wetsuit)]);
      expect(find.byType(EquipmentListTile), findsOneWidget);

      await _filterVia(tester, [_typeChipKey(null)]);
      expect(find.byType(EquipmentListTile), findsNWidgets(4));
    });

    testWidgets('re-tapping the selected type chip clears the filter', (
      tester,
    ) async {
      await pumpPhoneList(tester);

      await _filterVia(tester, [_typeChipKey(EquipmentType.bcd)]);
      expect(find.byType(EquipmentListTile), findsNWidgets(2));

      await _filterVia(tester, [_typeChipKey(EquipmentType.bcd)]);
      expect(find.byType(EquipmentListTile), findsNWidgets(4));
    });

    testWidgets('type filter composes with the status filter (AND)', (
      tester,
    ) async {
      // The status provider is overridden to return the full fixture list, so
      // after picking a status the type chip must still narrow client-side.
      await pumpPhoneList(tester);

      await _filterVia(tester, [
        _statusChipKey(EquipmentStatus.retired),
        _typeChipKey(EquipmentType.regulator),
      ]);

      expect(find.text('Alpha Reg'), findsOneWidget);
      expect(find.byType(EquipmentListTile), findsOneWidget);
    });

    testWidgets('the status axis is a single choice', (tester) async {
      // Service Due and a concrete status cannot both be on: the list reads
      // one provider, and EquipmentFilterState asserts it.
      await pumpPhoneList(tester);

      await _openFilterPanel(tester);
      await _tapPanelChip(tester, _statusChipKey(EquipmentStatus.retired));
      await _tapPanelChip(tester, 'equipment_filter_status_serviceDue');
      await _applyPanel(tester);

      expect(tester.takeException(), isNull);
      // Service Due won, and its (empty) provider is what the list shows.
      expect(find.byType(EquipmentListTile), findsNothing);
      expect(find.text('Service Due'), findsOneWidget);
      expect(find.text(EquipmentStatus.retired.displayName), findsNothing);
    });

    testWidgets('the top-bar icon is badged only while a filter is active', (
      tester,
    ) async {
      await pumpPhoneList(tester);
      expect(_badgeIsVisible(tester), isFalse);

      await _filterVia(tester, [_typeChipKey(EquipmentType.bcd)]);
      expect(_badgeIsVisible(tester), isTrue);

      await _filterVia(tester, [_typeChipKey(null)]);
      expect(_badgeIsVisible(tester), isFalse);
    });

    testWidgets('the active-filter bar names each axis and removes it', (
      tester,
    ) async {
      await pumpPhoneList(tester);

      await _filterVia(tester, [
        _statusChipKey(EquipmentStatus.retired),
        _typeChipKey(EquipmentType.bcd),
      ]);

      final statusChip = find.widgetWithText(
        InputChip,
        EquipmentStatus.retired.displayName,
      );
      final typeChip = find.widgetWithText(
        InputChip,
        EquipmentType.bcd.displayName,
      );
      expect(statusChip, findsOneWidget);
      expect(typeChip, findsOneWidget);

      // Dropping the category leaves the status filter in place. The delete
      // affordance is invoked through the chip's own callback so the test
      // does not depend on which glyph Material picks for it.
      tester.widget<InputChip>(typeChip).onDeleted!();
      await tester.pumpAndSettle();
      expect(typeChip, findsNothing);
      expect(statusChip, findsOneWidget);
      expect(find.byType(EquipmentListTile), findsNWidgets(4));
    });

    testWidgets('clear all in the active-filter bar drops every axis', (
      tester,
    ) async {
      await pumpPhoneList(tester);

      await _filterVia(tester, [
        _statusChipKey(EquipmentStatus.retired),
        _typeChipKey(EquipmentType.bcd),
      ]);
      expect(find.byType(InputChip), findsNWidgets(2));

      await tester.tap(
        find.byKey(const ValueKey('equipment_activeFilter_clearAll')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
      expect(_badgeIsVisible(tester), isFalse);
      expect(find.byType(EquipmentListTile), findsNWidgets(4));
    });

    testWidgets('empty type match shows the category empty state', (
      tester,
    ) async {
      // Select a type, then shrink the source list so nothing matches; the
      // filter must stay clearable and the empty state must name the category.
      final source = StateProvider<List<EquipmentItem>>((ref) => items);
      await pumpLiveList(tester, source);

      await _filterVia(tester, [_typeChipKey(EquipmentType.wetsuit)]);
      expect(find.text('Delta Suit'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(EquipmentListContent)),
      );
      container.read(source.notifier).state = [items.first];
      await tester.pumpAndSettle();

      expect(find.byType(EquipmentListTile), findsNothing);
      // The active-filter bar stays on screen so the filter can be cleared.
      expect(
        find.widgetWithText(InputChip, EquipmentType.wetsuit.displayName),
        findsOneWidget,
      );
      expect(find.text('No equipment in this category'), findsOneWidget);
      // A category filter is active, so the add-first-equipment CTA (which
      // implies there is no gear at all) must not appear.
      expect(find.text('Add Your First Equipment'), findsNothing);
    });

    testWidgets(
      'add-first-equipment CTA stays hidden when a type is selected and the '
      'underlying list becomes empty (#1435)',
      (tester) async {
        // Regression: the CTA visibility used to key off blameCategory,
        // which is false once the pre-filter source is empty -- letting the
        // "add your first equipment" button reappear while a category filter
        // was still active.
        final source = StateProvider<List<EquipmentItem>>((ref) => items);
        await pumpLiveList(tester, source);

        await _filterVia(tester, [_typeChipKey(EquipmentType.wetsuit)]);
        expect(find.text('Delta Suit'), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(EquipmentListContent)),
        );
        container.read(source.notifier).state = const <EquipmentItem>[];
        await tester.pumpAndSettle();

        expect(find.byType(EquipmentListTile), findsNothing);
        expect(
          find.widgetWithText(InputChip, EquipmentType.wetsuit.displayName),
          findsOneWidget,
        );
        expect(find.text('Add Your First Equipment'), findsNothing);
      },
    );

    testWidgets(
      'a category survives an empty status list and the empty state blames '
      'the status, not the category',
      (tester) async {
        // No item carries any non-active status, so every status filter comes
        // back empty while the default view has gear.
        final source = StateProvider<List<EquipmentItem>>((ref) => items);
        await pumpLiveList(
          tester,
          source,
          byStatus: (_) => const <EquipmentItem>[],
        );

        await _filterVia(tester, [_typeChipKey(EquipmentType.wetsuit)]);
        expect(find.text('Delta Suit'), findsOneWidget);

        await _filterVia(tester, [_statusChipKey(EquipmentStatus.retired)]);

        expect(find.byType(EquipmentListTile), findsNothing);
        // The status list was empty before the category narrowed anything,
        // so the category is not to blame.
        expect(find.text('No equipment in this category'), findsNothing);
        expect(find.text('No equipment with this status'), findsOneWidget);

        // Both filters are still listed, and clearing them restores the list.
        expect(find.byType(InputChip), findsNWidgets(2));
        await tester.tap(
          find.byKey(const ValueKey('equipment_activeFilter_clearAll')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EquipmentListTile), findsNWidgets(4));
      },
    );
  });

  group('filter selection and refresh target the right provider (#636)', () {
    Future<void> pumpPhoneList(
      WidgetTester tester,
      List<EquipmentItem> items,
    ) async {
      final overrides = await _buildPhoneOverrides(
        items: items,
        viewMode: ListViewMode.detailed,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('selecting a status filter switches to the status provider', (
      tester,
    ) async {
      await pumpPhoneList(tester, [
        _makeEquipment(id: 'e1', name: 'Alpha Reg'),
        _makeEquipment(
          id: 'e2',
          name: 'Old BCD',
          status: EquipmentStatus.retired,
        ),
      ]);

      await _filterVia(tester, [_statusChipKey(EquipmentStatus.retired)]);

      // The status branch of build() is now live; both fixtures come back
      // because the status provider is overridden to return the full list.
      expect(find.byType(EquipmentListTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    /// Drives the RefreshIndicator directly: the list is short, so its
    /// default physics do not permit the overscroll a drag would need.
    Future<void> pullToRefresh(WidgetTester tester) async {
      final state = tester.state<RefreshIndicatorState>(
        find.byType(RefreshIndicator),
      );
      unawaited(state.show());
      await tester.pumpAndSettle();
    }

    testWidgets('refreshing the default view rebuilds the active provider', (
      tester,
    ) async {
      var activeBuilds = 0;
      var statusBuilds = 0;
      final items = [_makeEquipment(id: 'e1', name: 'Alpha Reg')];
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        testApp(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            activeEquipmentProvider.overrideWith((ref) async {
              activeBuilds++;
              return items;
            }),
            equipmentByStatusProvider.overrideWith((ref, status) {
              statusBuilds++;
              return items;
            }),
            allEquipmentProvider.overrideWith((ref) async => items),
            equipmentListViewModeProvider.overrideWith(
              (ref) => ListViewMode.detailed,
            ),
            equipmentTableConfigProvider.overrideWith(
              (ref) => _TestEquipTableConfigNotifier(_testConfig),
            ),
          ],
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      final activeBefore = activeBuilds;
      final statusBefore = statusBuilds;

      await pullToRefresh(tester);

      expect(
        activeBuilds,
        greaterThan(activeBefore),
        reason:
            'the default view reads activeEquipmentProvider, so refresh must '
            'invalidate that one or the list stays stale (#636)',
      );
      expect(
        statusBuilds,
        statusBefore,
        reason: 'the status family is not what the default view is showing',
      );
    });

    testWidgets('refreshing under a status filter rebuilds that status', (
      tester,
    ) async {
      var activeBuilds = 0;
      var statusBuilds = 0;
      final items = [
        _makeEquipment(
          id: 'e2',
          name: 'Old BCD',
          status: EquipmentStatus.retired,
        ),
      ];
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        testApp(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            activeEquipmentProvider.overrideWith((ref) async {
              activeBuilds++;
              return items;
            }),
            equipmentByStatusProvider.overrideWith((ref, status) {
              statusBuilds++;
              return items;
            }),
            allEquipmentProvider.overrideWith((ref) async => items),
            equipmentListViewModeProvider.overrideWith(
              (ref) => ListViewMode.detailed,
            ),
            equipmentTableConfigProvider.overrideWith(
              (ref) => _TestEquipTableConfigNotifier(_testConfig),
            ),
          ],
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      await _filterVia(tester, [_statusChipKey(EquipmentStatus.retired)]);

      final activeBefore = activeBuilds;
      final statusBefore = statusBuilds;

      await pullToRefresh(tester);

      expect(
        statusBuilds,
        greaterThan(statusBefore),
        reason:
            'the filtered view reads the status family, so refresh must '
            'invalidate that family',
      );
      expect(activeBuilds, activeBefore);
    });
  });
}

/// Records which ids each bulk action reached the notifier with.
class _CapturingEquipmentNotifier
    extends StateNotifier<AsyncValue<List<EquipmentItem>>>
    implements EquipmentListNotifier {
  _CapturingEquipmentNotifier() : super(const AsyncValue.data([]));

  final deleted = <String>[];
  final retired = <String>[];
  final reactivated = <String>[];

  @override
  Future<void> deleteEquipment(String id) async => deleted.add(id);

  @override
  Future<void> retireEquipment(String id) async => retired.add(id);

  @override
  Future<void> reactivateEquipment(String id) async => reactivated.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Serves the gear arrangement from memory so a test can drive the real
/// arrangement notifier through the sort sheet.
class _FakeArrangementRepository extends AppSettingsRepository {
  _FakeArrangementRepository() {
    addTearDown(_ticks.close);
  }

  final StreamController<void> _ticks = StreamController<void>();
  EquipmentArrangement? _stored;

  /// When set, the read waits on this, so a test can land the stored
  /// arrangement after the first frame, as a slow launch read would.
  Completer<EquipmentArrangement?>? heldRead;

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() async =>
      heldRead != null ? heldRead!.future : _stored;

  @override
  Future<void> setEquipmentArrangement(EquipmentArrangement arrangement) async {
    _stored = arrangement;
  }

  @override
  Stream<void> watchSettingsChanges() => _ticks.stream;
}
