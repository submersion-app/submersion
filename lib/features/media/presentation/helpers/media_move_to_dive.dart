import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_picker_row.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

const _log = LoggerService('MediaMoveToDive');

/// Whether moving items now on [fromDiveIds] to [targetDiveId] would change
/// a dive that is open for editing on its page (issue #4527).
///
/// The opposite answer to a dropped file's (`diveDropAnswer`): a drop is
/// held by an open dive and refused by a locked one, while Move belongs to
/// no sitting, so it refuses an open dive and writes to a locked one. A
/// session being saved (frozen) is still open; a disposed one is a page
/// that has gone without clearing the provider, so it is not.
bool moveTouchesOpenDive({
  required OpenDiveSitting? open,
  required String targetDiveId,
  required Iterable<String?> fromDiveIds,
}) {
  if (open == null || open.session.isDisposed) return false;
  return open.diveId == targetDiveId || fromDiveIds.contains(open.diveId);
}

/// The media library's Move to dive: pick a dive, check no dive in the move
/// is open for editing, ask, then write one labelled History entry
/// (`MediaRepository.reassignMediaToDive`).
///
/// A refusal writes nothing and keeps the selection; so does Cancel. There
/// is no Undo: the History entry reverts the whole move. Items already on
/// the picked dive are left out; when that is all of them, nothing is
/// asked or written.
Future<BulkActionOutcome> moveMediaToDive(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> selected,
) async {
  final row = await showDivePickerRowSheet(context);
  if (row == null || !context.mounted) return BulkActionOutcome.cancelled;
  final items = [
    for (final item in selected)
      if (item.diveId != row.id) item,
  ];
  if (items.isEmpty) return BulkActionOutcome.completed;

  bool refused() {
    final touches = moveTouchesOpenDive(
      open: ref.read(openDiveSittingProvider),
      targetDiveId: row.id,
      fromDiveIds: [for (final item in items) item.diveId],
    );
    if (touches) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.media_library_moveDiveOpenHint)),
      );
    }
    return touches;
  }

  if (refused()) return BulkActionOutcome.cancelled;
  final confirmed = await _confirmMove(context, ref, items.length, row);
  if (!confirmed || !context.mounted) return BulkActionOutcome.cancelled;
  // A dive may have been unlocked while the confirmation was up.
  if (refused()) return BulkActionOutcome.cancelled;

  try {
    await ref.read(mediaRepositoryProvider).reassignMediaToDive([
      for (final item in items) item.id,
    ], row.id);
    return BulkActionOutcome.completed;
  } catch (error, stackTrace) {
    _log.error('Move to dive failed', error: error, stackTrace: stackTrace);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.media_library_moveFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
    return BulkActionOutcome.failed;
  }
}

/// '#42 Blue Hole, Mar 12, 2026': the dive as the picker showed it, with its
/// date in the diver's format, joined as the language joins them.
String _diveName(BuildContext context, WidgetRef ref, DivePickerRow row) {
  final date = ref.read(unitFormatterProvider).formatDate(row.dateTime);
  final label = divePickerRowLabel(row);
  return label.isEmpty
      ? date
      : context.l10n.media_library_moveDiveName(label, date);
}

Future<bool> _confirmMove(
  BuildContext context,
  WidgetRef ref,
  int count,
  DivePickerRow row,
) async {
  final l10n = context.l10n;
  final dive = _diveName(context, ref, row);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('move_to_dive_confirm'),
      title: Text(l10n.media_library_moveConfirmTitle(count)),
      content: Text(l10n.media_library_moveConfirmBody(count, dive)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.media_library_moveConfirmAction),
        ),
      ],
    ),
  );
  return confirmed == true;
}
