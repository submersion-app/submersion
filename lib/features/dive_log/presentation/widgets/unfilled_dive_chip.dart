import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Where a dive that waits for its dive computer readings stands: a plan
/// (issue #2002), or a draft marked at the site (issue #637) that is still
/// in the water or waiting for its download.
enum UnfilledDiveState { planned, inWater, awaitingDownload }

/// The state for a dive's flags, or null for a logged dive. A dive with both
/// flags reads as the draft: it happened.
UnfilledDiveState? unfilledDiveStateOf({
  required bool isPlanned,
  required bool isDraft,
  bool isOpenDraft = false,
}) {
  if (isDraft) {
    return isOpenDraft
        ? UnfilledDiveState.inWater
        : UnfilledDiveState.awaitingDownload;
  }
  return isPlanned ? UnfilledDiveState.planned : null;
}

/// The title an unfilled dive shows where a logged one shows "Dive #N", or
/// null for a logged dive: a plan or draft has no number yet.
String? unfilledDiveTitle(
  BuildContext context, {
  required bool isPlanned,
  required bool isDraft,
}) => switch (unfilledDiveStateOf(isPlanned: isPlanned, isDraft: isDraft)) {
  null => null,
  UnfilledDiveState.planned => context.l10n.diveLog_planned_bannerTitle,
  UnfilledDiveState.inWater ||
  UnfilledDiveState.awaitingDownload => context.l10n.diveLog_draft_title,
};

/// A dive list tile's screen-reader label, for both list styles: an unfilled dive's leaves the number out,
/// since the list's fallback number belongs to another dive.
String diveTileSemanticsLabel(
  BuildContext context,
  UnfilledDiveState? state,
  int diveNumber,
  String? siteName,
) {
  final l10n = context.l10n;
  final site = siteName ?? l10n.diveLog_listPage_unknownSite;
  return switch (state) {
    null => l10n.diveLog_listPage_semanticsDiveAtSite(diveNumber, site),
    UnfilledDiveState.planned =>
      l10n.diveLog_listPage_semanticsPlannedDiveAtSite(site),
    UnfilledDiveState.inWater || UnfilledDiveState.awaitingDownload =>
      l10n.diveLog_listPage_semanticsDraftDiveAtSite(site),
  };
}

/// The icon that stands in for the number badge: an unfilled dive holds no
/// number, and the list passes its position as a fallback that belongs to
/// another dive.
IconData unfilledDiveIcon(UnfilledDiveState state) => switch (state) {
  UnfilledDiveState.planned => Icons.event_available_outlined,
  UnfilledDiveState.inWater ||
  UnfilledDiveState.awaitingDownload => Icons.hourglass_top_outlined,
};

/// The marker on a dive list tile for a dive waiting for its readings:
/// "Planned", "In the water" or "Waiting for download". The text stays in
/// the semantics tree on purpose: the tile's own label says only "Dive N at
/// site", so without it a screen reader could not tell these dives from a
/// logged one.
class UnfilledDiveChip extends StatelessWidget {
  const UnfilledDiveChip({super.key, required this.state});

  final UnfilledDiveState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final planned = state == UnfilledDiveState.planned;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: planned ? scheme.tertiaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        switch (state) {
          UnfilledDiveState.planned => l10n.diveLog_planned_chip,
          UnfilledDiveState.inWater => l10n.diveLog_draft_inWaterChip,
          UnfilledDiveState.awaitingDownload => l10n.diveLog_draft_chip,
        },
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: planned
              ? scheme.onTertiaryContainer
              : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
