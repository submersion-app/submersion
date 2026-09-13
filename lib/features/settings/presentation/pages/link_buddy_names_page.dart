import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/buddies/presentation/legacy_buddy_conversion_actions.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/link_buddy_names_dive_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Data Tools > Link buddy names (#1831): links the legacy buddy
/// and dive-master text of every dive that has no linked buddies, after a
/// preview, with Undo.
class LinkBuddyNamesPage extends ConsumerStatefulWidget {
  const LinkBuddyNamesPage({super.key});

  @override
  ConsumerState<LinkBuddyNamesPage> createState() => _LinkBuddyNamesPageState();
}

class _LinkBuddyNamesPageState extends ConsumerState<LinkBuddyNamesPage> {
  /// Dive ids the diver unchecked.
  Set<String> _excluded = const {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dataAsync = ref.watch(linkBuddyNamesDataProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.buddies_linkText_page_title)),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _message(l10n.buddies_linkText_page_errorLoading('$error')),
        data: (data) => data == null || data.dives.isEmpty
            ? _message(l10n.buddies_linkText_page_empty)
            : _content(data),
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );

  Widget _content(LinkBuddyNamesData data) {
    final l10n = context.l10n;
    final selected = [
      for (final dive in data.dives)
        if (!_excluded.contains(dive.diveId)) dive,
    ];
    final summary = summarizeCandidates(selected);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              [
                l10n.buddies_linkText_page_summaryDives(summary.dives),
                l10n.buddies_linkText_page_summaryNew(summary.newBuddies),
                l10n.buddies_linkText_page_summaryExisting(
                  summary.existingBuddies,
                ),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: data.dives.length,
            itemBuilder: (context, i) {
              final dive = data.dives[i];
              return LinkBuddyNamesDiveRow(
                dive: dive,
                selected: !_excluded.contains(dive.diveId),
                onSelectedChanged: (value) => setState(
                  () => _excluded = value
                      ? {
                          for (final id in _excluded)
                            if (id != dive.diveId) id,
                        }
                      : {..._excluded, dive.diveId},
                ),
                onTap: () => _reviewOne(data, dive),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _linkSelected(data, selected),
                child: Text(
                  l10n.buddies_linkText_page_linkDives(selected.length),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reviews one dive in the per-dive sheet and links just that dive.
  Future<void> _reviewOne(LinkBuddyNamesData data, CandidateDive dive) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final reviewed = await showLegacyBuddyReviewSheet(
      context,
      plan: dive.plan,
      matcher: data.matcher,
    );
    if (reviewed == null || reviewed.isEmpty) return;
    await applyLegacyBuddyPlans(
      container: container,
      messenger: messenger,
      l10n: l10n,
      plans: [reviewed],
      diverId: data.diverId,
      successMessage: (receipt) =>
          l10n.buddies_linkText_linkedSnackbar(receipt.linkIds.length),
    );
  }

  Future<void> _linkSelected(
    LinkBuddyNamesData data,
    List<CandidateDive> selected,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    await applyLegacyBuddyPlans(
      container: container,
      messenger: messenger,
      l10n: l10n,
      plans: [for (final dive in selected) dive.plan],
      diverId: data.diverId,
      successMessage: (receipt) =>
          l10n.buddies_linkText_page_linkedSnackbar(receipt.diveIds.length),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _excluded = const {};
    });
  }
}
