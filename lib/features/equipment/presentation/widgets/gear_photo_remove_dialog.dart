import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before removing [count] gear photos (issue #3355). Removing unlinks:
/// a photo nothing else holds leaves Submersion, and the file is never
/// touched. Shared by the Photos card, the check-in photos and the Gear
/// gallery so the wording stays one.
Future<bool> confirmRemoveGearPhotos(BuildContext context, int count) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.equipment_photos_removeConfirmTitle(count)),
      content: Text(l10n.equipment_photos_removeConfirmContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.media_diveMediaSection_cancelButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.equipment_photos_remove),
        ),
      ],
    ),
  );
  return confirmed == true;
}
