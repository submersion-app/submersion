import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_lab/presentation/providers/dive_scenario_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the saved-scenarios sheet for [diveId]. [onOpen] runs after a
/// scenario was loaded into the draft (the lab page passes nothing; the
/// teaser card passes a navigation).
Future<void> showLabSavedScenariosSheet(
  BuildContext context, {
  required String diveId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => LabSavedScenariosSheet(diveId: diveId),
  );
}

/// This dive's saved scenarios: open (load into the draft), rename,
/// duplicate, delete.
class LabSavedScenariosSheet extends ConsumerWidget {
  const LabSavedScenariosSheet({super.key, required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scenarios = ref
        .watch(diveScenariosForDiveProvider(diveId))
        .valueOrNull;
    final tanks = ref
        .watch(labRequestInputsProvider(diveId))
        .valueOrNull
        ?.tanks;
    String tankName(String id) => tanks == null ? id : labTankName(tanks, id);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.diveLab_saved_title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (scenarios == null)
              const Center(child: CircularProgressIndicator())
            else if (scenarios.isEmpty)
              Text(l10n.diveLab_saved_empty)
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: scenarios.length,
                  itemBuilder: (context, index) => _ScenarioTile(
                    diveId: diveId,
                    scenario: scenarios[index],
                    subtitle: labScenarioSummary(
                      l10n,
                      units,
                      scenarios[index],
                      tankName,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioTile extends ConsumerWidget {
  const _ScenarioTile({
    required this.diveId,
    required this.scenario,
    required this.subtitle,
  });

  final String diveId;
  final DiveScenario scenario;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final repository = ref.read(diveScenarioRepositoryProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(scenario.name),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () {
        ref.read(labDraftProvider(diveId).notifier).loadScenario(scenario);
        Navigator.of(context).pop();
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: scheme.error),
            tooltip: l10n.diveLab_saved_delete,
            onPressed: () => confirmAndDeleteScenario(
              context,
              ref,
              scenario.id,
              scenario.name,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'rename') {
                final entered = await showPlanNameDialog(
                  context,
                  initialName: scenario.name,
                  title: l10n.diveLab_saved_rename,
                );
                if (entered == null) return;
                await repository.saveScenario(scenario.copyWith(name: entered));
              } else if (value == 'duplicate') {
                await repository.duplicateScenario(scenario.id);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Text(l10n.diveLab_saved_rename),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Text(l10n.diveLab_saved_duplicate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One confirmation path for every delete entry point. The repository is
/// read before the await so no ref crosses the async gap.
Future<void> confirmAndDeleteScenario(
  BuildContext context,
  WidgetRef ref,
  String id,
  String name,
) async {
  final l10n = context.l10n;
  final repository = ref.read(diveScenarioRepositoryProvider);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.diveLab_saved_deleteConfirm(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.diveLab_saved_delete),
        ),
      ],
    ),
  );
  if (confirmed ?? false) await repository.deleteScenario(id);
}
