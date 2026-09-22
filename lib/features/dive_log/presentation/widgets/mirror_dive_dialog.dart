import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Asks which linked buddies' profiles should receive the dive (issue
/// #2002). Returns the chosen diver ids, or null for "Not now".
Future<List<String>?> showMirrorDiveDialog(
  BuildContext context, {
  required List<MirrorCandidate> candidates,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => _MirrorDiveDialog(candidates: candidates),
  );
}

class _MirrorDiveDialog extends StatefulWidget {
  final List<MirrorCandidate> candidates;

  const _MirrorDiveDialog({required this.candidates});

  @override
  State<_MirrorDiveDialog> createState() => _MirrorDiveDialogState();
}

class _MirrorDiveDialogState extends State<_MirrorDiveDialog> {
  late Set<String> _selected = {for (final c in widget.candidates) c.diver.id};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.diveLog_mirror_dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.diveLog_mirror_dialogBody),
          const SizedBox(height: 12),
          for (final c in widget.candidates)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(c.diver.id),
              secondary: ProfileAvatar(
                photo: c.diver.photo ?? c.buddy.photo,
                initials: c.diver.initials,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
              ),
              title: Text(c.diver.name),
              onChanged: (checked) => setState(() {
                _selected = checked == true
                    ? {..._selected, c.diver.id}
                    : _selected.difference({c.diver.id});
              }),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.diveLog_mirror_notNow),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final c in widget.candidates)
                    if (_selected.contains(c.diver.id)) c.diver.id,
                ]),
          child: Text(l10n.diveLog_mirror_log),
        ),
      ],
    );
  }
}

/// Runs the mirror and shows a snackbar with Undo. Invalidates the dive
/// lists through [container] so it keeps working after the caller's State
/// is gone (the edit page navigates away right after saving).
Future<void> runDiveMirror({
  required BuildContext context,
  required ProviderContainer container,
  required String sourceDiveId,
  required List<MirrorCandidate> chosen,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final names = chosen.map((c) => c.diver.name).join(', ');
  final service = container.read(diveMirrorServiceProvider);

  void refreshLists() {
    container.invalidate(paginatedDiveListProvider);
    container.invalidate(diveListNotifierProvider);
    container.invalidate(divesProvider);
    container.invalidate(diveStatisticsProvider);
  }

  final MirrorOutcome outcome;
  try {
    outcome = await service.mirror(
      sourceDiveId: sourceDiveId,
      targetDiverIds: [for (final c in chosen) c.diver.id],
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveLog_mirror_failed(names))),
    );
    return;
  }
  refreshLists();
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.diveLog_mirror_snackbar(names)),
      duration: const Duration(seconds: 6),
      persist: false,
      showCloseIcon: true,
      action: SnackBarAction(
        label: l10n.diveLog_bulkDelete_undo,
        onPressed: () async {
          // The undo runs in a transaction that can fail (a constraint or an
          // IO error). Without this guard the exception escapes the snackbar
          // callback and reaches the framework instead of the diver.
          try {
            await service.undo(outcome);
          } catch (_) {
            refreshLists();
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.diveLog_mirror_undoFailed)),
            );
            return;
          }
          refreshLists();
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.diveLog_mirror_undone)),
          );
        },
      ),
    ),
  );
}
