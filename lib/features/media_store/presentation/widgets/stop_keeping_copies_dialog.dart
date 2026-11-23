import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before this device stops keeping copies: from Photos and videos,
/// Advanced, and from the reconnect sheet (issue #4527, media library
/// decision 3). True only when the diver confirms.
Future<bool> confirmStopKeepingCopies(BuildContext context) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.settings_photos_stopKeeping),
      content: Text(l10n.settings_photos_stopKeepingBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.common_action_cancel),
        ),
        TextButton(
          key: const Key('media-s3-disconnect-confirm'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.settings_photos_stopKeeping),
        ),
      ],
    ),
  );
  return confirmed == true;
}
