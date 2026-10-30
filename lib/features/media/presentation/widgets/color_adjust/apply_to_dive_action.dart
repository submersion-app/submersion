import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(ColorAdjustment);

/// "Apply to this dive" (issue #3520): gives every other photo and video on
/// [item]'s dive the sliders and Auto switch of [source], each keeping its
/// own white point and its own depth-based automatic fix.
///
/// Asks first, naming how many items change, and offers Undo afterwards,
/// because this rewrites synced adjustments the diver may have tuned by
/// hand. Nothing happens when the dive has no other media.
Future<void> runApplyToDive(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
  ColorAdjustment source,
) async {
  final diveId = item.diveId;
  if (diveId == null) return;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
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

  final Map<String, ColorAdjustment?> prior;
  try {
    prior = await repository.applySlidersToDive(
      diveId: diveId,
      sourceMediaId: item.id,
      source: source,
    );
  } catch (e, stackTrace) {
    _log.error('Apply to dive failed', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.media_color_saveFailed)),
    );
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.media_color_appliedToDive(prior.length)),
      duration: const Duration(seconds: 5),
      persist: false,
      showCloseIcon: true,
      action: SnackBarAction(
        label: l10n.media_color_undo,
        // A failed restore says so: the banner that offered Undo is already
        // gone, so silence would read as success.
        onPressed: () async {
          try {
            await repository.restoreColorAdjustments(prior);
          } catch (e, stackTrace) {
            _log.error(
              'Undo apply to dive failed',
              error: e,
              stackTrace: stackTrace,
            );
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.media_color_undoFailed)),
            );
          }
        },
      ),
    ),
  );
}
