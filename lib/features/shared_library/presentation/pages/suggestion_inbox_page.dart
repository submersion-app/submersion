import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_role_chip.dart';
import 'package:submersion/features/shared_library/presentation/widgets/suggestion_review_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Owners' inbox of reader suggestions, grouped by site (issue #2567).
class SuggestionInboxPage extends ConsumerWidget {
  const SuggestionInboxPage({super.key, required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final suggestions = ref.watch(incomingSuggestionsProvider(libraryId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharedLibrary_inbox_title)),
      body: suggestions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(l10n.sharedLibrary_inbox_empty));
          }
          final bySite = <String, List<SharedSiteSuggestion>>{};
          for (final s in list) {
            bySite.putIfAbsent(s.siteId, () => []).add(s);
          }
          return ListView(
            children: [
              for (final entry in bySite.entries)
                _SiteGroup(siteId: entry.key, suggestions: entry.value),
            ],
          );
        },
      ),
    );
  }
}

class _SiteGroup extends ConsumerWidget {
  const _SiteGroup({required this.siteId, required this.suggestions});

  final String siteId;
  final List<SharedSiteSuggestion> suggestions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final site = ref.watch(siteProvider(siteId));
    final name = site.valueOrNull?.name;
    final gone = site.hasValue && site.valueOrNull == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            name ?? (gone ? l10n.sharedLibrary_inbox_siteDeleted : ''),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final s in suggestions)
          ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: Text(
              l10n.sharedLibrary_inbox_from(
                s.memberName,
                libraryDateLabel(ref, s.createdAt),
              ),
            ),
            subtitle: s.note.isEmpty ? null : Text(s.note),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showSuggestionReviewSheet(
              context,
              suggestion: s,
              siteGone: gone,
            ),
          ),
      ],
    );
  }
}
