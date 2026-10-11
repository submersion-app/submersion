import 'package:flutter/material.dart';

import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/widgets/document_expiry_badge.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_thumbnail.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One document in a list: first-page thumbnail, title, where it is filed
/// and who issued it, and its expiry badge. The badge sits under the text,
/// not in trailing, so a long translation never squeezes the title.
class DocumentTile extends StatelessWidget {
  final Document document;
  final String? ownerLabel;
  final VoidCallback? onTap;
  final bool selected;

  /// Defaults to the document's first page; tests pass a plain widget.
  final Widget? thumbnail;

  const DocumentTile({
    super.key,
    required this.document,
    this.ownerLabel,
    this.onTap,
    this.selected = false,
    this.thumbnail,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = documentExpiryStatus(document, DateTime.now());
    final details = [
      ?ownerLabel,
      if (document.issuer?.trim() case final issuer? when issuer.isNotEmpty)
        issuer,
    ].join(' · ');
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: thumbnail ?? DocumentPageThumbnail(document: document),
      title: Text(
        documentDisplayTitle(l10n, document),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: details.isEmpty && !status.needsAttention
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (details.isNotEmpty)
                  Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (status.needsAttention) ...[
                  const SizedBox(height: 4),
                  DocumentExpiryBadge(status: status),
                ],
              ],
            ),
    );
  }
}
