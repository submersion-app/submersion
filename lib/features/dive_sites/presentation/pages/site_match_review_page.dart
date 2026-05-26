import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';

/// Reviews auto-matched dives and lets the user resolve ambiguous/unmatched
/// ones. Reached post-download (seeded with imported dive ids) and from the
/// dives-list overflow menu (null = whole eligible backlog).
class SiteMatchReviewPage extends ConsumerWidget {
  const SiteMatchReviewPage({super.key, this.diveIds});

  final List<String>? diveIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(siteMatchReviewProvider(diveIds));
    final notifier = ref.read(siteMatchReviewProvider(diveIds).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Sites'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Builder(
        builder: (_) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            return Center(child: Text(state.errorMessage!));
          }
          if (state.entries.isEmpty) {
            return const Center(child: Text('Nothing to match.'));
          }
          return ListView(
            children: [
              _Summary(
                matched: state.matchedCount,
                review: state.reviewCount,
                noMatch: state.noMatchCount,
              ),
              for (final e in state.entries)
                _EntryTile(
                  entry: e,
                  onUnlink: () => notifier.unlink(e.dive.id),
                  onPick: (cid) => notifier.link(e.dive.id, cid),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.matched,
    required this.review,
    required this.noMatch,
  });

  final int matched;
  final int review;
  final int noMatch;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      '$matched matched · $review to review · $noMatch no match',
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onUnlink,
    required this.onPick,
  });

  final DiveMatchEntry entry;
  final VoidCallback onUnlink;
  final void Function(String candidateId) onPick;

  @override
  Widget build(BuildContext context) {
    final title = 'Dive #${entry.dive.diveNumber ?? '?'}';
    switch (entry.status) {
      case MatchEntryStatus.autoMatched:
        return ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(title),
          subtitle: Text(
            '${entry.siteName} · ${entry.distanceMeters?.round()} m'
            '${entry.isNewlyCreated ? ' · newly added' : ''}',
          ),
          trailing: TextButton(
            onPressed: onUnlink,
            child: const Text('Unlink'),
          ),
        );
      case MatchEntryStatus.needsReview:
        return ExpansionTile(
          leading: const Icon(Icons.help_outline),
          title: Text(title),
          subtitle: Text('${entry.candidates.length} nearby sites'),
          children: [
            for (final c in entry.candidates)
              ListTile(
                title: Text(c.name),
                subtitle: Text(
                  '${c.distanceMeters.round()} m · '
                  '${c.isExisting ? 'your site' : 'import'}',
                ),
                onTap: () => onPick(c.id),
              ),
          ],
        );
      case MatchEntryStatus.noMatch:
        return ListTile(
          leading: const Icon(Icons.location_off_outlined),
          title: Text(title),
          subtitle: const Text('No nearby site'),
        );
    }
  }
}
