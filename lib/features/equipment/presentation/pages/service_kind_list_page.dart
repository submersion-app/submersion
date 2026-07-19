import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Catalog management for service kinds: built-ins are read-only reference
/// data; custom kinds support full CRUD.
class ServiceKindListPage extends ConsumerWidget {
  const ServiceKindListPage({super.key});

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
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kindsAsync = ref.watch(serviceKindsProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.equipment_serviceKinds_title)),
      floatingActionButton: FloatingActionButton(
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
                  leading: const Icon(Icons.lock_outline),
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
                  leading: const Icon(Icons.build_circle_outlined),
                  title: Text(kind.name),
                  subtitle: Text(_intervalSummary(context, kind)),
                  onTap: () => _showEditDialog(context, ref, kind: kind),
                  trailing: IconButton(
                    tooltip: l10n.equipment_serviceKinds_delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, kind),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
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
    ref.invalidate(dueClocksProvider);
    ref.invalidate(equipmentWorstClockProvider);
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
    _hours = TextEditingController(
      text: k?.defaultIntervalHours?.toString() ?? '',
    );
    _types = {...(k?.applicableTypes ?? const [])};
    _autoAttach = k?.autoAttach ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    _dives.dispose();
    _hours.dispose();
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
          defaultIntervalDays: int.tryParse(_days.text.trim()),
          defaultIntervalDives: int.tryParse(_dives.text.trim()),
          defaultIntervalHours: double.tryParse(_hours.text.trim()),
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
          defaultIntervalDays: int.tryParse(_days.text.trim()),
          defaultIntervalDives: int.tryParse(_dives.text.trim()),
          defaultIntervalHours: double.tryParse(_hours.text.trim()),
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
