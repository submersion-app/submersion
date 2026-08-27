import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The 3-step repair wizard (design spec section 6): scope and sources,
/// review grouped by confidence, apply summary. Panes are driven entirely
/// by [repairWizardProvider] state.
class MediaRepairWizardPage extends ConsumerStatefulWidget {
  const MediaRepairWizardPage({super.key});

  @override
  ConsumerState<MediaRepairWizardPage> createState() =>
      _MediaRepairWizardPageState();
}

class _MediaRepairWizardPageState extends ConsumerState<MediaRepairWizardPage> {
  final List<String> _folderRoots = [];
  bool _usePhotoLibrary = false;
  bool _useStore = true;

  Future<void> _addFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || _folderRoots.contains(path)) return;
    setState(() => _folderRoots.add(path));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repairWizardProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.media_repair_title)),
      body: switch (state) {
        RepairWizardIdle() => _scopePane(context),
        RepairWizardHarvesting() || RepairWizardApplying() => const Center(
          child: CircularProgressIndicator(),
        ),
        RepairWizardReview(:final proposals, :final prefixMove) => _reviewPane(
          context,
          proposals,
          prefixMove,
        ),
        RepairWizardDone(:final report) => _summaryPane(context, report),
        // The exception goes to the log, not the screen: it is untranslated
        // and can name internal paths and store keys.
        RepairWizardError() => _errorPane(context),
      },
    );
  }

  Widget _errorPane(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.common_error_tryAgain,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _scopePane(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final root in _folderRoots)
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(root, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _folderRoots.remove(root)),
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.create_new_folder_outlined),
          label: Text(context.l10n.media_repair_addFolder),
          onPressed: _addFolder,
        ),
        SwitchListTile(
          title: Text(context.l10n.media_repair_usePhotoLibrary),
          value: _usePhotoLibrary,
          onChanged: (v) => setState(() => _usePhotoLibrary = v),
        ),
        SwitchListTile(
          title: Text(context.l10n.media_repair_useStore),
          value: _useStore,
          onChanged: (v) => setState(() => _useStore = v),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => ref
              .read(repairWizardProvider.notifier)
              .harvest(
                RepairWizardConfig(
                  folderRoots: List.of(_folderRoots),
                  usePhotoLibrary: _usePhotoLibrary,
                  useStore: _useStore,
                ),
              ),
          child: Text(context.l10n.media_repair_scan),
        ),
      ],
    );
  }

  Widget _reviewPane(
    BuildContext context,
    List<RepairProposal> proposals,
    PrefixMove? prefixMove,
  ) {
    final notifier = ref.read(repairWizardProvider.notifier);
    final checkedCount = proposals
        .where((p) => notifier.isChecked(p.item.id))
        .length;

    String groupLabel(RepairConfidence confidence) => switch (confidence) {
      RepairConfidence.exact => context.l10n.media_repair_confidence_exact,
      RepairConfidence.probable =>
        context.l10n.media_repair_confidence_probable,
      RepairConfidence.edited => context.l10n.media_repair_confidence_edited,
      RepairConfidence.unmatched =>
        context.l10n.media_repair_confidence_unmatched,
    };

    final byConfidence = <RepairConfidence, List<RepairProposal>>{};
    for (final proposal in proposals) {
      byConfidence.putIfAbsent(proposal.confidence, () => []).add(proposal);
    }

    return Column(
      children: [
        if (prefixMove != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  context.l10n.media_repair_prefixMove(
                    prefixMove.fromPrefix,
                    prefixMove.toPrefix,
                    prefixMove.coveredCount,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final confidence in RepairConfidence.values)
                if (byConfidence.containsKey(confidence)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      groupLabel(confidence),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final proposal in byConfidence[confidence]!)
                    CheckboxListTile(
                      value: notifier.isChecked(proposal.item.id),
                      onChanged:
                          proposal.confidence == RepairConfidence.unmatched
                          ? null
                          : (_) => notifier.toggleProposal(proposal.item.id),
                      title: Text(
                        proposal.item.originalFilename ?? proposal.item.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: _proposalSubtitle(context, proposal),
                    ),
                ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: checkedCount == 0
                  ? null
                  : () =>
                        ref.read(repairWizardProvider.notifier).applyChecked(),
              child: Text(context.l10n.media_repair_apply(checkedCount)),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _proposalSubtitle(BuildContext context, RepairProposal proposal) {
    final candidate = proposal.candidate;
    if (candidate == null) return null;
    if (candidate.isStore) {
      return candidate.verified
          ? null
          : Text(context.l10n.media_repair_unverified);
    }
    final label = candidate.path ?? candidate.assetId;
    return label == null
        ? null
        : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _summaryPane(BuildContext context, RepairApplyReport report) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              context.l10n.media_repair_summary(
                report.relinked,
                report.cloudBacked,
                report.reuploadsQueued,
                report.failed,
                report.skipped,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.common_action_close),
            ),
          ],
        ),
      ),
    );
  }
}
