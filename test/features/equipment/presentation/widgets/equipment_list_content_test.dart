import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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
