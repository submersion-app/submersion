import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/utils/log_failure.dart';

/// Creates or edits one configuration. Cylinders are a reorderable list;
/// their sortOrder is derived from list position on save.
class CylinderConfigEditPage extends ConsumerStatefulWidget {
  const CylinderConfigEditPage({super.key, this.configId, this.equipmentId});

  /// Null when creating.
  final String? configId;

  /// Pre-selects the owning unit when arriving from a rebreather's card.
  final String? equipmentId;

  @override
  ConsumerState<CylinderConfigEditPage> createState() =>
      _CylinderConfigEditPageState();
}

class _CylinderConfigEditPageState
    extends ConsumerState<CylinderConfigEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _nameController = TextEditingController();

  List<CylinderConfigItem> _items = [];
  String? _equipmentId;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _equipmentId = widget.equipmentId;
    if (widget.configId == null) {
      _loaded = true;
    } else {
      logFailure(_load(), _CylinderConfigEditPageState, 'load');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await ref.read(
      cylinderConfigProvider(widget.configId!).future,
    );
    if (!mounted) return;
    setState(() {
      _nameController.text = config?.name ?? '';
      _equipmentId = config?.equipmentId ?? widget.equipmentId;
      _items = [...?config?.items];
      _loaded = true;
    });
  }

  void _addCylinder() {
    final now = DateTime.now();
    setState(() {
      _items = [
        ..._items,
        CylinderConfigItem(
          id: _uuid.v4(),
          configId: widget.configId ?? '',
          sortOrder: _items.length,
          tankRole: TankRole.bailout,
          createdAt: now,
          updatedAt: now,
        ),
      ];
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final repository = ref.read(cylinderConfigRepositoryProvider);
    // Read the active diver directly. Bootstrapping this from an existing
    // config made the first write depend on a prior one: with no configs yet
    // the id was null, and a null diver_id is invisible to every
    // diver-scoped query, so the first configuration ever saved vanished.
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);

    var id = widget.configId;
    if (id == null) {
      id = await repository.createConfig(
        diverId: diverId,
        equipmentId: _equipmentId,
        name: _nameController.text.trim(),
      );
    } else {
      final existing = await repository.getConfigById(id);
      if (existing != null) {
        await repository.updateConfig(
          existing.copyWith(
            name: _nameController.text.trim(),
            equipmentId: _equipmentId,
            clearEquipmentId: _equipmentId == null,
          ),
        );
      }
    }
    await repository.saveItems(id, _items);

    if (!mounted) return;
    invalidateCylinderConfigs(ref, configId: id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final equipment = ref.watch(allEquipmentProvider).valueOrNull ?? const [];
    final rebreathers = equipment
        .where((e) => e.type == EquipmentType.rebreather)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.configId == null
              ? l10n.cylinderConfigs_new
              : l10n.cylinderConfigs_title,
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.cylinderConfigs_name,
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.cylinderConfigs_nameRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    // The equipment list loads asynchronously, so on the first
                    // frame it is empty even when _equipmentId is set from the
                    // route. A dropdown value with no matching item throws, so
                    // fall back to the generic option until the unit appears
                    // (also covers an owning unit that was deleted).
                    initialValue:
                        rebreathers.any((unit) => unit.id == _equipmentId)
                        ? _equipmentId
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.cylinderConfigs_forUnit,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.cylinderConfigs_noUnit),
                      ),
                      for (final EquipmentItem unit in rebreathers)
                        DropdownMenuItem<String?>(
                          value: unit.id,
                          child: Text(unit.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _equipmentId = value),
                  ),
                  const Divider(height: 32),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    // onReorderItem already adjusts newIndex for the removed
                    // item, so no oldIndex/newIndex correction is needed.
                    onReorderItem: (oldIndex, newIndex) => setState(() {
                      final next = [..._items];
                      next.insert(newIndex, next.removeAt(oldIndex));
                      _items = next;
                    }),
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Padding(
                          key: ValueKey(_items[i].id),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CylinderConfigItemEditor(
                            item: _items[i],
                            units: units,
                            onChanged: (updated) => setState(() {
                              final next = [..._items];
                              next[i] = updated;
                              _items = next;
                            }),
                            onRemove: () => setState(() {
                              final next = [..._items]..removeAt(i);
                              _items = next;
                            }),
                          ),
                        ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _addCylinder,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.cylinderConfigs_addCylinder),
                  ),
                ],
              ),
            ),
    );
  }
}
