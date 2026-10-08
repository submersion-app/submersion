import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/import_wizard/presentation/suunto_file_import_navigation.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/source_confirmation_step.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shows [FileTriageStep] for multi-file batches and the classic
/// [SourceConfirmationStep] for single files.
class SourceConfirmationOrTriageStep extends ConsumerWidget {
  const SourceConfirmationOrTriageStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBatch = ref.watch(
      universalImportNotifierProvider.select((s) => s.isBatch),
    );
    return isBatch ? const FileTriageStep() : const SourceConfirmationStep();
  }
}

/// Batch replacement for the Confirm Source step: lists every selected file
/// with its detected format and whether it will join the batch. Shows parse
/// progress with a cancel affordance while the batch is being parsed.
class FileTriageStep extends ConsumerWidget {
  const FileTriageStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final readyCount = state.files
        .where(
          (f) =>
              f.status == ImportFileStatus.pending ||
              f.status == ImportFileStatus.parsed,
        )
        .length;

    // The "all excluded" copy is CSV-specific ("import one at a time"), so only
    // use it when a CSV was actually excluded; otherwise (only unsupported or
    // failed files) show a format-neutral message.
    final hasExcludedCsv = state.files.any(
      (f) =>
          f.status == ImportFileStatus.excludedCsv &&
          !f.detection.format.isHandoff,
    );
    // Suunto exports picked together are excluded from the batch like a
    // CSV, but they have an importer of their own that takes several files
    // at once (#1445); without this the triage would be a dead end.
    final suuntoFiles = [
      for (final f in state.files)
        if (f.status == ImportFileStatus.excludedCsv &&
            f.detection.format == ImportFormat.suuntoJson &&
            f.path != null)
          f,
    ];
    final emptyMessage = hasExcludedCsv
        ? l10n.universalImport_triage_allExcluded
        : l10n.universalImport_triage_noneImportable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            // A parse failure (e.g. every file failed) sets state.error; show
            // it instead of the generic empty-state message, which would
            // misrepresent the cause.
            state.error ??
                (readyCount > 0
                    ? l10n.universalImport_triage_readyCount(readyCount)
                    : emptyMessage),
            style: theme.textTheme.titleMedium?.copyWith(
              color: state.error != null ? theme.colorScheme.error : null,
            ),
          ),
        ),
        if (suuntoFiles.isNotEmpty && !state.isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                key: const ValueKey('triage-import-with-suunto'),
                icon: const Icon(Icons.scuba_diving),
                label: Text(l10n.universalImport_summary_importWithSuunto),
                onPressed: () => _openSuuntoImporter(context, suuntoFiles),
              ),
            ),
          ),
        if (state.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: state.parseTotal > 0
                      ? state.parseCurrent / state.parseTotal
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.universalImport_triage_parsing(
                        state.parseCurrent,
                        state.parseTotal,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(universalImportNotifierProvider.notifier)
                          .cancelBatchParse(),
                      child: Text(l10n.universalImport_triage_cancelParsing),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: state.files.length,
            itemBuilder: (context, index) {
              final file = state.files[index];
              return _FileTriageTile(file: file);
            },
          ),
        ),
      ],
    );
  }
}

/// Reads the excluded Suunto exports back from disk (the batch keeps no
/// bytes) and opens the Suunto importer with all of them.
Future<void> _openSuuntoImporter(
  BuildContext context,
  List<PickedImportFile> files,
) async {
  final l10n = context.l10n;
  try {
    final picked = [
      for (final f in files)
        SuuntoJsonFile(name: f.name, bytes: await File(f.path!).readAsBytes()),
    ];
    if (!context.mounted) return;
    await openSuuntoFileImport(context, picked);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.dropTarget_error_readFailed)));
  }
}

class _FileTriageTile extends StatelessWidget {
  const _FileTriageTile({required this.file});

  final PickedImportFile file;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final excluded =
        file.status == ImportFileStatus.excludedCsv ||
        file.status == ImportFileStatus.unsupported ||
        file.status == ImportFileStatus.failed;

    final (IconData icon, String? statusLabel) = switch (file.status) {
      ImportFileStatus.pending => (Icons.insert_drive_file, null),
      ImportFileStatus.parsed => (Icons.check_circle_outline, null),
      ImportFileStatus.failed => (
        Icons.error_outline,
        l10n.universalImport_triage_parseFailed,
      ),
      // A hand-off file (#1445) is excluded like a CSV, but names its own
      // format rather than claiming to be one.
      ImportFileStatus.excludedCsv => (
        Icons.block,
        file.detection.format.isHandoff
            ? l10n.universalImport_triage_excludedHandoff(
                file.detection.format.displayName,
              )
            : l10n.universalImport_triage_excludedCsv,
      ),
      ImportFileStatus.unsupported => (
        Icons.help_outline,
        l10n.universalImport_triage_unsupported,
      ),
    };

    return ListTile(
      enabled: !excluded,
      leading: Icon(
        icon,
        color: excluded
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.primary,
      ),
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(statusLabel ?? file.detection.format.displayName),
    );
  }
}
