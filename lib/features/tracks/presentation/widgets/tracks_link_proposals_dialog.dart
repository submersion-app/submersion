import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_dive_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks whether to link each underwater track in [proposals] to the one
/// dive its recording overlaps (#4851), listing every track with that dive
/// and its site. True once the diver chooses Link; false for Not now or a
/// dismissal.
Future<bool> showTracksLinkProposalsDialog(
  BuildContext context,
  List<NavTrackLinkProposal> proposals,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('tracks-link-proposals-dialog'),
      title: Text(l10n.navTrack_match_confirmTitle(proposals.length)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.navTrack_match_confirmBody),
            const SizedBox(height: 8),
            for (final proposal in proposals) _ProposalTile(proposal: proposal),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.navTrack_match_notNow),
        ),
        FilledButton(
          key: const ValueKey('tracks-link-proposals-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.navTrack_match_confirmLink),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// One proposed link: the track's name (or the file it came from), then
/// when it was recorded, the dive and the dive's site.
class _ProposalTile extends ConsumerWidget {
  const _ProposalTile({required this.proposal});

  final NavTrackLinkProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final (:route, :dive) = proposal;
    // Wall-clock-as-UTC, as a dive's own entry time is.
    final recordedAt = DateTime.fromMillisecondsSinceEpoch(
      route.startTime,
      isUtc: true,
    );
    final siteName = dive.site?.name;
    return ListTile(
      key: ValueKey('tracks-link-proposal-${route.id}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.route_outlined),
      title: Text(
        route.name ?? route.sourceRef ?? l10n.navTrack_detail_defaultTrackTitle,
      ),
      subtitle: Text(
        [
          units.formatDateTime(recordedAt, l10n: l10n),
          navTrackDiveLabel(l10n, dive.id, dive),
          ?siteName,
        ].join(' · '),
      ),
    );
  }
}
