import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/data/services/document_archive_exporter.dart';
import 'package:submersion/features/documents/domain/document_archive_layout.dart';
import 'package:submersion/features/documents/domain/document_manifest.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_export_progress_dialog.dart';
import 'package:submersion/features/documents/presentation/widgets/document_export_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

final _log = LoggerService.forClass(DocumentArchiveExporter);

const _zipMime = 'application/zip';

/// Exports every document of the active diver as a password-protected ZIP
/// (#3397): asks where it goes, asks for the password, writes the archive
/// under a progress dialog, then shares or saves it. Used by the Documents
/// page menu and by Transfer > Export.
Future<void> exportAllDocuments(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final anchor = shareAnchorFrom(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  final repo = ref.read(documentRepositoryProvider);
  final entries = await ref.read(allDocumentsProvider.future);
  if (entries.isEmpty) {
    say(l10n.documents_export_nothing);
    return;
  }
  if (!context.mounted) return;
  final destination = await showExportDestinationSheet(
    context,
    title: l10n.documents_export_title,
  );
  if (destination == null || !context.mounted) return;

  final inputs = [
    for (final e in entries)
      _input(l10n, e, await repo.getPages(e.document.id, withBytes: false)),
  ];
  if (!context.mounted) return;
  final password = await showDocumentExportSheet(
    context,
    documentCount: inputs.length,
    fileCount: inputs.fold(0, (n, i) => n + i.pages.length),
  );
  if (password == null || !context.mounted) return;

  final plan = planDocumentArchive(
    inputs,
    ArchiveNames(
      front: l10n.documents_export_front,
      back: l10n.documents_export_back,
      page: l10n.documents_export_page,
    ),
  );
  final now = DateTime.now();
  final fileName = sanitizeArchiveSegment(
    '${l10n.documents_export_fileNamePrefix} '
    '${DateFormat('yyyy-MM-dd').format(now)}.zip',
  );
  final progress = ValueNotifier<DocumentExportProgress>((
    done: 0,
    total: plan.files.length + 1,
  ));
  var cancelled = false;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DocumentExportProgressDialog(
        progress: progress,
        onCancel: () => cancelled = true,
      ),
    ),
  );

  final temp = await Directory.systemTemp.createTemp(
    'submersion_documents_export_',
  );
  var dialogOpen = true;
  void closeDialog() {
    if (dialogOpen) navigator.pop();
    dialogOpen = false;
  }

  try {
    final path = p.join(temp.path, fileName);
    await DocumentArchiveExporter(repo).write(
      plan: plan,
      manifestCsv: buildDocumentManifestCsv(inputs, plan, _manifest(l10n)),
      password: password,
      outputPath: path,
      now: now,
      onProgress: (done, total) => progress.value = (done: done, total: total),
      isCancelled: () => cancelled,
    );
    closeDialog();
    final delivered = switch (destination) {
      ExportDestination.share => await shareFileAtPath(
        path,
        fileName,
        _zipMime,
        dialogTitle: l10n.documents_export_title,
        sharePositionOrigin: anchor,
      ),
      ExportDestination.saveToFile => await saveBytesToFile(
        await File(path).readAsBytes(),
        fileName,
        dialogTitle: l10n.documents_export_title,
        mimeType: _zipMime,
      ),
    };
    if (delivered != null) say(l10n.documents_export_done);
  } on DocumentExportCancelled {
    closeDialog();
    say(l10n.documents_export_cancelled);
  } catch (e, stack) {
    closeDialog();
    _log.error('Documents export failed', error: e, stackTrace: stack);
    say(l10n.documents_export_failed('$e'));
  } finally {
    progress.dispose();
    try {
      await temp.delete(recursive: true);
    } on FileSystemException catch (e) {
      _log.warning('Could not remove export temp space: $e');
    }
  }
}

ArchiveDocumentInput _input(
  AppLocalizations l10n,
  DocumentListEntry entry,
  List<DocumentPage> pages,
) {
  final doc = entry.document;
  final String? record;
  if (doc.owner.isPersonal) {
    record = null;
  } else {
    record =
        entry.dive?.folderName() ??
        entry.ownerLabel ??
        l10n.documents_export_unknownRecord;
  }
  return ArchiveDocumentInput(
    document: doc,
    displayTitle: documentDisplayTitle(l10n, doc, ownerLabel: entry.ownerLabel),
    kindFolder: documentOwnerKindLabel(l10n, doc.owner.kind),
    recordFolder: record,
    pages: pages,
  );
}

ManifestLabels _manifest(AppLocalizations l10n) => ManifestLabels(
  headers: [
    l10n.documents_export_manifest_title,
    l10n.documents_export_manifest_type,
    l10n.documents_export_manifest_kind,
    l10n.documents_export_manifest_filedUnder,
    l10n.documents_export_manifest_issuer,
    l10n.documents_export_manifest_reference,
    l10n.documents_export_manifest_issueDate,
    l10n.documents_export_manifest_expiryDate,
    l10n.documents_export_manifest_notes,
    l10n.documents_export_manifest_emergencyPhone,
    l10n.documents_export_manifest_phone,
    l10n.documents_export_manifest_page,
    l10n.documents_export_manifest_side,
    l10n.documents_export_manifest_path,
  ],
  type: (t) => documentTypeLabel(l10n, t),
  kind: (k) => documentOwnerKindLabel(l10n, k),
  front: l10n.documents_export_front,
  back: l10n.documents_export_back,
);
