import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
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
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_summary_widget.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
            tooltip: 'Column settings',
            onPressed: () {
              final config = ref.read(equipmentTableConfigProvider);
              final notifier = ref.read(equipmentTableConfigProvider.notifier);
              showEntityTableColumnPicker<EquipmentField>(
                context,
                config: config,
                adapter: EquipmentFieldAdapter.instance,
                onToggleColumn: notifier.toggleColumn,
                onReorderColumn: notifier.reorderColumn,
                onTogglePin: notifier.togglePin,
              );
            },
          ),
          appBarActions: [
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
                  getFieldDisplayName: (field) => field.displayName,
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
            IconButton(
              icon: const Icon(Icons.search, size: 20),
              tooltip: context.l10n.equipment_list_searchTooltip,
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: EquipmentSearchDelegate(),
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
        title: Text(context.l10n.equipment_appBar_title),
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
      return FloatingActionButton.extended(
        onPressed: () => _showAddEquipmentDialog(context, ref),
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

  void _showAddEquipmentDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddEquipmentSheet(ref: ref),
    );
  }
}

class AddEquipmentSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const AddEquipmentSheet({super.key, required this.ref});

  @override
  ConsumerState<AddEquipmentSheet> createState() => _AddEquipmentSheetState();
}

class _AddEquipmentSheetState extends ConsumerState<AddEquipmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _sizeController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _purchaseCurrencyController = TextEditingController(text: 'USD');
  final _serviceIntervalController = TextEditingController();
  final _notesController = TextEditingController();

  EquipmentType _selectedType = EquipmentType.regulator;
  DateTime? _purchaseDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _sizeController.dispose();
    _purchasePriceController.dispose();
    _purchaseCurrencyController.dispose();
    _serviceIntervalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.equipment_addSheet_title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: context.l10n.equipment_addSheet_closeTooltip,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EquipmentType>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_addSheet_typeLabel,
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: EquipmentType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_addSheet_nameLabel,
                    prefixIcon: const Icon(Icons.label),
                    hintText: context.l10n.equipment_addSheet_nameHint,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.equipment_addSheet_nameValidation;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _brandController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_addSheet_brandLabel,
                    prefixIcon: const Icon(Icons.business),
                    hintText: context.l10n.equipment_addSheet_brandHint,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_addSheet_modelLabel,
                    prefixIcon: const Icon(Icons.info_outline),
                    hintText: context.l10n.equipment_addSheet_modelHint,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _serialController,
                        decoration: InputDecoration(
                          labelText:
                              context.l10n.equipment_addSheet_serialNumberLabel,
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _sizeController,
                        decoration: InputDecoration(
                          labelText: context.l10n.equipment_addSheet_sizeLabel,
                          prefixIcon: const Icon(Icons.straighten),
                          hintText: context.l10n.equipment_addSheet_sizeHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Purchase Information
                Text(
                  context.l10n.equipment_addSheet_purchaseInfoTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: OutlinedButton.icon(
                        onPressed: _selectPurchaseDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _purchaseDate != null
                              ? '${_purchaseDate!.month}/${_purchaseDate!.day}/${_purchaseDate!.year}'
                              : context.l10n.equipment_addSheet_dateLabel,
                          style: TextStyle(
                            color: _purchaseDate != null
                                ? null
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        decoration: InputDecoration(
                          labelText: context.l10n.equipment_addSheet_priceLabel,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _purchaseCurrencyController,
                        decoration: InputDecoration(
                          labelText:
                              context.l10n.equipment_addSheet_currencyLabel,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Service Interval
                TextFormField(
                  controller: _serviceIntervalController,
                  decoration: InputDecoration(
                    labelText:
                        context.l10n.equipment_addSheet_serviceIntervalLabel,
                    prefixIcon: const Icon(Icons.schedule),
                    hintText:
                        context.l10n.equipment_addSheet_serviceIntervalHint,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_addSheet_notesLabel,
                    prefixIcon: const Icon(Icons.notes),
                    hintText: context.l10n.equipment_addSheet_notesHint,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _saveEquipment,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.equipment_addSheet_submitButton),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectPurchaseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _purchaseDate = date);
    }
  }

  Future<void> _saveEquipment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Get the current diver ID for new equipment
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);

      final equipment = EquipmentItem(
        id: '',
        diverId: diverId,
        name: _nameController.text.trim(),
        type: _selectedType,
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        serialNumber: _serialController.text.trim().isEmpty
            ? null
            : _serialController.text.trim(),
        size: _sizeController.text.trim().isEmpty
            ? null
            : _sizeController.text.trim(),
        purchaseDate: _purchaseDate,
        purchasePrice: _purchasePriceController.text.isNotEmpty
            ? double.tryParse(_purchasePriceController.text)
            : null,
        purchaseCurrency: _purchaseCurrencyController.text.trim().isEmpty
            ? 'USD'
            : _purchaseCurrencyController.text.trim(),
        serviceIntervalDays: _serviceIntervalController.text.isNotEmpty
            ? int.tryParse(_serviceIntervalController.text)
            : null,
        notes: _notesController.text.trim(),
        isActive: true,
      );

      await widget.ref
          .read(equipmentListNotifierProvider.notifier)
          .addEquipment(equipment);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.equipment_addSheet_successSnackbar),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.equipment_addSheet_errorSnackbar('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
