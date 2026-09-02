import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/media/data/services/media_share_temp_file.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Resolves full-resolution bytes for [items], writes share temp files, and
/// opens the platform share sheet. Shows a modal progress indicator while
/// resolving and an error snackbar when nothing could be resolved. Shared by
/// the full-screen viewer (single item) and the library selection bar
/// (multi-item).
///
/// [anchor] is the iPad share popover's origin; pass the share button's rect
/// (see `shareAnchorFrom`). Ignored on every other platform.
Future<void> shareMediaItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items, {
  Rect? anchor,
}) async {
  final l10n = context.l10n;
  // Falls back to [context] so callers that only have a page or bar context
  // still anchor somewhere sensible instead of the middle of the screen.
  // Resolved up front: the progress dialog below and the awaits after it can
  // outlive the widget that supplied it.
  final sharePositionOrigin = anchor ?? shareAnchorFrom(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        const Center(child: CircularProgressIndicator(color: Colors.white)),
  );

  try {
    final files = <XFile>[];
    for (final item in items) {
      final resolved = await ref.read(
        resolvedFullResolutionProvider(item).future,
      );
      if (resolved.isUnavailable || resolved.bytes == null) continue;
      final file = await writeShareTempFile(item, resolved.bytes!);
      files.add(XFile(file.path, mimeType: item.shareMimeType));
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (files.isEmpty) {
      if (context.mounted) {
        _showError(context, l10n.media_photoViewer_cannotShare);
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: files, sharePositionOrigin: sharePositionOrigin),
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _showError(context, l10n.media_photoViewer_failedToShare(e.toString()));
    }
  }
}

void _showError(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}
