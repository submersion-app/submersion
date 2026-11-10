import 'package:flutter/material.dart';

import 'package:submersion/features/data_quality/data/services/duplicate_cylinder_service.dart';
import 'package:submersion/features/data_quality/presentation/widgets/dive_identity_label.dart';
import 'package:submersion/features/data_quality/presentation/widgets/duplicate_cylinder_dialogs.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Runs a bulk removal, reporting each dive as it finishes.
typedef BulkDuplicateRun =
    Future<DuplicateRemovalResult> Function(
      void Function(int done, int total) onProgress,
    );

/// Shows what the bulk "Remove duplicate cylinders" will do, one line per
/// dive, and runs it with progress once confirmed (issue #4393). Resolves to
/// the run's result, or null when the diver cancels.
Future<DuplicateRemovalResult?> showDuplicateCylindersSheet(
  BuildContext context, {
  required List<CylinderMergePreview> previews,
  required DiveIdentityLabel? Function(String diveId) identityOf,
  required BulkDuplicateRun run,
}) {
  return showModalBottomSheet<DuplicateRemovalResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    builder: (context) => _DuplicateCylindersSheet(
      previews: previews,
      identityOf: identityOf,
      run: run,
    ),
  );
}

class _DuplicateCylindersSheet extends StatefulWidget {
  const _DuplicateCylindersSheet({
    required this.previews,
    required this.identityOf,
    required this.run,
  });

  final List<CylinderMergePreview> previews;
  final DiveIdentityLabel? Function(String diveId) identityOf;
  final BulkDuplicateRun run;

  @override
  State<_DuplicateCylindersSheet> createState() =>
      _DuplicateCylindersSheetState();
}

class _DuplicateCylindersSheetState extends State<_DuplicateCylindersSheet> {
  double? _progress;

  Future<void> _start() async {
    setState(() => _progress = 0);
    final result = await widget.run((done, total) {
      if (mounted) setState(() => _progress = total == 0 ? 1 : done / total);
    });
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final mergeable = [
      for (final p in widget.previews)
        if (!p.mixesDiffer) p,
    ];
    final skipped = widget.previews.length - mergeable.length;
    final running = _progress != null;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.dataQuality_bulk_sheetTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.dataQuality_bulk_sheetBody),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in mergeable)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.propane_tank_outlined),
                        title: Text(
                          widget.identityOf(p.diveId)?.headline ?? p.diveId,
                        ),
                        subtitle: Text(
                          l10n.dataQuality_bulk_sheetRow(
                            p.duplicateIds.length,
                            duplicateCylinderLabel(l10n, p.survivor),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (skipped > 0) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.dataQuality_bulk_skippedMixes(skipped),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (running)
                LinearProgressIndicator(value: _progress)
              else
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                    FilledButton(
                      onPressed: mergeable.isEmpty ? null : _start,
                      child: Text(l10n.dataQuality_removeDuplicate_confirm),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
