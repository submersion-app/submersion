import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown by the universal import wizard's file-selection step when
/// [FormatDetector] recognises a Seacraft ENC navigation console log
/// (spec 2026-09-10-underwater-nav-track-design.md, "Import and format
/// detection"): the wizard must not advance to Confirm Source for this
/// format -- it is a measured underwater route, not a dive log -- so this
/// card is the hand-off to `NavTrackImportReviewPage` instead.
class NavTrackHandoffCard extends StatelessWidget {
  const NavTrackHandoffCard({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('nav-track-handoff-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.navTrack_handoff_recognized,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.navTrack_handoff_description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('nav-track-handoff-continue'),
                onPressed: () => navigateToNavTrackReview(
                  context,
                  bytes,
                  fileName: fileName,
                ),
                child: Text(l10n.navTrack_handoff_reviewButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
