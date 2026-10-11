import 'package:flutter/material.dart';

import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Expired" or "Expires in N days"; nothing for a document that is fine
/// or has no expiry.
class DocumentExpiryBadge extends StatelessWidget {
  final DocumentExpiryStatus status;

  const DocumentExpiryBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (String, Color, Color)? look = switch (status.kind) {
      DocumentExpiryKind.expired => (
        l10n.documents_badge_expired,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      DocumentExpiryKind.dueSoon => (
        l10n.documents_badge_expiresInDays(status.daysLeft!),
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      DocumentExpiryKind.ok || DocumentExpiryKind.none => null,
    };
    if (look == null) return const SizedBox.shrink();
    final (text, background, foreground) = look;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
