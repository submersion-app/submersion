import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/documents/data/services/document_page_capture.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/byte_format.dart';

/// Asks where a page comes from, captures it through [capture], and returns
/// [pages] with it put in the slot [side] names (replacing what was there)
/// or at the end; null when nothing was added. A refused capture says why.
/// The document form and a document page's Pages card both add pages
/// through it (issue #4527, phase 3).
Future<List<DocumentPage>?> addDocumentPage(
  BuildContext context, {
  required DocumentPageCapture capture,
  required List<DocumentPage> pages,
  required DocumentPageSide? side,
}) async {
  if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) return null;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final canUseCamera = HostPlatform.isAndroid || HostPlatform.isIOS;
  final source = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canUseCamera)
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.documents_pages_addCamera),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.documents_pages_addGallery),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(l10n.documents_pages_addFile),
            onTap: () => Navigator.pop(ctx, 'file'),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final PageCaptureResult result;
  try {
    result = switch (source) {
      'camera' => await capture.fromImage(ImageSource.camera, side: side),
      'gallery' => await capture.fromImage(ImageSource.gallery, side: side),
      _ => await capture.fromFile(side: side),
    };
  } catch (e) {
    // The page may have gone while the picker was open: drop the capture.
    if (!context.mounted) return null;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.media_import_failedToImportError('$e'))),
    );
    return null;
  }
  // As the form did: a page that has gone takes no page.
  if (!context.mounted) return null;
  final refusal = switch (result) {
    PageCaptureTooLarge(:final sizeBytes) => l10n.documents_pages_tooLarge(
      formatBytes(sizeBytes),
    ),
    PageCaptureUnsupported(:final extension) =>
      l10n.documents_pages_unsupported(extension),
    PageCaptureImageTooLarge() => l10n.profilePhoto_error_tooLarge,
    PageCaptureUndecodable() => l10n.profilePhoto_error_undecodable,
    PageCaptured() || PageCaptureCancelled() => null,
  };
  if (refusal != null) {
    messenger.showSnackBar(SnackBar(content: Text(refusal)));
    return null;
  }
  if (result is! PageCaptured) return null;
  final captured = result.page;
  final next = [
    for (final p in pages)
      if (side == null || p.side != side) p,
    captured,
  ];
  // A card face goes where the strip shows it, Front then Back ahead of the
  // other pages: the stored order is what the viewer pages through.
  return side == null
      ? next
      : [
          for (final s in DocumentPageSide.values)
            ...next.where((p) => p.side == s),
          ...next.where((p) => p.side == null),
        ];
}
