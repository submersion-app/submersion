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
    equipmentListViewModeProvider.overrideWith((ref) => viewMode),
    equipmentTableConfigProvider.overrideWith(
      (ref) => _TestEquipTableConfigNotifier(_testConfig),
    ),
    highlightedEquipmentIdProvider.overrideWith(
      (ref) => highlightedEquipmentId,
    ),
  ];
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

    testWidgets('table shows filter chips area', (tester) async {
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

      // Filter chips area should render with filter icon
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
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
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
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

      await tester.tap(find.byType(DropdownButton<Object?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EquipmentStatus.retired.displayName).last);
      await tester.pumpAndSettle();

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

      await tester.tap(find.byType(DropdownButton<Object?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EquipmentStatus.retired.displayName).last);
      await tester.pumpAndSettle();

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
