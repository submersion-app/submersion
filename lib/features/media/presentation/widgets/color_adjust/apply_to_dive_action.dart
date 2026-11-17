import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/media/presentation/editing/photo_held_writes.dart';

/// "Apply to this dive" (issue #3520): gives every other photo and video on
/// [item]'s dive the sliders and Auto switch of the photo's colour, each
/// keeping its own white point and its own depth-based automatic fix.
///
/// Asks first, naming how many items change, because this rewrites
/// adjustments the diver may have tuned by hand. It is held in the photo's
/// [sitting] until Save, and Cancel undoes it (issue #4527). Nothing
/// happens with no sitting (it ended, or a device that cannot unlock), or
/// when the dive has no other media.
Future<void> runApplyToDive(
  BuildContext context,
  WidgetRef ref,
  MediaItem item, {
  required EditSession<PhotoRecord>? sitting,
}) async {
  final diveId = item.diveId;
  if (diveId == null || sitting == null) return;
  final l10n = context.l10n;
  final repository = ref.read(mediaColorAdjustmentRepositoryProvider);

  final count = await repository.countOtherMediaOnDive(diveId, item.id);
  if (count == 0 || !context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.media_color_applyToDiveTitle),
      content: Text(l10n.media_color_applyToDiveBody(count)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.common_action_apply),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (sitting.isDisposed || sitting.isFrozen) return;
  holdColorToDive(sitting, diveId: diveId, repository: repository);
}
