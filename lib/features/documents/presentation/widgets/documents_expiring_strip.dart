import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/widgets/document_expiry_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Needs attention": the expired and soon-due documents, as a row of
/// cards above the list. Shows nothing when everything is fine.
class DocumentsExpiringStrip extends ConsumerWidget {
  final List<DocumentListEntry> entries;
  final ValueChanged<String> onOpen;

  const DocumentsExpiringStrip({
    super.key,
    required this.entries,
    required this.onOpen,
  });

  /// The entries that need attention, expired first, then soonest.
  static List<(DocumentListEntry, DocumentExpiryStatus)> due(
    List<DocumentListEntry> entries,
    DateTime now,
  ) {
    final out = [
      for (final e in entries) (e, documentExpiryStatus(e.document, now)),
    ].where((e) => e.$2.needsAttention).toList();
    out.sort((a, b) => a.$2.daysLeft!.compareTo(b.$2.daysLeft!));
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final items = due(entries, DateTime.now());
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            l10n.documents_expiring_title,
            style: theme.textTheme.titleSmall,
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (entry, status) = items[i];
              final doc = entry.document;
              return SizedBox(
                width: 200,
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onOpen(doc.id),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(documentTypeIcon(doc.type), size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  documentDisplayTitle(l10n, doc),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          if (entry.ownerText(units) case final owner?)
                            Text(
                              owner,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          const Spacer(),
                          DocumentExpiryBadge(status: status),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
