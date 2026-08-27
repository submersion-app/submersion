import 'package:flutter/material.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_summary_widget.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

class EquipmentListPage extends ConsumerStatefulWidget {
  const EquipmentListPage({super.key});

  @override
  ConsumerState<EquipmentListPage> createState() => _EquipmentListPageState();
}

class _EquipmentListPageState extends ConsumerState<EquipmentListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _switchingTabProgrammatically = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
    // Skip URL clearing for programmatic tab switches (e.g., auto-switching
    // to Equipment tab when EquipmentDetailPage's desktop redirect fires)
    if (_switchingTabProgrammatically) {
      _switchingTabProgrammatically = false;
      return;
    }
    // Clear selected item when switching tabs on desktop to prevent
    // one tab's MasterDetailScaffold from receiving the other tab's ID
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      final state = GoRouterState.of(context);
      if (state.uri.queryParameters.containsKey('selected') ||
          state.uri.queryParameters.containsKey('setSelected') ||
          state.uri.queryParameters.containsKey('mode')) {
        context.go('/equipment');
      }
    }
  }

  bool get _isEquipmentTab => _tabController.index == 0;

  @override
  Widget build(BuildContext context) {
    // Table mode: intercept before the tab scaffold and use TableModeLayout
    // for the Equipment tab (equipment items only, not equipment sets).
    final viewMode = ref.watch(equipmentListViewModeProvider);
    if (viewMode == ListViewMode.table) {
      final fab = FloatingActionButton.extended(
        onPressed: () => context.push('/equipment/new'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.equipment_fab_addEquipment),
      );

      return FocusTraversalGroup(
        child: TableModeLayout(
          sectionKey: 'equipment',
          appBarTitle: context.l10n.nav_equipment,
          tableContent: const EquipmentListContent(showAppBar: false),
          detailBuilder: (context, id) => EquipmentDetailPage(
            equipmentId: id,
            embedded: true,
            onDeleted: () {
              context.go('/equipment');
            },
          ),
          summaryBuilder: (context) => const EquipmentSummaryWidget(),
          editBuilder: (context, id, onSaved, onCancel) => EquipmentEditPage(
            equipmentId: id,
            embedded: true,
            onSaved: onSaved,
            onCancel: onCancel,
          ),
          createBuilder: (context, onSaved, onCancel) => EquipmentEditPage(
            embedded: true,
            onSaved: onSaved,
            onCancel: onCancel,
          ),
          selectedId: ref.watch(highlightedEquipmentIdProvider),
          onEntitySelected: (id) {
            ref.read(highlightedEquipmentIdProvider.notifier).state = id;
          },
          columnSettingsAction: IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: context.l10n.columnConfig_tooltip_columnSettings,
            onPressed: () => showEntityTableColumnPicker<EquipmentField>(
              context,
              configProvider: equipmentTableConfigProvider,
              adapter: EquipmentFieldAdapter.instance,
            ),
          ),
          appBarActions: [
            IconButton(
              icon: const Icon(Icons.search, size: 20),
              tooltip: context.l10n.equipment_list_searchTooltip,
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: EquipmentSearchDelegate(context.l10n),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.sort, size: 20),
              tooltip: context.l10n.equipment_list_sortTooltip,
              onPressed: () {
                final sort = ref.read(equipmentSortProvider);
                showSortBottomSheet<EquipmentSortField>(
                  context: context,
                  title: context.l10n.equipment_list_sortTitle,
                  currentField: sort.field,
                  currentDirection: sort.direction,
                  fields: EquipmentSortField.values,
                  getFieldDisplayName: (field) =>
                      field.localizedName(context.l10n),
                  getFieldIcon: (field) => field.icon,
                  onSortChanged: (field, direction) {
                    ref.read(equipmentSortProvider.notifier).state = SortState(
                      field: field,
                      direction: direction,
                    );
                  },
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value.startsWith('view_')) {
                  final mode = ListViewMode.fromName(
                    value.replaceFirst('view_', ''),
                  );
                  ref.read(equipmentListViewModeProvider.notifier).state = mode;
                }
              },
              itemBuilder: (context) {
                final currentMode = ref.read(equipmentListViewModeProvider);
                return [
                  ...ListViewModeToggle.menuItems(
                    context,
                    currentMode: currentMode,
                    modes: const [
                      ListViewMode.detailed,
                      ListViewMode.compact,
                      ListViewMode.table,
                    ],
                  ),
                ];
              },
            ),
          ],
          floatingActionButton: fab,
        ),
      );
    }

    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      // Auto-switch to Equipment tab when ?selected= is in URL but Sets
      // tab is active. This handles the EquipmentDetailPage desktop redirect,
      // which sets ?selected=<equipmentId> when navigating from a set detail.
      if (!_isEquipmentTab) {
        final state = GoRouterState.of(context);
        if (state.uri.queryParameters.containsKey('selected')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isEquipmentTab) {
              _switchingTabProgrammatically = true;
              _tabController.index = 0;
            }
          });
        }
      }
      return _buildMasterDetailLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: FeatureAppBarTitle(
          featureId: 'equipment',
          title: context.l10n.equipment_appBar_title,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.backpack, size: 20),
                  const SizedBox(width: 8),
                  Text(context.l10n.equipment_tab_equipment),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_special, size: 20),
                  const SizedBox(width: 8),
                  Text(context.l10n.equipment_tab_sets),
                ],
              ),
            ),
          ],
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: colorScheme.primaryContainer,
          ),
          indicatorPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          labelColor: colorScheme.onPrimaryContainer,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          splashBorderRadius: BorderRadius.circular(24),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const EquipmentListContent(showAppBar: false),
          const EquipmentSetListContent(showAppBar: false),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildMasterDetailLayout(BuildContext context) {
    return _isEquipmentTab
        ? _buildEquipmentMasterDetail()
        : _buildSetsMasterDetail();
  }

  Widget _buildMasterTabBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TabBar(
      controller: _tabController,
      tabs: [
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.backpack, size: 20),
              const SizedBox(width: 8),
              Text(context.l10n.equipment_tab_equipment),
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_special, size: 20),
              const SizedBox(width: 8),
              Text(context.l10n.equipment_tab_sets),
            ],
          ),
        ),
      ],
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.primaryContainer,
      ),
      indicatorPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      labelColor: colorScheme.onPrimaryContainer,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      splashBorderRadius: BorderRadius.circular(24),
    );
  }

  Widget _buildEquipmentMasterDetail() {
    return MasterDetailScaffold(
      key: const ValueKey('equipment-master-detail'),
      sectionId: 'equipment',
      masterBuilder: (context, onItemSelected, selectedId) =>
          EquipmentListContent(
            onItemSelected: onItemSelected,
            selectedId: selectedId,
            showAppBar: false,
            headerExtension: _buildMasterTabBar(context),
          ),
      detailBuilder: (context, id) => EquipmentDetailPage(
        equipmentId: id,
        embedded: true,
        onDeleted: () {
          context.go('/equipment');
        },
      ),
      summaryBuilder: (context) => const EquipmentSummaryWidget(),
      editBuilder: (context, id, onSaved, onCancel) => EquipmentEditPage(
        equipmentId: id,
        embedded: true,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
      createBuilder: (context, onSaved, onCancel) => EquipmentEditPage(
        embedded: true,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: Text(context.l10n.equipment_fab_addEquipment),
      ),
    );
  }

  Widget _buildSetsMasterDetail() {
    return MasterDetailScaffold(
      key: const ValueKey('sets-master-detail'),
      sectionId: 'equipment-sets',
      queryParamKey: 'setSelected',
      masterBuilder: (context, onItemSelected, selectedId) =>
          EquipmentSetListContent(
            onItemSelected: onItemSelected,
            selectedId: selectedId,
            showAppBar: false,
            headerExtension: _buildMasterTabBar(context),
          ),
      detailBuilder: (context, id) => EquipmentSetDetailPage(setId: id),
      summaryBuilder: (context) => _buildSetsSummary(context),
      mobileDetailRoute: (id) => '/equipment/sets/$id',
      mobileCreateRoute: '/equipment/sets/new',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: Text(context.l10n.equipment_fab_addSet),
      ),
    );
  }

  Widget _buildSetsSummary(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_special,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.equipment_sets_appBar_title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.equipment_sets_emptyState_description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    if (_isEquipmentTab) {
      // The full editor, same as the table-mode FAB and the master-detail
      // create pane. A compact-only quick-add sheet used to live here, but it
      // offered no type-specific attribute fields, so new gear had to be saved
      // and reopened before dry weight / buoyancy could be entered.
      return FloatingActionButton.extended(
        onPressed: () => context.push('/equipment/new'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.equipment_fab_addEquipment),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => context.push('/equipment/sets/new'),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.equipment_fab_addSet),
    );
  }
}
