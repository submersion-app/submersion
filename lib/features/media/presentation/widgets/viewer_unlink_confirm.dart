import 'package:flutter/material.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_photo_remove_dialog.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_unlink.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('ViewerUnlinkConfirm', category: LogCategory.media);

/// Asks before the media viewer holds an Unlink (issue #5126), as the Unlink
/// of the screen [scope] names asks (a dive's or a site's Media card, the
/// library's selection bar, or a gear item's Remove), worded for the one
/// item on screen. Where the item
/// would leave the library with a caption or favorite on it, says those are
/// lost, as the library's does.
Future<bool> confirmViewerUnlink(
  BuildContext context,
  WidgetRef ref,
  ViewerUnlinkScope scope,
  String mediaId,
) async {
  if (scope == ViewerUnlinkScope.gear) {
    return confirmRemoveGearPhotos(context, 1);
  }
  final ids = [mediaId];
  final Set<String> atRisk;
  try {
    atRisk = await switch (scope) {
      ViewerUnlinkScope.dive =>
        ref.read(mediaUnlinkServiceProvider).idsWithUserMetadataAtRisk(ids),
      ViewerUnlinkScope.site =>
        ref
            .read(mediaUnlinkServiceProvider)
            .idsWithUserMetadataAtRiskForSite(ids),
      _ => ref.read(mediaRepositoryProvider).idsWithUserMetadata(ids),
    };
  } catch (error, stackTrace) {
    // The note is a courtesy: a read that fails leaves it out, and the
    // dialog still asks.
    _log.error(
      'Reading what an unlink would lose failed',
      error: error,
      stackTrace: stackTrace,
    );
    return context.mounted && await _ask(context, scope, const {});
  }
  if (!context.mounted) return false;
  return _ask(context, scope, atRisk);
}

Future<bool> _ask(
  BuildContext context,
  ViewerUnlinkScope scope,
  Set<String> atRisk,
) async {
  final l10n = context.l10n;
  final (title, body, action) = switch (scope) {
    ViewerUnlinkScope.site => (
      l10n.media_siteMediaSection_unlinkSelectedTitle(1),
      l10n.media_viewer_unlinkConfirmSiteBody,
      l10n.media_diveMediaSection_unlinkButton,
    ),
    ViewerUnlinkScope.library => (
      l10n.media_library_unlinkConfirmTitle(1),
      l10n.media_library_unlinkConfirmBody,
      l10n.media_library_unlinkSelected,
    ),
    _ => (
      l10n.media_diveMediaSection_unlinkSelectedTitle(1),
      l10n.media_viewer_unlinkConfirmDiveBody,
      l10n.media_diveMediaSection_unlinkButton,
    ),
  };
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(
        atRisk.isEmpty
            ? body
            : '$body\n\n${l10n.media_library_unlinkMetadataNote(atRisk.length)}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        TextButton(
          key: const ValueKey('viewer_unlink_confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
