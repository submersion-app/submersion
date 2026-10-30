import 'package:flutter/material.dart';

import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/widgets/document_expiry_badge.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_thumbnail.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One document in a list: first-page thumbnail, title, where it is filed
/// and who issued it, its expiry badge and its tags. The badge sits under
/// the text, not in trailing, so a long translation never squeezes the
/// title.
class DocumentTile extends StatelessWidget {
  final Document document;
  final String? ownerLabel;
  final VoidCallback? onTap;
  final bool selected;

  /// The document's tags, up to three shown (issue #1970). The list passes
  /// them in, so the tile watches no provider of its own.
  final List<Tag> tags;

  /// Defaults to the document's first page; tests pass a plain widget.
  final Widget? thumbnail;

  const DocumentTile({
    super.key,
    required this.document,
    this.ownerLabel,
    this.onTap,
    this.selected = false,
    this.tags = const [],
    this.thumbnail,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = documentExpiryStatus(document, DateTime.now());
    // A card is titled by its certification, so naming it again below
    // would only repeat the title.
    final card = document.type == DocumentType.certificationCard;
    final details = [
      if (!card) ?ownerLabel,
      if (document.issuer?.trim() case final issuer? when issuer.isNotEmpty)
        issuer,
    ].join(' · ');
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: thumbnail ?? DocumentPageThumbnail(document: document),
      title: Text(
        documentDisplayTitle(l10n, document, ownerLabel: ownerLabel),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: details.isEmpty && !status.needsAttention && tags.isEmpty
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
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  TagChips(tags: tags),
                ],
              ],
            ),
    );
  }
}
