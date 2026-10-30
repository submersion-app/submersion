import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

// coverage:ignore-start
// Shells out to Process.run / the platform share sheet, like
// DocumentOpenHelper.openExternally; exercised by manual smoke tests.

/// Opens [page] outside the app from a temp copy of its bytes: the
/// platform opener on desktop, the share sheet on mobile. Used for pages
/// the app cannot render (Word, text) and as the fallback for one that
/// fails to render.
Future<void> openDocumentPageExternally(
  BuildContext context,
  DocumentPage page,
) async {
  if (!demoSealGuard(context, DemoSealedFeature.share)) {
    return;
  }
  // Captured before the awaits: on iPad this anchors the share popover to
  // whatever the caller tapped.
  final anchor = shareAnchorFrom(context);
  final messenger = ScaffoldMessenger.of(context);
  final unavailable = context.l10n.documents_page_cannotDisplay;
  final bytes = page.bytes;
  if (bytes == null) {
    messenger.showSnackBar(SnackBar(content: Text(unavailable)));
    return;
  }
  final dir = Directory(
    p.join((await getTemporaryDirectory()).path, 'documents', page.id),
  );
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, p.basename(page.fileName)));
  await file.writeAsBytes(bytes);
  if (Platform.isMacOS) {
    await Process.run('open', [file.path]);
  } else if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', file.path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [file.path]);
  } else {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: page.mimeType)],
        sharePositionOrigin: anchor,
      ),
    );
  }
}

// coverage:ignore-end
