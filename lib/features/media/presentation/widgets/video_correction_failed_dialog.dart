import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks what to do when a shared video's colour correction could not be
/// applied (issue #3521): true shares the [failedCount] videos as their
/// originals, false (Cancel, or dismissed) shares nothing.
Future<bool> showVideoCorrectionFailedDialog(
  BuildContext context, {
  required int failedCount,
}) async {
  final l10n = context.l10n;
  final shareOriginal = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.media_share_correctionFailedTitle),
      content: Text(l10n.media_share_correctionFailedBody(failedCount)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.media_share_shareOriginal),
        ),
      ],
    ),
  );
  return shareOriginal ?? false;
}
