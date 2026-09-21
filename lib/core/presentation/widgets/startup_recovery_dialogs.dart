import 'package:flutter/material.dart';

import 'package:submersion/core/services/startup_recovery_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirms the dive log found in the folder the diver picked.
///
/// The counts are the whole point of the step. A diver recovering from a
/// failed launch is choosing between folders that all look alike from the
/// outside, and "412 dives, 87 dive sites" is what tells them they picked the
/// right one before Submersion commits to it.
///
/// Returns true when the diver wants to switch to [found].
Future<bool> showAdoptDiveLogDialog(
  BuildContext context,
  AdoptableDiveLog found,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.startup_recovery_adopt_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.startup_recovery_adopt_contents(
              found.diveCount,
              found.siteCount,
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText(
            found.path,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.startup_recovery_adopt_body),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.startup_recovery_adopt_confirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Confirms setting the unreadable database aside for an empty one.
///
/// Returns true when the diver wants to start fresh.
Future<bool> showStartFreshDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.startup_recovery_startFresh_title),
      content: Text(context.l10n.startup_recovery_startFresh_body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.startup_recovery_startFresh_confirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Says where the set-aside database went.
///
/// Shown before the relaunch rather than after, because once the app is up it
/// looks like a diver who has lost every dive they ever logged. The path is
/// selectable so it can be pasted into a file manager or a support message.
Future<void> showStartFreshDoneDialog(
  BuildContext context,
  String folder,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: SelectableText(
        context.l10n.startup_recovery_startFresh_done(folder),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_ok),
        ),
      ],
    ),
  );
}

/// Reports a recovery route that did not get anywhere.
///
/// [message] is null when there is nothing to add beyond the title, which is
/// the case for an unexpected throw: the raw [detail] says more than any
/// paraphrase of it could, and repeating the title as the body says nothing
/// at all.
///
/// [detail] carries raw error text when there is any; it is monospaced and
/// selectable rather than hidden, because on this screen the diver is often
/// the only person who can pass it on.
Future<void> showRecoveryProblemDialog(
  BuildContext context, {
  String? message,
  String? detail,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.startup_recovery_problem_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) Text(message),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              detail,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_ok),
        ),
      ],
    ),
  );
}
