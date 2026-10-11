import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';

/// A document's first page at thumbnail size: the image itself, or an icon
/// for a PDF, Word or text page (and for a document without pages).
class DocumentPageThumbnail extends ConsumerWidget {
  final Document document;
  final double size;

  const DocumentPageThumbnail({
    super.key,
    required this.document,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(documentFirstPageProvider(document.id)).value;
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _content(context, page),
      ),
    );
  }

  Widget _content(BuildContext context, DocumentPage? page) {
    final bytes = page?.bytes;
    if (page != null && page.isImage && bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (context, _, _) => _icon(context, page),
      );
    }
    return _icon(context, page);
  }

  Widget _icon(BuildContext context, DocumentPage? page) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (page) {
      DocumentPage(isPdf: true) => Icons.picture_as_pdf_outlined,
      DocumentPage() => Icons.insert_drive_file_outlined,
      null => documentTypeIcon(document.type),
    };
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(icon, color: scheme.primary, size: size * 0.5),
    );
  }
}
