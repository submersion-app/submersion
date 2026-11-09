import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/unfilled_dive_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown above the header of a draft dive (issue #637): marked at the site,
/// waiting for its dive computer readings. It says how long the taps put the
/// dive at, and offers the download that fills it, "Mark as complete" for a
/// dive that will never be downloaded, and "Surfaced" while it is open.
/// Built like [PlannedDiveBanner], in the draft chip's colours.
class DraftDiveBanner extends StatelessWidget {
  const DraftDiveBanner({
    super.key,
    required this.dive,
    required this.onMarkComplete,
    required this.onDownload,
    this.onSurfaced,
  });

  final Dive dive;
  final VoidCallback onMarkComplete;
  final VoidCallback onDownload;

  /// Shown only while the draft is open (no exit time yet).
  final VoidCallback? onSurfaced;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final open = dive.exitTime == null;
    final minutes = dive.effectiveRuntime?.inMinutes;
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        // The actions sit under the text: beside it, three of them leave the
        // text no room at phone width.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  unfilledDiveIcon(UnfilledDiveState.awaitingDownload),
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        open
                            ? l10n.diveLog_draft_inWaterChip
                            : l10n.diveLog_draft_chip,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        open || minutes == null
                            ? l10n.diveLog_draft_bannerBodyOpen
                            : l10n.diveLog_draft_bannerBody(minutes),
                        style: TextStyle(color: scheme.onSecondaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                if (open && onSurfaced != null)
                  FilledButton.tonal(
                    onPressed: onSurfaced,
                    child: Text(l10n.diveLog_draft_surfaced),
                  ),
                TextButton(
                  onPressed: onDownload,
                  child: Text(l10n.diveLog_draft_downloadNow),
                ),
                TextButton(
                  onPressed: onMarkComplete,
                  child: Text(l10n.diveLog_draft_markComplete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
