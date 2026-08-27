import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_category_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// Catalog management for service kinds: built-ins are read-only reference
/// data; custom kinds support full CRUD.
class ServiceKindListPage extends ConsumerStatefulWidget {
  const ServiceKindListPage({super.key});

  @override
  ConsumerState<ServiceKindListPage> createState() =>
      _ServiceKindListPageState();
}

class _ServiceKindListPageState extends ConsumerState<ServiceKindListPage> {
  /// Owns the bulk-selection state machine for this page.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  String _intervalSummary(BuildContext context, ServiceKind kind) {
    final l10n = context.l10n;
    final parts = <String>[
      if (kind.defaultIntervalDays != null)
        l10n.equipment_serviceKinds_everyDays(kind.defaultIntervalDays!),
      if (kind.defaultIntervalDives != null)
        l10n.equipment_serviceKinds_everyDives(kind.defaultIntervalDives!),
      if (kind.defaultIntervalHours != null)
        l10n.equipment_serviceKinds_everyHours(
          kind.defaultIntervalHours!.toStringAsFixed(1),
        ),
      if (kind.defaultCategory != null) kind.defaultCategory!.label(l10n),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final kindsAsync = ref.watch(serviceKindsProvider);
    final l10n = context.l10n;

    // Built-in kinds are reference data the repository refuses to delete
    // (ServiceKindRepository.deleteKind throws), so they are not selectable
    // and must not appear in select-all.
    final selectableIds = (kindsAsync.value ?? const <ServiceKind>[])
        .where((k) => !k.isBuiltIn)
        .map((k) => k.id)
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(selectableIds);
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: selectableIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? SelectionAppBar(
                  controller: _selection,
                  selectableIds: selectableIds,
                  actions: const [],
                  shell: SelectionBarShell.appBar,
                  onDelete: _confirmAndDeleteSelected,
                )
              : AppBar(
                  title: Text(l10n.equipment_serviceKinds_title),
                  actions: [
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                  ],
                ),
          floatingActionButton: selection.isActive
              ? null
              : FloatingActionButton(
                  tooltip: l10n.equipment_serviceKinds_add,
                  onPressed: () => _showEditDialog(context, ref, kind: null),
                  child: const Icon(Icons.add),
                ),
          body: kindsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (kinds) {
              final builtIn = kinds.where((k) => k.isBuiltIn).toList();
              final custom = kinds.where((k) => !k.isBuiltIn).toList();
              return ListView(
                children: [
                  _SectionHeader(title: l10n.equipment_serviceKinds_builtIn),
                  for (final kind in builtIn)
                    ListTile(
                      // Not selectable: the repository refuses to delete these,
                      // so no checkbox appears and the lock stays put.
                      leading: SelectionLeading(
                        isSelectionMode: _isSelectionMode,
                        isChecked: false,
                        isSelectable: false,
                        child: const Icon(Icons.lock_outline),
                      ),
                      title: Text(kind.name),
                      subtitle: Text(_intervalSummary(context, kind)),
                    ),
                  _SectionHeader(title: l10n.equipment_serviceKinds_custom),
                  if (custom.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.equipment_serviceKinds_emptyCustom,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final kind in custom)
                    ListTile(
                      leading: SelectionLeading(
                        isSelectionMode: _isSelectionMode,
                        isChecked: _selectedIds.contains(kind.id),
                        onChanged: (_) => _selection.toggle(kind.id),
                        child: const Icon(Icons.build_circle_outlined),
                      ),
                      title: Text(kind.name),
                      subtitle: Text(_intervalSummary(context, kind)),
                      onTap: () {
                        if (_isSelectionMode) {
                          _selection.toggle(kind.id);
                          return;
                        }
                        _showEditDialog(context, ref, kind: kind);
                      },
                      // The per-row trash yields to selection mode: the bulk
                      // delete deliberately sits behind the selection bar's
                      // overflow, and a one-tap delete next to the checkbox
                      // would contradict that.
                      trailing: _isSelectionMode
                          ? null
                          : IconButton(
                              tooltip: l10n.equipment_serviceKinds_delete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _confirmDelete(context, ref, kind),
                            ),
                    ),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.common_bulkDelete_title(ids.length)),
        content: Text(ctx.l10n.common_bulkDelete_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(ctx.l10n.equipment_serviceKinds_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(serviceKindRepositoryProvider);
    _selection.exit();
    for (final id in ids) {
      await repo.deleteKind(id);
    }
    if (!mounted) return;
    // Mirrors the per-row delete: the kind list and the equipment clocks that
    // reference cascaded schedules both need re-reading.
    ref.invalidate(serviceKindsProvider);
    ref.invalidate(activeEquipmentClocksProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.common_bulkDelete_snackbar(ids.length)),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ServiceKind kind,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.equipment_serviceKinds_deleteConfirmTitle),
        content: Text(l10n.equipment_serviceKinds_deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.equipment_serviceKinds_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.equipment_serviceKinds_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(serviceKindRepositoryProvider).deleteKind(kind.id);
    ref.invalidate(serviceKindsProvider);
    // Deleting a kind cascade-deletes its schedules; dueClocks/worstClock and
    // the urgency map all derive from this base, so re-evaluate once.
    ref.invalidate(activeEquipmentClocksProvider);
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref, {
    required ServiceKind? kind,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ServiceKindEditDialog(ref: ref, existing: kind),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ServiceKindEditDialog extends StatefulWidget {
  final WidgetRef ref;
  final ServiceKind? existing;

  const _ServiceKindEditDialog({required this.ref, this.existing});

  @override
  State<_ServiceKindEditDialog> createState() => _ServiceKindEditDialogState();
}

class _ServiceKindEditDialogState extends State<_ServiceKindEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _days;
  late final TextEditingController _dives;
  late final TextEditingController _hours;
  late final TextEditingController _defaultCost;

  /// Null means "no opinion, use the diver's default currency". A dropdown
  /// entry maps to it explicitly so a chosen currency can be cleared again.
  String? _defaultCurrency;

  /// Null means "no default": a record logged against this type starts with
  /// whatever the dialog would have chosen anyway, rather than a category the
  /// diver never asked for.
  ServiceCategory? _defaultCategory;
  late Set<EquipmentType> _types;
  late bool _autoAttach;

  @override
  void initState() {
    super.initState();
    final k = widget.existing;
    _name = TextEditingController(text: k?.name ?? '');
    _days = TextEditingController(
      text: k?.defaultIntervalDays?.toString() ?? '',
    );
    _dives = TextEditingController(
      text: k?.defaultIntervalDives?.toString() ?? '',
    );
    // Hours are fractional, so the seed has to use the diver's decimal
    // separator: toString() would seed "12.5" where '.' groups thousands,
    // and an untouched re-save would store 125 (#1091).
    final hours = k?.defaultIntervalHours;
    _hours = TextEditingController(
      text: hours == null ? '' : formatDecimalForInput(hours),
    );
    // Same decimal-separator pairing as the hours field above (#1091).
    final cost = k?.defaultCost;
    _defaultCost = TextEditingController(
      text: cost == null ? '' : formatDecimalForInput(cost),
    );
    _defaultCurrency = k?.defaultCurrency;
    _defaultCategory = k?.defaultCategory;
    _types = {...(k?.applicableTypes ?? const [])};
    _autoAttach = k?.autoAttach ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    _dives.dispose();
    _hours.dispose();
    _defaultCost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? l10n.equipment_serviceKinds_add
            : l10n.equipment_serviceKinds_editTitle,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.equipment_serviceKinds_nameLabel,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.equipment_serviceKinds_nameRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.equipment_scheduleDialog_intervalDays,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dives,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.equipment_scheduleDialog_intervalDives,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hours,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.equipment_scheduleDialog_intervalHours,
                  ),
                ),
                const SizedBox(height: 12),
                // Default price for this maintenance, prefilled when a record
                // is logged. A per-item schedule can override it (#829).
                TextFormField(
                  key: const Key('service-kind-default-cost'),
                  controller: _defaultCost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.equipment_serviceKinds_defaultCostLabel,
                    hintText: l10n.equipment_serviceKinds_defaultCostHint,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final parsed = parseUserDecimal(value);
                    if (parsed == null || parsed < 0) {
                      return l10n.equipment_serviceDialog_costValidation;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Full width rather than sharing a row with the price: the
                // inherit entry is a sentence, not a 3-letter code, and it
                // overflowed a half-width dropdown even in English.
                DropdownButtonFormField<String?>(
                  key: const Key('service-kind-default-currency'),
                  initialValue: _defaultCurrency,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.equipment_serviceKinds_defaultCurrencyLabel,
                  ),
                  items: [
                    // The null entry is what makes a chosen currency clearable
                    // again; without it there is no way back to "inherit the
                    // diver's default".
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        l10n.equipment_serviceKinds_defaultCurrencyInherit,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final code in currencyCodesWith(_defaultCurrency))
                      DropdownMenuItem<String?>(value: code, child: Text(code)),
                  ],
                  onChanged: (value) =>
                      setState(() => _defaultCurrency = value),
                ),
                const SizedBox(height: 12),
                // Full width for the same reason as the currency dropdown
                // above: the "no default" entry is a phrase, not a code.
                DropdownButtonFormField<ServiceCategory?>(
                  key: const Key('service-kind-default-category'),
                  initialValue: _defaultCategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.equipment_serviceKinds_defaultCategoryLabel,
                  ),
                  items: [
                    DropdownMenuItem<ServiceCategory?>(
                      value: null,
                      child: Text(
                        l10n.equipment_serviceKinds_defaultCategoryNone,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final category in ServiceCategory.values)
                      DropdownMenuItem<ServiceCategory?>(
                        value: category,
                        child: Text(
                          category.label(l10n),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _defaultCategory = value),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.equipment_serviceKinds_appliesTo,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final type in EquipmentType.values)
                      FilterChip(
                        label: Text(type.displayName),
                        selected: _types.contains(type),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _types.add(type);
                          } else {
                            _types.remove(type);
                          }
                        }),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.equipment_serviceKinds_autoAttach),
                  value: _autoAttach,
                  onChanged: (value) => setState(() => _autoAttach = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.equipment_serviceKinds_cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.equipment_serviceKinds_save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final repo = widget.ref.read(serviceKindRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      // Scope the custom kind to the active diver so it does not surface
      // (or auto-attach) for other divers; null only when no diver exists.
      final diverId = await widget.ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      await repo.createKind(
        ServiceKind(
          id: '',
          diverId: diverId,
          name: _name.text.trim(),
          applicableTypes: _types.toList(),
          defaultIntervalDays: parseUserInt(_days.text),
          defaultIntervalDives: parseUserInt(_dives.text),
          defaultIntervalHours: parseUserDecimal(_hours.text),
          defaultCost: parseUserDecimal(_defaultCost.text),
          defaultCurrency: _defaultCurrency,
          defaultCategory: _defaultCategory,
          autoAttach: _autoAttach,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      // copyWith cannot null a field; build the updated entity directly.
      await repo.updateKind(
        ServiceKind(
          id: existing.id,
          diverId: existing.diverId,
          name: _name.text.trim(),
          applicableTypes: _types.toList(),
          defaultIntervalDays: parseUserInt(_days.text),
          defaultIntervalDives: parseUserInt(_dives.text),
          defaultIntervalHours: parseUserDecimal(_hours.text),
          defaultCost: parseUserDecimal(_defaultCost.text),
          defaultCurrency: _defaultCurrency,
          defaultCategory: _defaultCategory,
          autoAttach: _autoAttach,
          isBuiltIn: false,
          createdAt: existing.createdAt,
          updatedAt: now,
        ),
      );
    }
    widget.ref.invalidate(serviceKindsProvider);
    if (mounted) Navigator.pop(context);
  }
}
