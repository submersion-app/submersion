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
///
/// Returns whether the sheet was opened with at least one file. The library's
/// selection bar turns that into a [BulkActionOutcome], which is what makes
/// Share leave multi-select the way every other bulk action does (#1262).
/// Opening the sheet counts as done even if the diver then dismisses it:
/// share_plus only reports a dismissal on mobile, so trusting the status
/// would make the bar behave differently on desktop for no gain.
Future<bool> shareMediaItems(
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

  // The dialog is popped before the platform call so the share sheet is not
  // raised behind a modal, which leaves the catch below with nothing of its
  // own to dismiss. Without this flag a throwing share popped a second time
  // and took the page the diver shared FROM with it.
  var dialogVisible = true;
  void dismissDialog() {
    if (!dialogVisible || !context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    dialogVisible = false;
  }

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

    dismissDialog();
    if (files.isEmpty) {
      if (context.mounted) {
        _showError(context, l10n.media_photoViewer_cannotShare);
      }
      return false;
    }
    await SharePlus.instance.share(
      ShareParams(files: files, sharePositionOrigin: sharePositionOrigin),
    );
    return true;
  } catch (e) {
    dismissDialog();
    if (context.mounted) {
      _showError(context, l10n.media_photoViewer_failedToShare(e.toString()));
    }
    return false;
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
