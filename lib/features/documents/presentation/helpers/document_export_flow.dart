import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/shared/export_file_name.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/data/services/document_archive_exporter.dart';
import 'package:submersion/features/documents/data/services/document_export_dirs.dart';
import 'package:submersion/features/documents/domain/document_archive_layout.dart';
import 'package:submersion/features/documents/domain/document_manifest.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_export_progress_dialog.dart';
import 'package:submersion/features/documents/presentation/widgets/document_export_sheet.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

final _log = LoggerService.forClass(DocumentArchiveExporter);

const _zipMime = 'application/zip';

/// Exports every document of the active diver as a password-protected ZIP
/// (#3397): asks where it goes, asks for the password, writes the archive
/// under a progress dialog, then shares or saves it. Used by the Documents
/// page menu and by Transfer > Export. Every failure ends in a snackbar.
Future<void> exportAllDocuments(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));
  try {
    await _exportAllDocuments(context, ref, say);
  } catch (e, stack) {
    _log.error('Documents export failed', error: e, stackTrace: stack);
    say(l10n.documents_export_failed('$e'));
  }
}

Future<void> _exportAllDocuments(
  BuildContext context,
  WidgetRef ref,
  void Function(String text) say,
) async {
  final l10n = context.l10n;
  final navigator = Navigator.of(context, rootNavigator: true);
  final anchor = shareAnchorFrom(context);

  final repo = ref.read(documentRepositoryProvider);
  final catalog = ref.read(certificationCatalogSyncProvider);
  final entries = [
    // A certification with no custom title is named the way the Documents
    // page names it (#3366), not by its empty stored name.
    for (final e in await ref.read(allDocumentsProvider.future))
      withCertificationOwnerTitle(e, l10n, catalog: catalog),
  ];
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

  final tagsByDocument = await TagLinkRepository(
    TagScope.documents,
  ).getTagsByItem();
  final inputs = [
    for (final e in entries)
      _input(
        l10n,
        e,
        await repo.getPages(e.document.id, withBytes: false),
        tagNames: [
          for (final t in tagsByDocument[e.document.id] ?? const <Tag>[])
            t.name,
        ],
      ),
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
    '${fileNameDate(now)}.zip',
  );
  // Before the dialog opens, so a failure here cannot strand it.
  final dir = await newDocumentExportDir(now);
  if (!context.mounted) {
    await dir.delete(recursive: true);
    return;
  }
  final progress = ValueNotifier<DocumentExportProgress>((
    done: 0,
    total: plan.files.length + 1,
  ));
  var cancelled = false;
  // Its own route, so closing removes this dialog even if something else
  // was pushed above it during a long export.
  final dialog = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DocumentExportProgressDialog(
      progress: progress,
      onCancel: () => cancelled = true,
    ),
  );
  unawaited(navigator.push(dialog));
  void closeDialog() {
    if (!dialog.isActive) return;
    if (dialog.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(dialog);
    }
  }

  var keepForShare = false;
  try {
    final path = p.join(dir.path, fileName);
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
    final String? delivered;
    switch (destination) {
      case ExportDestination.share:
        keepForShare = true;
        delivered = await shareFileAtPath(
          path,
          fileName,
          _zipMime,
          dialogTitle: l10n.documents_export_title,
          sharePositionOrigin: anchor,
        );
      case ExportDestination.saveToFile:
        delivered = await saveBytesToFile(
          await File(path).readAsBytes(),
          fileName,
          dialogTitle: l10n.documents_export_title,
          mimeType: _zipMime,
        );
    }
    if (delivered != null) say(l10n.documents_export_done);
  } on DocumentExportCancelled {
    closeDialog();
    say(l10n.documents_export_cancelled);
  } catch (_) {
    closeDialog();
    rethrow;
  } finally {
    // progress is not disposed here: the dialog is still listening while it
    // animates out, and a ValueNotifier holds nothing that needs releasing.
    if (!keepForShare) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException catch (e) {
        _log.warning('Could not remove export temp space: $e');
      }
    }
  }
}

ArchiveDocumentInput _input(
  AppLocalizations l10n,
  DocumentListEntry entry,
  List<DocumentPage> pages, {
  List<String> tagNames = const [],
}) {
  final doc = entry.document;
  final String? record;
  if (doc.owner.isPersonal) {
    record = null;
  } else {
    record = _recordFolder(entry) ?? l10n.documents_export_unknownRecord;
  }
  return ArchiveDocumentInput(
    document: doc,
    displayTitle: documentDisplayTitle(l10n, doc, ownerLabel: entry.ownerLabel),
    kindFolder: documentOwnerKindLabel(l10n, doc.owner.kind),
    recordFolder: record,
    pages: pages,
    tagNames: tagNames,
  );
}

/// The folder a document's record gets: its owner label, and for a dive
/// (#3391's `#142 · Blue Hole`) the date too, as `#142 Blue Hole
/// 2026-10-12` so dive folders sort by date. Null when the record is gone.
String? _recordFolder(DocumentListEntry entry) {
  final label = entry.ownerLabel?.trim();
  final date = entry.ownerDate;
  if (date == null) return label == null || label.isEmpty ? null : label;
  return [
    if (label != null && label.isNotEmpty) label.replaceAll(' · ', ' '),
    fileNameDate(date),
  ].join(' ');
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
    l10n.documents_export_manifest_tags,
  ],
  type: (t) => documentTypeLabel(l10n, t),
  kind: (k) => documentOwnerKindLabel(l10n, k),
  front: l10n.documents_export_front,
  back: l10n.documents_export_back,
);
