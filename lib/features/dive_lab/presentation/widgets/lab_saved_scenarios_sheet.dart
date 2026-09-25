import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/data/services/dive_lab_slate_pdf_service.dart';
import 'package:submersion/features/dive_lab/data/services/scenario_file_codec.dart';
import 'package:submersion/features/dive_lab/data/services/scenario_file_importer.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_lab/presentation/lab_share.dart';
import 'package:submersion/features/dive_lab/presentation/providers/dive_scenario_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the saved-scenarios sheet for [diveId].
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
/// duplicate, delete, share as a file; import a `.sublab`; multi-select to
/// share several as one PDF.
class LabSavedScenariosSheet extends ConsumerStatefulWidget {
  const LabSavedScenariosSheet({super.key, required this.diveId});

  final String diveId;

  @override
  ConsumerState<LabSavedScenariosSheet> createState() =>
      _LabSavedScenariosSheetState();
}

class _LabSavedScenariosSheetState
    extends ConsumerState<LabSavedScenariosSheet> {
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _busy = false;

  String get diveId => widget.diveId;

  Future<void> _import() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(labShareActionsProvider);
    try {
      final source = await actions.pickScenarioFile();
      if (source == null) return;
      final file = sublabFromJson(source);
      final result = await ScenarioFileImporter().import(
        file,
        diveNotes: l10n.diveLab_sublab_notes,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.diveCreated
                ? '${l10n.diveLab_import_done(file.scenario.name)} · '
                      '${l10n.diveLab_import_diveCreated}'
                : l10n.diveLab_import_done(file.scenario.name),
          ),
        ),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLab_import_failed(e.message))),
      );
    } on FileSystemException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLab_import_failed(e.message))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLab_import_failed(e.toString()))),
      );
    }
  }

  Future<void> _shareSelectedPdf(List<DiveScenario> scenarios) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final units = UnitFormatter(ref.read(settingsProvider));
    final actions = ref.read(labShareActionsProvider);
    setState(() => _busy = true);
    try {
      final inputs = await ref.read(labRequestInputsProvider(diveId).future);
      if (inputs == null) return;
      final sections = <LabSlateScenario>[];
      for (final s in scenarios) {
        if (!_selected.contains(s.id)) continue;
        final outcome = await ref.read(
          savedScenarioOutcomeProvider((
            diveId: diveId,
            scenarioId: s.id,
          )).future,
        );
        if (outcome == null || !mounted) continue;
        sections.add(
          labSlateScenario(
            context,
            l10n: l10n,
            units: units,
            inputs: inputs,
            scenario: s,
            outcome: outcome,
          ),
        );
      }
      if (sections.isEmpty) return;
      final bytes = await const DiveLabSlatePdfService().buildSlate(
        scenarios: sections,
        labels: labSlateLabels(l10n),
      );
      await actions.sharePdf(
        bytes,
        '${labSafeFileName('${inputs.dive.diveNumber ?? 'dive'}_lab')}.pdf',
      );
      if (mounted) {
        setState(() {
          _selecting = false;
          _selected.clear();
        });
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLab_share_failed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareFile(DiveScenario scenario) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(labShareActionsProvider);
    try {
      final inputs = await ref.read(labRequestInputsProvider(diveId).future);
      if (inputs == null) return;
      await actions.shareFile(
        labScenarioFileJson(inputs: inputs, scenario: scenario),
        '${labSafeFileName(scenario.name)}.$sublabExtension',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLab_share_failed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.diveLab_saved_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (scenarios != null && scenarios.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _selecting = !_selecting;
                      _selected.clear();
                    }),
                    child: Text(
                      _selecting
                          ? l10n.diveLab_saved_done
                          : l10n.diveLab_saved_select,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.file_open_outlined),
                  tooltip: l10n.diveLab_import_file,
                  onPressed: _import,
                ),
              ],
            ),
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
                  itemBuilder: (context, index) {
                    final s = scenarios[index];
                    final subtitle = labScenarioSummary(
                      l10n,
                      units,
                      s,
                      tankName,
                    );
                    if (_selecting) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selected.contains(s.id),
                        title: Text(s.name),
                        subtitle: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            _selected.add(s.id);
                          } else {
                            _selected.remove(s.id);
                          }
                        }),
                      );
                    }
                    return _ScenarioTile(
                      diveId: diveId,
                      scenario: s,
                      subtitle: subtitle,
                      onShareFile: () => _shareFile(s),
                    );
                  },
                ),
              ),
            if (_selecting && scenarios != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _selected.isEmpty || _busy
                    ? null
                    : () => _shareSelectedPdf(scenarios),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(l10n.diveLab_saved_sharePdf),
              ),
            ],
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
    required this.onShareFile,
  });

  final String diveId;
  final DiveScenario scenario;
  final String subtitle;
  final VoidCallback onShareFile;

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
              } else if (value == 'share') {
                onShareFile();
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
              PopupMenuItem(
                value: 'share',
                child: Text(l10n.diveLab_share_file),
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
