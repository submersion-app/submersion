import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/match_sites_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Staged review: compute proposals, choose a site per dive (list or map),
/// then Confirm to write all matches. Reached post-download and from the
/// dives-list overflow menu (diveIds == null = whole eligible backlog).
class SiteMatchReviewPage extends ConsumerWidget {
  const SiteMatchReviewPage({super.key, this.diveIds});

  final List<String>? diveIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(siteMatchReviewProvider(diveIds));
    final notifier = ref.read(siteMatchReviewProvider(diveIds).notifier);

    Future<void> onConfirm() async {
      final result = await notifier.confirm();
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.siteMatchReview_applyError)),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.siteMatchReview_appliedSnack(
              result.divesLinked,
              result.sitesCreated,
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    }

    Future<void> onCancel() async {
      if (state.selections.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.siteMatchReview_discardTitle),
          content: Text(l10n.siteMatchReview_discardMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.siteMatchReview_keepReviewing),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.siteMatchReview_discardConfirm),
            ),
          ],
        ),
      );
      if (discard == true && context.mounted) Navigator.of(context).pop();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.siteMatchReview_title)),
      body: Builder(
        builder: (_) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            return Center(child: Text(state.errorMessage!));
          }
          if (state.proposals.isEmpty) {
            return Center(child: Text(l10n.siteMatchReview_empty));
          }

          final summary = Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              l10n.siteMatchReview_summary(
                state.selectedCount,
                state.reviewCount,
                state.noMatchCount,
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final list = ListView(
                children: [
                  for (final p in state.proposals)
                    _DiveRow(
                      proposal: p,
                      focused: p.dive.id == state.focusedDiveId,
                      selectedCandidateId: state.selections[p.dive.id],
                      showInlineCards: !wide,
                      onFocus: () => notifier.focusDive(p.dive.id),
                      onSelect: (cid) => notifier.select(p.dive.id, cid),
                    ),
                ],
              );

              if (!wide) {
                return Column(
                  children: [
                    _MapPanel(state: state, notifier: notifier),
                    summary,
                    Expanded(child: list),
                  ],
                );
              }

              final focused = state.focusedProposal;
              return Row(
                children: [
                  Expanded(flex: 2, child: list),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _MapPanel(state: state, notifier: notifier),
                        summary,
                        Expanded(
                          child: ListView(
                            children: [
                              if (focused != null)
                                for (final c in focused.candidates)
                                  _CandidateCard(
                                    candidate: c,
                                    selected:
                                        c.id ==
                                        state.selections[focused.dive.id],
                                    onTap: () =>
                                        notifier.select(focused.dive.id, c.id),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: state.isLoading || state.proposals.isEmpty
          ? null
          : _ConfirmBar(
              count: state.selectedCount,
              busy: state.isApplying,
              onCancel: onCancel,
              onConfirm: state.selectedCount == 0 ? null : onConfirm,
            ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.state, required this.notifier});
  final SiteMatchReviewState state;
  final SiteMatchReviewNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final p = state.focusedProposal;
    final point = p?.dive.entryLocation ?? p?.dive.exitLocation;
    if (p == null || point == null) {
      return const SizedBox(height: 200);
    }
    return SizedBox(
      height: 200,
      child: MatchSitesMap(
        key: ValueKey(p.dive.id),
        divePoint: point,
        candidates: p.candidates,
        selectedCandidateId: state.selections[p.dive.id],
        onSelectCandidate: (cid) => notifier.select(p.dive.id, cid),
      ),
    );
  }
}

class _DiveRow extends StatelessWidget {
  const _DiveRow({
    required this.proposal,
    required this.focused,
    required this.selectedCandidateId,
    required this.showInlineCards,
    required this.onFocus,
    required this.onSelect,
  });

  final MatchProposal proposal;
  final bool focused;
  final String? selectedCandidateId;
  final bool showInlineCards;
  final VoidCallback onFocus;
  final void Function(String candidateId) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = 'Dive #${proposal.dive.diveNumber ?? '?'}';

    MatchCandidateView? selected;
    for (final c in proposal.candidates) {
      if (c.id == selectedCandidateId) {
        selected = c;
        break;
      }
    }

    final subtitle = switch (proposal.status) {
      ProposalStatus.none => l10n.siteMatchReview_noNearbySite,
      _ =>
        selected != null
            ? '${selected.name} · ${l10n.siteMatchReview_awayMeters(selected.distanceMeters.round())}'
            : l10n.siteMatchReview_tapToChoose,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          selected: focused,
          leading: Icon(
            selected != null
                ? Icons.check_circle
                : (proposal.status == ProposalStatus.none
                      ? Icons.location_off_outlined
                      : Icons.help_outline),
            color: selected != null ? Colors.green : null,
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: onFocus,
        ),
        if (focused && showInlineCards && proposal.candidates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                for (final c in proposal.candidates)
                  _CandidateCard(
                    candidate: c,
                    selected: c.id == selectedCandidateId,
                    onTap: () => onSelect(c.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final MatchCandidateView candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final c = candidate;

    final meta = <String>[
      l10n.siteMatchReview_awayMeters(c.distanceMeters.round()),
      if (c.minDepth != null && c.maxDepth != null)
        l10n.siteMatchReview_depthRange(
          c.minDepth!.round(),
          c.maxDepth!.round(),
        )
      else if (c.maxDepth != null)
        l10n.siteMatchReview_depthTo(c.maxDepth!.round()),
      if ((c.region ?? c.country) != null) (c.region ?? c.country)!,
    ];

    return Card(
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    c.isExisting
                        ? l10n.siteMatchReview_sourceExisting
                        : l10n.siteMatchReview_sourceBundled,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                meta.join(' · '),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (c.rating != null || c.difficulty != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (c.rating != null) '★ ${c.rating!.toStringAsFixed(1)}',
                      if (c.difficulty != null) c.difficulty!,
                    ].join(' · '),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (c.features.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final f in c.features) Chip(label: Text(f)),
                    ],
                  ),
                ),
              if (c.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    c.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.count,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  final int count;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onCancel,
                child: Text(l10n.siteMatchReview_cancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: busy ? null : onConfirm,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.siteMatchReview_confirm(count)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
