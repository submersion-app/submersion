import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How long a draft may stay open before the app asks whether the diver
/// surfaced (issue #637).
const kStaleOpenDraftAfter = Duration(hours: 6);

/// Whether [draft] is still open [kStaleOpenDraftAfter] after its entry.
/// [now] is wall clock flagged UTC, as dive times are stored.
bool isStaleOpenDraft(Dive draft, DateTime now) {
  if (!draft.isDraft || draft.exitTime != null) return false;
  final entry = draft.entryTime ?? draft.dateTime;
  return now.difference(entry) >= kStaleOpenDraftAfter;
}

/// The surfacing time a picked clock time names: on the entry's day, or
/// the next day when it is earlier than the entry (a dive across midnight).
DateTime surfacingTimeFor({
  required DateTime entry,
  required int hour,
  required int minute,
}) {
  final sameDay = entry.isUtc
      ? DateTime.utc(entry.year, entry.month, entry.day, hour, minute)
      : DateTime(entry.year, entry.month, entry.day, hour, minute);
  return sameDay.isBefore(entry)
      ? sameDay.add(const Duration(days: 1))
      : sameDay;
}

/// Asks about the current diver's stale open draft at launch and resume,
/// once per draft per app session. The app never invents an exit time.
class StaleOpenDraftPrompter {
  final _asked = <String>{};

  /// True the first time [draft] comes up this session.
  bool shouldAsk(Dive draft) => _asked.add(draft.id);

  /// Shows the prompt over [context] (the root navigator's) when a dive has
  /// been open on this device for [kStaleOpenDraftAfter], whoever's it is:
  /// the one Surfaced would close.
  Future<void> check(WidgetRef ref, BuildContext? context) async {
    final drafts = ref.read(diveDraftRepositoryProvider);
    final draft = await drafts.openDraftFor(null);
    if (draft == null ||
        !isStaleOpenDraft(draft, asWallClockUtc(DateTime.now())) ||
        context == null ||
        !context.mounted ||
        !shouldAsk(draft)) {
      return;
    }
    await showStaleOpenDraftPrompt(
      context,
      draft,
      onSurfaced: (at) => drafts.closeDraft(draft.id, exitTime: at),
    );
  }
}

/// "Did you surface?" for a draft left open: "Set surfacing time" picks the
/// exit time, an hour after entry by default, and calls [onSurfaced] with
/// it; "Still in the water" leaves the draft open.
Future<void> showStaleOpenDraftPrompt(
  BuildContext context,
  Dive draft, {
  required Future<void> Function(DateTime exitTime) onSurfaced,
}) async {
  final entry = draft.entryTime ?? draft.dateTime;
  // The diver's own time format, read before the dialog takes over.
  final time = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(unitFormatterProvider).formatTime(entry);
  final setTime = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.diveLog_draft_stale_title),
        content: Text(l10n.diveLog_draft_stale_body(time)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.diveLog_draft_stale_stillIn),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.diveLog_draft_stale_setTime),
          ),
        ],
      );
    },
  );
  if (setTime != true || !context.mounted) return;
  final suggested = entry.add(const Duration(hours: 1));
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: suggested.hour, minute: suggested.minute),
  );
  if (picked == null) return;
  await onSurfaced(
    surfacingTimeFor(entry: entry, hour: picked.hour, minute: picked.minute),
  );
}
