import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_filter_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_sort_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_toggle.dart';
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

  /// Bulk selection for the phone list. The page owns it because the phone's
  /// app bar carries "Select items", and the rows it selects live in the list.
  final SelectionController _phoneSelection = SelectionController();

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
    _phoneSelection.dispose();
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
          // Table mode has no app bar of its own inside the content, so the
          // filter panel is reachable only from here. The table stays flat,
          // so its sort sheet leaves the grouping out.
          appBarActions: _buildListActions(
            context,
            showGrouping: false,
            iconSize: 20,
          ),
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
    // Rebuilt with selection, because the actions step aside while selecting
    // the way the list's own action row used to.
    return ValueListenableBuilder<SelectionState>(
      valueListenable: _phoneSelection,
      builder: (context, selection, _) {
        final actions = _isEquipmentTab && !selection.isActive
            ? _buildListActions(
                context,
                showGrouping: EquipmentListContent.showsGrouping(
                  ref.watch(equipmentListViewModeProvider),
                ),
                onSelect: _phoneSelection.enterExplicit,
              )
            : const <Widget>[];
        final titleStyle = _phoneTitleStyle(context);
        final oneRow =
            actions.isEmpty ||
            _phoneRowFits(context, titleStyle, actionCount: actions.length);

        return Scaffold(
          appBar: AppBar(
            // The title is the section switcher: "Equipment" and "Sets" sit
            // where the title would, the one showing in a pill. 8 here plus
            // the switcher's own 8px label padding puts the text at the 16px
            // every other app bar title sits at.
            titleSpacing: _phoneTitleSpacing,
            title: DefaultTextStyle.merge(
              style: titleStyle,
              child: _buildSectionToggle(context),
            ),
            // One row whenever the switcher and the actions both fit; a
            // second row under the switcher otherwise, for the longer
            // translations and the narrowest phones (issue #2256).
            actions: oneRow ? actions : null,
            bottom: oneRow
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(
                      kMinInteractiveDimension,
                    ),
                    child: Row(children: [const Spacer(), ...actions]),
                  ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              EquipmentListContent(
                showAppBar: false,
                showHeader: false,
                selectionController: _phoneSelection,
              ),
              const EquipmentSetListContent(showAppBar: false),
            ],
          ),
          floatingActionButton: _buildFab(context),
        );
      },
    );
  }

  /// Horizontal space either side of the phone title; see [_phoneRowFits].
  static const double _phoneTitleSpacing = 8;

  /// The phone title at 18px: a step under the usual 22px app bar title,
  /// which is what lets the switcher share its row with the actions in most
  /// locales.
  TextStyle _phoneTitleStyle(BuildContext context) =>
      (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontSize: 18,
      );

  /// Whether the switcher and [actionCount] actions fit the app bar's one row.
  ///
  /// Mirrors how the app bar sizes its title: the width left after the
  /// actions and their padding, less the title spacing on both sides.
  bool _phoneRowFits(
    BuildContext context,
    TextStyle titleStyle, {
    required int actionCount,
  }) {
    final hasAccentIcon =
        resolveFeatureAccent(
          context,
          ref,
          surface: AccentSurface.header,
          featureId: 'equipment',
        ) !=
        null;
    final actionsPadding =
        AppBarTheme.of(context).actionsPadding?.horizontal ?? 0;
    final needed =
        EquipmentSectionToggle.naturalWidth(
          context,
          titleStyle,
          withAccentIcon: hasAccentIcon,
        ) +
        2 * _phoneTitleSpacing +
        actionCount * kMinInteractiveDimension +
        actionsPadding;
    return needed <= MediaQuery.sizeOf(context).width;
  }

  /// Search, filter, sort and the overflow menu, for an app bar.
  ///
  /// [onSelect] adds "Select items" to the overflow menu. The phone puts it
  /// there so the header fits one row; table mode has its own select control.
  List<Widget> _buildListActions(
    BuildContext context, {
    required bool showGrouping,
    VoidCallback? onSelect,
    double? iconSize,
  }) {
    return [
      IconButton(
        icon: Icon(Icons.search, size: iconSize),
        tooltip: context.l10n.equipment_list_searchTooltip,
        onPressed: () {
          showSearch(
            context: context,
            delegate: EquipmentSearchDelegate(context.l10n),
          );
        },
      ),
      IconButton(
        key: const ValueKey('equipment_filter_button'),
        icon: Badge(
          isLabelVisible: ref.watch(equipmentFilterProvider).hasActiveFilters,
          child: Icon(Icons.filter_list, size: iconSize),
        ),
        tooltip: context.l10n.equipment_list_filterTooltip,
        onPressed: () => showEquipmentFilterSheet(context, ref),
      ),
      IconButton(
        icon: Icon(Icons.sort, size: iconSize),
        tooltip: context.l10n.equipment_list_sortTooltip,
        onPressed: () =>
            showEquipmentListSortSheet(context, showGrouping: showGrouping),
      ),
      PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: iconSize),
        onSelected: (value) {
          if (value == _selectMenuValue) {
            onSelect?.call();
          } else if (value.startsWith('view_')) {
            final mode = ListViewMode.fromName(value.replaceFirst('view_', ''));
            ref.read(equipmentListViewModeProvider.notifier).state = mode;
          }
        },
        itemBuilder: (context) {
          final currentMode = ref.read(equipmentListViewModeProvider);
          return [
            if (onSelect != null) ...[
              PopupMenuItem<String>(
                value: _selectMenuValue,
                // Laid out like the view-mode items below it.
                child: Row(
                  children: [
                    const Icon(Icons.checklist, size: 20),
                    const SizedBox(width: 12),
                    Text(context.l10n.common_selection_enterTooltip),
                  ],
                ),
              ),
              const PopupMenuDivider(),
            ],
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
    ];
  }

  static const String _selectMenuValue = 'select_items';

  Widget _buildMasterDetailLayout(BuildContext context) {
    return _isEquipmentTab
        ? _buildEquipmentMasterDetail()
        : _buildSetsMasterDetail();
  }

  /// The Equipment / Sets switcher, for whichever header is hosting it.
  ///
  /// The same [TabController] drives it everywhere, so the phone layout keeps
  /// the swipe gesture its `TabBarView` provides.
  Widget _buildSectionToggle(BuildContext context) {
    return EquipmentSectionToggle(controller: _tabController);
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
            toggleBuilder: _buildSectionToggle,
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
            toggleBuilder: _buildSectionToggle,
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
