import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart'
    show compute, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_file_types.dart';
import 'package:submersion/features/media/presentation/helpers/media_drop_destination.dart';
import 'package:submersion/features/media/presentation/helpers/media_drop_import.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/universal_import/data/services/batch_parse_service.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/services/incoming_file_handler.dart';

/// Wraps content with a desktop drag-and-drop target that navigates to the
/// import wizard when a supported file is dropped.
///
/// Photos and videos are not dive logs. Dropped on a screen that takes them
/// (the Media section, a dive, a site; see [mediaDropDestinationFor]) they
/// open that screen's media importer instead; dropped anywhere else they
/// earn a hint saying where to drop them (issue #2488). A drop mixing both
/// kinds sends each kind its own way, the media first.
///
/// This is the window's only drop target on purpose: desktop_drop delivers
/// every drop to every live target, including those hidden under a pushed
/// page, so screens cannot simply nest their own.
///
/// On non-desktop platforms, this widget passes through [child] unchanged.
/// Shows a frosted glass overlay when a file is dragged over the app.
class GlobalDropTarget extends ConsumerStatefulWidget {
  const GlobalDropTarget({
    super.key,
    required this.child,
    this.onMediaDrop = importDroppedMedia,
  });

  final Widget child;

  /// Imports dropped photos and videos; a seam for tests, which cannot drive
  /// the photo picker the default opens.
  final MediaDropHandler onMediaDrop;

  @override
  ConsumerState<GlobalDropTarget> createState() => _GlobalDropTargetState();
}

class _GlobalDropTargetState extends ConsumerState<GlobalDropTarget> {
  bool _isDragging = false;

  static bool get _isDesktop {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return widget.child;

    return DropTarget(
      onDragEntered: (_) {
        if (mounted) setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        if (mounted) setState(() => _isDragging = false);
      },
      onDragDone: (details) => _handleDrop(details),
      child: Stack(
        children: [widget.child, if (_isDragging) const _FrostedDropOverlay()],
      ),
    );
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (mounted) setState(() => _isDragging = false);

    if (details.files.isEmpty) return;

    // Check wizard-active BEFORE reading bytes to avoid unnecessary I/O and
    // to ensure the "wizard active" message always takes precedence over a
    // read-failure snackbar. An open photo picker counts too: a second one
    // opened over it would clear the files the first has staged.
    if (!mounted) return;
    final routerState = GoRouterState.of(context);
    final currentPath = routerState.uri.path;
    if (currentPath.startsWith('/transfer/import-wizard') ||
        ref.read(openPhotoPickerSessionsProvider).value > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.dropTarget_error_wizardActive)),
      );
      return;
    }
    final mediaDestination = mediaDropDestinationFor(context, ref);

    // Split the drop into photos and videos and dive logs, expanding any
    // dropped folders into the files of each kind they hold. A folder is
    // searched for media even where media cannot go, so a folder of photos
    // dropped there earns the hint rather than ending in silence.
    final mediaPaths = <String>[];
    final diveLogPaths = <String>[];
    for (final xFile in details.files) {
      final path = xFile.path;
      if (path.isEmpty) continue;
      if (FileSystemEntity.isDirectorySync(path)) {
        mediaPaths.addAll(await compute(scanFolderForMediaFiles, path));
        diveLogPaths.addAll(await scanFolderForImportableFiles(path));
      } else if (isLinkableMediaPath(path)) {
        mediaPaths.add(path);
      } else {
        diveLogPaths.add(path);
      }
    }
    if (!mounted) return;

    if (mediaPaths.isNotEmpty) {
      if (mediaDestination == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dropTarget_error_mediaNeedsDestination),
          ),
        );
      } else {
        // Awaited, so dive logs in the same drop open their wizard only
        // after the media importer closes, rather than underneath it.
        await widget.onMediaDrop(context, ref, mediaDestination, mediaPaths);
        if (!mounted) return;
      }
    }

    await _importDiveLogs(diveLogPaths);
  }

  /// Sends dropped dive-log files to the import wizard.
  Future<void> _importDiveLogs(List<String> paths) async {
    if (paths.isEmpty || !mounted) return;
    // Re-read: a media import that ran first may have moved the user on.
    final currentPath = GoRouterState.of(context).uri.path;

    if (paths.length > 1) {
      await ref
          .read(universalImportNotifierProvider.notifier)
          .loadFilesFromPaths(paths);
      if (!mounted) return;
      context.push('/transfer/import-wizard');
      return;
    }

    // Single file: keep the existing byte-based path (share-intent parity).
    final Uint8List bytes;
    try {
      bytes = await File(paths.first).readAsBytes();
    } catch (e) {
      // Logged even when the target is gone; only the snackbar needs it.
      reportIncomingFileError(
        e,
        messenger: mounted ? ScaffoldMessenger.of(context) : null,
        readFailedMessage: mounted
            ? context.l10n.dropTarget_error_readFailed
            : null,
      );
      return;
    }

    if (!mounted) return;

    final fileName = p.basename(paths.first);
    final outcome = await handleIncomingFile(
      bytes: bytes,
      fileName: fileName,
      currentPath: currentPath,
      notifier: ref.read(universalImportNotifierProvider.notifier),
      messenger: ScaffoldMessenger.of(context),
      unsupportedFileMessage: context.l10n.dropTarget_error_unsupportedFile,
    );

    if (!mounted) return;

    switch (outcome) {
      case IncomingFileOutcome.navigateToWizard:
        context.push('/transfer/import-wizard');
      case IncomingFileOutcome.navigateToNavTrackReview:
        await navigateToNavTrackReview(context, bytes, fileName: fileName);
      case IncomingFileOutcome.none:
        break;
    }
  }
}

/// Frosted glass overlay shown when a file is dragged over the app.
class _FrostedDropOverlay extends StatelessWidget {
  const _FrostedDropOverlay();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Positioned.fill(
      child: IgnorePointer(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: ColoredBox(
            color: const Color(0xBF0A1628),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0x9964B4FF),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.upload_file,
                      size: 40,
                      color: Color(0xCC64B4FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.dropTarget_title,
                    style: const TextStyle(
                      color: Color(0xE664B4FF),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dropTarget_subtitle,
                    style: const TextStyle(
                      color: Color(0x99B4C8E6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
