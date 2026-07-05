import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Present the saved-plans picker as a modal bottom sheet.
Future<void> showSavedPlansSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const SavedPlansSheet(),
  );
}

/// Lists saved plans (newest first) with open, duplicate, share, delete,
/// import, and a multi-select compare mode.
class SavedPlansSheet extends ConsumerStatefulWidget {
  const SavedPlansSheet({super.key});

  @override
  ConsumerState<SavedPlansSheet> createState() => _SavedPlansSheetState();
}

class _SavedPlansSheetState extends ConsumerState<SavedPlansSheet> {
  bool _selecting = false;
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(divePlanSummariesProvider);
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));

    // Render stale data during a reload rather than flashing a spinner.
    final plans = summaries.valueOrNull;

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
                    context.l10n.plannerCanvas_saved_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if ((plans?.length ?? 0) >= 2)
                  TextButton.icon(
                    icon: Icon(
                      _selecting ? Icons.close : Icons.compare_arrows,
                      size: 18,
                    ),
                    label: Text(
                      _selecting
                          ? context.l10n.common_action_cancel
                          : context.l10n.plannerCanvas_compare_action,
                    ),
                    onPressed: () => setState(() {
                      _selecting = !_selecting;
                      _selected.clear();
                    }),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.file_open, size: 18),
                  label: Text(context.l10n.plannerCanvas_share_import),
                  onPressed: () => _importPlan(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (plans == null && summaries.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (plans == null || plans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  context.l10n.plannerCanvas_saved_empty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  itemBuilder: (context, i) => _selecting
                      ? CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(plans[i].name),
                          value: _selected.contains(plans[i].id),
                          onChanged: (checked) => setState(() {
                            if (checked ?? false) {
                              if (_selected.length < 3) {
                                _selected.add(plans[i].id);
                              }
                            } else {
                              _selected.remove(plans[i].id);
                            }
                          }),
                        )
                      : _PlanTile(summary: plans[i], units: units),
                ),
              ),
            if (_selecting)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton(
                  onPressed: _selected.length >= 2
                      ? () {
                          final ids = _selected.join(',');
                          Navigator.of(context).pop();
                          GoRouter.of(
                            context,
                          ).go('/planning/dive-planner/compare?ids=$ids');
                        }
                      : null,
                  child: Text(
                    '${context.l10n.plannerCanvas_compare_action}'
                    ' (${_selected.length})',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _importPlan(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);

    final result = await FilePicker.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null) return;

    try {
      final source = await File(path).readAsString();
      final plan = subplanFromJson(source);
      await ref.read(divePlanRepositoryProvider).savePlan(plan);
      navigator.pop();
      router.go('/planning/dive-planner/${plan.id}');
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.plannerCanvas_share_importFailed(e.message)),
        ),
      );
    } on FileSystemException catch (e) {
      // An unreadable/missing file should surface the same friendly error
      // rather than escaping and tearing down the sheet.
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.plannerCanvas_share_importFailed(e.message)),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.plannerCanvas_share_importFailed(e.toString())),
        ),
      );
    }
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.summary, required this.units});

  final DivePlanSummary summary;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(summary.updatedAt);
    final subtitleParts = <String>[
      date,
      if (summary.maxDepth != null) units.formatDepth(summary.maxDepth!),
      if (summary.runtimeSeconds != null)
        '${(summary.runtimeSeconds! / 60).ceil()}′',
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(summary.name),
      subtitle: Text(subtitleParts.join(' · ')),
      onTap: () {
        context.pop();
        context.go('/planning/dive-planner/${summary.id}');
      },
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          final repository = ref.read(divePlanRepositoryProvider);
          if (value == 'duplicate') {
            await repository.duplicatePlan(summary.id);
          } else if (value == 'share') {
            final plan = await repository.getPlan(summary.id);
            if (plan == null) return;
            final safeName = plan.name
                .replaceAll(RegExp(r'[^\w\s-]'), '')
                .trim()
                .replaceAll(RegExp(r'\s+'), '_');
            await saveAndShareFile(
              planToSubplanJson(plan),
              '${safeName.isEmpty ? 'dive_plan' : safeName}.$subplanExtension',
              'application/json',
            );
          } else if (value == 'delete') {
            final confirmed = await _confirmDelete(context);
            if (confirmed) await repository.deletePlan(summary.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'duplicate',
            child: Text(context.l10n.plannerCanvas_saved_duplicate),
          ),
          PopupMenuItem(
            value: 'share',
            child: Text(context.l10n.plannerCanvas_share_menu),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.plannerCanvas_saved_deleteConfirmTitle),
        content: Text(
          context.l10n.plannerCanvas_saved_deleteConfirmBody(summary.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
