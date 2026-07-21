import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
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
  bool _starting = false;

  bool get _needsEquipmentSet =>
      _templateItems.any((i) => i.itemType == PreDiveItemType.equipmentSet);

  Future<void> _selectTemplate(PreDiveChecklistTemplate template) async {
    final items = await ref
        .read(preDiveTemplateRepositoryProvider)
        .getItemsForTemplate(template.id);
    if (!mounted) return;
    setState(() {
      _template = template;
      _templateItems = items;
    });
  }

  Future<void> _begin() async {
    final template = _template;
    if (template == null || _starting) return;
    // Capture the localized note before any await, so the composer never
    // touches BuildContext across an async gap.
    final serviceOverdueNote = context.l10n.preDive_runner_serviceOverdue;
    setState(() => _starting = true);
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final chosenSet = _needsEquipmentSet ? _equipmentSet : null;
      List<EquipmentItem> gear = const [];
      Set<String> overdueEquipmentIds = const {};
      if (chosenSet != null) {
        final all = await EquipmentRepository().getAllEquipment(
          diverId: diverId,
        );
        gear = all.where((g) => chosenSet.equipmentIds.contains(g.id)).toList();
        // Overdue gear is flagged from the service-clock ledger, evaluated only
        // for the chosen set (proportional to the set) and in parallel so total
        // latency is the slowest item, not the sum.
        final statusesPerGear = await Future.wait(
          gear.map((g) => ref.read(serviceClockStatusesProvider(g.id).future)),
        );
        overdueEquipmentIds = {
          for (var i = 0; i < gear.length; i++)
            if (statusesPerGear[i].any(
              (s) => s.severity == ServiceClockSeverity.overdue,
            ))
              gear[i].id,
        };
      }
      final items = SessionItemComposer.compose(
        templateItems: _templateItems,
        equipmentSet: chosenSet,
        equipmentItems: gear,
        now: DateTime.now(),
        serviceOverdueNote: serviceOverdueNote,
        overdueEquipmentIds: overdueEquipmentIds,
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

    // Pre-select the diver's default equipment set once sets load.
    if (!_setInitialized && sets.isNotEmpty) {
      _setInitialized = true;
      _equipmentSet = sets.where((s) => s.isDefault).firstOrNull;
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
