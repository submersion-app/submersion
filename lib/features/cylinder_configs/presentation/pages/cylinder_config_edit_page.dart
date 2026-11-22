import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/pages/cylinder_config_draft.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';
import 'package:submersion/core/platform/desktop_target_platform.dart';

/// Creates or edits one configuration. Cylinders are a reorderable list;
/// their sortOrder is derived from list position on save.
///
/// An editor with no read page (issue #4527, phase 4): it opens on the
/// shared Cancel and Save bar, asks before its changes are left behind, and
/// writes the configuration and its cylinders in one transaction and one
/// History entry.
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

class _CylinderConfigEditPageState extends ConsumerState<CylinderConfigEditPage>
    with RecordEditorHost<CylinderConfigEditPage, CylinderConfigDraft> {
  static final _log = LoggerService.forClass(CylinderConfigEditPage);

  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _nameController = TextEditingController();

  List<CylinderConfigItem> _items = [];
  String? _equipmentId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _equipmentId = widget.equipmentId;
    _nameController.addListener(editorChanged);
    if (widget.configId == null) {
      _loaded = true;
      // A new configuration opens on its empty form, so the first frame
      // shows the Cancel and Save bar. One made from a unit's card names
      // that unit: a seed, so it can be saved as it opens.
      final draft = readEditorDraft();
      openEditor(
        from: widget.equipmentId == null
            ? null
            : CylinderConfigDraft(name: draft.name, rows: draft.rows),
      );
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    disposeEditor();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final CylinderConfig? config;
    try {
      config = await ref.read(cylinderConfigProvider(widget.configId!).future);
    } catch (error, stackTrace) {
      _log.warning(
        'Loading cylinder configuration ${widget.configId} failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _leaveUnopened(context.l10n.recordEdit_loadFailed);
      return;
    }
    if (!mounted) return;
    // A stale link, or a configuration deleted on another device: there is
    // nothing to edit, so say so and go back to the list.
    if (config == null) {
      _leaveUnopened(context.l10n.cylinderConfigs_edit_notFound);
      return;
    }
    setState(() {
      _nameController.text = config!.name;
      _equipmentId = config.equipmentId;
      _items = [...config.items];
      _loaded = true;
    });
    openEditor();
  }

  /// Says [message] and leaves a configuration that could not be opened.
  void _leaveUnopened(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    leaveEditor();
  }

  /// Changes the form and hands it to the sitting.
  void _change(VoidCallback change) {
    setState(change);
    editorChanged();
  }

  void _addCylinder() {
    final now = DateTime.now();
    _change(() {
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

  @override
  String get editorTable => 'cylinder_configs';

  @override
  String? get editorStoredId => widget.configId;

  @override
  String? get editorLeaveLocation => '/equipment/cylinder-configs';

  @override
  String editorTitle(BuildContext context) => widget.configId == null
      ? context.l10n.cylinderConfigs_new
      : context.l10n.cylinderConfigs_title;

  @override
  CylinderConfigDraft readEditorDraft() {
    final units = ref.read(unitFormatterProvider);
    return CylinderConfigDraft(
      name: _nameController.text,
      equipmentId: _equipmentId,
      rows: [for (final item in _items) cylinderRowDraft(item, units)],
    );
  }

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  Future<void> writeEditor(String recordId) async {
    final repository = ref.read(cylinderConfigRepositoryProvider);
    final name = _nameController.text.trim();
    if (editorCreating) {
      // A null diver_id is invisible to every diver-scoped list, so the
      // configuration would vanish (the first one ever saved once did).
      final diverId = editorDiverId;
      if (diverId == null) {
        throw StateError('A new cylinder configuration needs an active diver');
      }
      await repository.createConfig(
        id: recordId,
        diverId: diverId,
        equipmentId: _equipmentId,
        name: name,
      );
      if (_items.isNotEmpty) await repository.saveItems(recordId, _items);
      return;
    }

    // The configuration as stored now, not as the page loaded it: what the
    // diver left alone keeps what storage holds, a sync meanwhile included.
    final stored = await repository.getConfigById(recordId);
    if (stored == null) {
      throw RecordSittingRefusal((l10n) => l10n.cylinderConfigs_edit_notFound);
    }
    final start = editorStartDraft;
    final draft = readEditorDraft();
    final nameChanged = start == null || draft.name != start.name;
    final unitChanged = start == null || draft.equipmentId != start.equipmentId;
    if (nameChanged || unitChanged) {
      await repository.updateConfig(
        stored.copyWith(
          name: nameChanged ? name : stored.name,
          equipmentId: unitChanged ? _equipmentId : stored.equipmentId,
          clearEquipmentId: unitChanged && _equipmentId == null,
        ),
      );
    }
    if (start != null && listEquals(draft.rows, start.rows)) return;
    // The cylinders as stored now, with the diver's own changes on them: a
    // cylinder the diver left alone follows storage (kept as stored, or gone
    // when removed elsewhere meanwhile), one they changed takes those
    // changes on its stored copy, one they added is written as the form has
    // it, and one added elsewhere meanwhile stays.
    final storedById = {for (final item in stored.items) item.id: item};
    final startById = {for (final row in start?.rows ?? const []) row.id: row};
    final formIds = {for (final item in _items) item.id};
    final inCuft =
        ref.read(unitFormatterProvider).settings.volumeUnit ==
        VolumeUnit.cubicFeet;
    CylinderConfigItem? toWrite(int i) {
      final item = _items[i];
      final row = draft.rows[i];
      final startRow = startById[row.id];
      final storedItem = storedById[item.id];
      if (startRow == row) return storedItem;
      if (startRow == null || storedItem == null) return item;
      return mergeCylinderEdits(
        stored: storedItem,
        edited: item,
        start: startRow,
        draft: row,
        inCuft: inCuft,
      );
    }

    await repository.saveItems(recordId, [
      for (var i = 0; i < _items.length; i++) ?toWrite(i),
      for (final item in stored.items)
        if (!startById.containsKey(item.id) && !formIds.contains(item.id)) item,
    ]);
  }

  @override
  void afterEditorSaved(ScaffoldMessengerState messenger) {
    invalidateCylinderConfigs(ref, configId: editorRecordId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    // ReorderableListView draws a drag handle over each card's end edge on
    // desktop; on mobile a long press drags and there is no handle.
    final dragHandleShown = isDesktopTargetPlatform(Theme.of(context).platform);
    final equipment = ref.watch(allEquipmentProvider).valueOrNull ?? const [];
    // Wishlist rebreathers (#2025) are not units a configuration can belong
    // to, except the one this configuration already names.
    final rebreathers = equipment
        .where(
          (e) =>
              e.type == EquipmentType.rebreather &&
              (!e.isWanted || e.id == _equipmentId),
        )
        .toList();

    return editorScaffold(
      context,
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
                  // Only a rebreather owner has a unit to tie a configuration
                  // to (issue #3576). A configuration already tied to one
                  // keeps the field even if that unit is gone, so it can be
                  // made generic again.
                  if (rebreathers.isNotEmpty || _equipmentId != null) ...[
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
                      onChanged: (value) => _change(() => _equipmentId = value),
                    ),
                  ],
                  const Divider(height: 32),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    // onReorderItem already adjusts newIndex for the removed
                    // item, so no oldIndex/newIndex correction is needed.
                    onReorderItem: (oldIndex, newIndex) => _change(() {
                      final next = [..._items];
                      next.insert(newIndex, next.removeAt(oldIndex));
                      _items = next;
                    }),
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Padding(
                          key: ValueKey(_items[i].id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CylinderConfigItemEditor(
                            item: _items[i],
                            number: i + 1,
                            units: units,
                            reserveDragHandle: dragHandleShown,
                            onChanged: (updated) => _change(() {
                              final next = [..._items];
                              next[i] = updated;
                              _items = next;
                            }),
                            onRemove: () => _change(() {
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
