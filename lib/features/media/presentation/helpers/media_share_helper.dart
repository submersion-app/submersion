import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/share_preparation.dart';
import 'package:submersion/features/media/presentation/helpers/video_share_timeline.dart';
import 'package:submersion/features/media/presentation/widgets/video_correction_failed_dialog.dart';
import 'package:submersion/features/media/presentation/widgets/video_share_progress_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// Prepares share files for [items] and opens the platform share sheet.
/// Photos go out with their colour correction, and a video with a
/// correction is re-encoded with it (issues #3520, #3521). Shared by the
/// full-screen viewers (single item) and the library selection bar
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
}) => runShareFlow(
  context,
  anchor: anchor,
  // Only mobile systems stop an app's encoding when it leaves the screen;
  // a minimised desktop window keeps encoding.
  systemStopsEncodes: Platform.isIOS || Platform.isAndroid,
  showVideoProgress: items.any((item) => videoMayNeedCorrection(ref, item)),
  prepare: (onProgress, cancel, backgroundEntries) => prepareShareFiles(
    ref,
    items,
    onProgress: onProgress,
    cancel: cancel,
    backgroundEntries: backgroundEntries,
  ),
  originals: (failed) => originalShareFiles(ref, failed),
);

/// The dialogs around a share (issue #3521): a spinner, or the video
/// progress dialog with Cancel when [showVideoProgress], while [prepare]
/// works; then the share sheet, the "couldn't apply the colour correction"
/// question when a video failed (Share original adds [originals] of the
/// failed videos), or the message that the app going into the background
/// stopped it.
Future<bool> runShareFlow(
  BuildContext context, {
  required bool showVideoProgress,
  required Future<SharePreparation> Function(
    void Function(VideoShareProgress progress) onProgress,
    ColorEncodeCancel cancel,
    int Function() backgroundEntries,
  )
  prepare,
  required Future<List<XFile>> Function(List<MediaItem> failed) originals,
  Rect? anchor,
  bool systemStopsEncodes = true,
}) async {
  if (!demoSealGuard(context, DemoSealedFeature.share)) {
    return false;
  }
  final l10n = context.l10n;
  // Falls back to [context] so callers that only have a page or bar context
  // still anchor somewhere sensible instead of the middle of the screen.
  // Resolved up front: the progress dialog below and the awaits after it can
  // outlive the widget that supplied it.
  final sharePositionOrigin = anchor ?? shareAnchorFrom(context);
  final cancel = ColorEncodeCancel();
  final progress = ValueNotifier(const VideoShareProgress(index: 1, total: 1));
  // An encode that fails or stops while the app is away was stopped by the
  // system (iOS suspends video encoding in the background), not by a fault:
  // count the trips away so each encode can tell whether one fell inside it.
  var backgroundEntries = 0;
  final lifecycle = AppLifecycleListener(
    onHide: () {
      if (systemStopsEncodes) backgroundEntries++;
    },
  );

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => showVideoProgress
        ? VideoShareProgressDialog(progress: progress, onCancel: cancel.cancel)
        : const Center(child: CircularProgressIndicator(color: Colors.white)),
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
    final prepared = await prepare(
      (p) => progress.value = p,
      cancel,
      () => backgroundEntries,
    );
    dismissDialog();
    switch (prepared) {
      case ShareCancelled():
        return false;
      case ShareInterrupted():
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.media_share_videoInterrupted)),
          );
        }
        return false;
      case ShareReady(
        :final files,
        :final failedVideos,
        :final correctedCopies,
      ):
        var toShare = files;
        if (failedVideos.isNotEmpty) {
          final shareOriginal =
              context.mounted &&
              await showVideoCorrectionFailedDialog(
                context,
                failedCount: failedVideos.length,
              );
          if (!shareOriginal) {
            await deleteShareCopies(correctedCopies);
            return false;
          }
          toShare = [...files, ...await originals(failedVideos)];
        }
        if (toShare.isEmpty) {
          if (context.mounted) {
            _showError(context, l10n.media_photoViewer_cannotShare);
          }
          return false;
        }
        await SharePlus.instance.share(
          ShareParams(files: toShare, sharePositionOrigin: sharePositionOrigin),
        );
        return true;
    }
  } catch (e) {
    dismissDialog();
    if (context.mounted) {
      _showError(context, l10n.media_photoViewer_failedToShare(e.toString()));
    }
    return false;
  } finally {
    lifecycle.dispose();
    progress.dispose();
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
