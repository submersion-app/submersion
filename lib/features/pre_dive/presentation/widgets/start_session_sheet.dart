import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/services/session_item_composer.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet that starts a pre-dive checklist session: pick a template,
/// optionally pick an equipment set (only offered when the template has an
/// equipmentSet item), then compose the snapshot and open the runner.
Future<void> showStartSessionSheet(
  BuildContext context, {
  String? diveId,
  String? tripId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _StartSessionSheet(diveId: diveId, tripId: tripId),
    ),
  );
}

class _StartSessionSheet extends ConsumerStatefulWidget {
  final String? diveId;
  final String? tripId;

  const _StartSessionSheet({this.diveId, this.tripId});

  @override
  ConsumerState<_StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends ConsumerState<_StartSessionSheet> {
  PreDiveChecklistTemplate? _template;
  List<PreDiveChecklistTemplateItem> _templateItems = const [];
  EquipmentSet? _equipmentSet;
  bool _setInitialized = false;
  final Map<String, EquipmentItem?> _equipmentByItemId = {};
  final Set<String> _equipmentInitialized = {};
  bool _starting = false;

  bool get _needsEquipmentSet =>
      _templateItems.any((i) => i.itemType == PreDiveItemType.equipmentSet);

  List<PreDiveChecklistTemplateItem> get _equipmentItems => _templateItems
      .where((i) => i.itemType == PreDiveItemType.equipment)
      .toList();

  Future<void> _selectTemplate(PreDiveChecklistTemplate template) async {
    final items = await ref
        .read(preDiveTemplateRepositoryProvider)
        .getItemsForTemplate(template.id);
    if (!mounted) return;
    setState(() {
      _template = template;
      _templateItems = items;
      _equipmentByItemId.clear();
      _equipmentInitialized.clear();
    });
  }

  Future<void> _begin() async {
    final template = _template;
    if (template == null || _starting) return;
    setState(() => _starting = true);
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final chosenSet = _needsEquipmentSet ? _equipmentSet : null;
      final chosenSingles = <String, EquipmentItem>{
        for (final item in _equipmentItems)
          if (_equipmentByItemId[item.id] != null)
            item.id: _equipmentByItemId[item.id]!,
      };
      var gear = const <EquipmentItem>[];
      if (chosenSet != null) {
        final all = await EquipmentRepository().getAllEquipment(
          diverId: diverId,
        );
        gear = all.where((g) => chosenSet.equipmentIds.contains(g.id)).toList();
      }
      // Union of set-expanded gear and single-item links, deduplicated by id
      // so a device chosen both ways is not passed twice to the composer.
      final allGear = {
        for (final g in gear) g.id: g,
        for (final g in chosenSingles.values) g.id: g,
      }.values.toList();
      // Overdue service is a purely informative, live-computed warning shown
      // in the runner (SessionItemTile), not a decision baked into the
      // session at start time -- so no service-clock lookup happens here.
      final items = SessionItemComposer.compose(
        templateItems: _templateItems,
        equipmentSet: chosenSet,
        equipmentItems: allGear,
        equipmentByTemplateItemId: {
          for (final entry in chosenSingles.entries) entry.key: entry.value.id,
        },
        now: DateTime.now(),
      );
      final session = await ref
          .read(preDiveSessionRepositoryProvider)
          .startSession(
            template: template,
            items: items,
            diverId: diverId,
            diveId: widget.diveId,
            tripId: widget.tripId,
            equipmentSetId: chosenSet?.id,
            equipmentSetName: chosenSet?.name,
          );
      // Remember each single-equipment choice on its template item so the
      // next session pre-fills it. Skipped for built-in templates, whose
      // items are shared across every diver.
      if (!template.isBuiltIn) {
        final templateRepo = ref.read(preDiveTemplateRepositoryProvider);
        for (final item in _equipmentItems) {
          final chosen = _equipmentByItemId[item.id];
          final chosenId = chosen?.id;
          if (chosenId != item.equipmentId) {
            await templateRepo.updateItemEquipment(item.id, chosenId);
          }
        }
      }
      if (mounted) {
        Navigator.pop(context);
        context.push('/pre-dive-sessions/${session.id}');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final templatesAsync = ref.watch(preDiveTemplatesProvider);
    final templates = templatesAsync.value ?? const [];
    final setsAsync = ref.watch(equipmentSetsProvider);
    final sets = setsAsync.value ?? const [];
    final equipmentAsync = ref.watch(allEquipmentProvider);
    final equipmentList = equipmentAsync.value ?? const [];

    // Pre-select the diver's default equipment set once sets load.
    if (!_setInitialized && sets.isNotEmpty) {
      _setInitialized = true;
      _equipmentSet = sets.where((s) => s.isDefault).firstOrNull;
    }

    // Pre-fill each single-equipment item with its remembered device once
    // the diver's equipment list loads.
    if (equipmentList.isNotEmpty) {
      for (final item in _equipmentItems) {
        if (_equipmentInitialized.add(item.id)) {
          _equipmentByItemId[item.id] = equipmentList
              .where((e) => e.id == item.equipmentId)
              .firstOrNull;
        }
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.preDive_start_title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PreDiveChecklistTemplate>(
              initialValue: _template,
              decoration: InputDecoration(
                labelText: l10n.preDive_start_template,
              ),
              items: [
                for (final template in templates)
                  DropdownMenuItem(value: template, child: Text(template.name)),
              ],
              onChanged: (template) {
                if (template != null) _selectTemplate(template);
              },
            ),
            if (_needsEquipmentSet) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<EquipmentSet?>(
                initialValue: _equipmentSet,
                decoration: InputDecoration(
                  labelText: l10n.preDive_start_equipmentSet,
                ),
                items: [
                  DropdownMenuItem<EquipmentSet?>(
                    value: null,
                    child: Text(l10n.preDive_start_noEquipmentSet),
                  ),
                  for (final set in sets)
                    DropdownMenuItem<EquipmentSet?>(
                      value: set,
                      child: Text(set.name),
                    ),
                ],
                onChanged: (set) => setState(() => _equipmentSet = set),
              ),
            ],
            for (final item in _equipmentItems) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<EquipmentItem?>(
                initialValue: _equipmentByItemId[item.id],
                decoration: InputDecoration(labelText: item.title),
                items: [
                  DropdownMenuItem<EquipmentItem?>(
                    value: null,
                    child: Text(l10n.preDive_start_noEquipment),
                  ),
                  for (final e in equipmentList)
                    DropdownMenuItem<EquipmentItem?>(
                      value: e,
                      child: Text(e.name),
                    ),
                ],
                onChanged: (e) =>
                    setState(() => _equipmentByItemId[item.id] = e),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _template == null || _starting ? null : _begin,
              child: Text(l10n.preDive_start_begin),
            ),
          ],
        ),
      ),
    );
  }
}
