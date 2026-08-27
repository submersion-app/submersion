import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/core/utils/share_anchor.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/document_import_service.dart';
import 'package:submersion/features/media/data/services/media_share_temp_file.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/document_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/services/files/picked_file_materializer.dart';

/// Routes document attachments: PDFs to the in-app viewer, other formats
/// to the platform; and hosts the pick-and-attach flow shared by dives and
/// sites.
class DocumentOpenHelper {
  /// Route a tapped document: PDFs to the in-app viewer, everything else
  /// to the platform (desktop-open vs mobile-share duality).
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    if (item.isPdf) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => DocumentViewerPage(item: item),
        ),
      );
      return;
    }
    await openExternally(context, ref, item);
  }

  // coverage:ignore-start
  // Shells out to Process.run / the platform share sheet; exercised by
  // manual desktop smoke tests.
  /// Resolves the document to a temp file and opens it outside the app:
  /// the platform opener on desktop, the share sheet on mobile.
  static Future<void> openExternally(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final l10n = context.l10n;
    // Captured before the awaits: on iPad this anchors the share popover to
    // whatever the caller tapped, instead of the middle of the screen.
    final anchor = shareAnchorFrom(context);
    final resolved = await ref.read(mediaBytesProvider(item).future);
    if (resolved.isUnavailable || resolved.bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.media_documentViewer_unavailable)),
        );
      }
      return;
    }
    final file = await writeShareTempFile(item, resolved.bytes!);
    if (Platform.isMacOS) {
      await Process.run('open', [file.path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [file.path]);
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: item.shareMimeType)],
          sharePositionOrigin: anchor,
        ),
      );
    }
  }

  /// Opens the document picker and attaches the selection to exactly one
  /// of [diveId] / [siteId] by reference.
  static Future<void> pickAndAttach({
    required BuildContext context,
    required WidgetRef ref,
    String? diveId,
    String? siteId,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: DocumentImportService.allowedExtensions,
    );
    if (result.isEmpty || !context.mounted) return;
    // identifier travels with path: on Android it is the SAF content URI of
    // the original, and path is only a local copy. The import service needs
    // the URI to take a persistable permission (issue #1002); it is null on
    // every other platform.
    //
    // file_picker 12 dropped PlatformFile.identifier and exposes the SAF URI
    // as `uri` instead, so a non-file scheme IS the identifier; a plain
    // file: pick has none, matching the old null on other platforms. It also
    // leaves `path` null for those picks, so materialize them rather than
    // skipping: silently dropping would make Attach document look like it
    // did nothing.
    final List<LocalPickedFile> local;
    try {
      local = await materializePickedFiles(result);
    } on PickedFileMaterializationException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_import_failedToImportError(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    final picked = [
      for (final f in local)
        (
          path: f.path,
          filename: f.name,
          identifier: f.uri.isScheme('file') ? null : f.uri.toString(),
        ),
    ];
    if (picked.isEmpty) return;

    try {
      final service = ref.read(documentImportServiceProvider);
      final created = await service.importDocuments(
        picked: picked,
        diveId: diveId,
        siteId: siteId,
      );
      if (siteId != null) {
        ref.invalidate(mediaForSiteProvider(siteId));
        ref.invalidate(mediaCountForSiteProvider(siteId));
      }
      if (diveId != null) {
        ref.invalidate(mediaForDiveProvider(diveId));
        ref.invalidate(mediaCountForDiveProvider(diveId));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_documentViewer_attached(created.length),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_import_failedToImportError(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // coverage:ignore-end
}
