import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_hero_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draft_dive_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

/// The fixed block above the dive page's sections: the planned and draft
/// banners, the site suggestion, and the hero card.
///
/// On a page that offers editing (a [RecordEditScope] above) the hero is
/// framed as the header card (issue #4527): unlocked it gains a pencil and
/// opens in place. The site suggestion follows the page's lock.
class DiveDetailHeaderBlock extends StatelessWidget {
  const DiveDetailHeaderBlock({
    super.key,
    required this.stored,
    required this.shown,
    required this.embedded,
    required this.onMarkLogged,
    required this.onDownloadDraft,
    required this.onSurfaceDraft,
    this.creating = false,
  });

  /// A new dive not yet created (issue #4527, plan 8): no banner and no
  /// site suggestion, which act on a stored dive.
  final bool creating;

  /// The dive as stored. The banners read it: what they offer acts on the
  /// dive as a whole, not on a sitting.
  final Dive stored;

  /// The dive the page shows: the sitting's during one.
  final Dive shown;

  /// In the master-detail pane, whose own header carries the banners and
  /// the suggestion.
  final bool embedded;
  final VoidCallback onMarkLogged;
  final VoidCallback onDownloadDraft;
  final VoidCallback onSurfaceDraft;

  @override
  Widget build(BuildContext context) {
    final controller = RecordEditScope.of<Dive>(context);
    final editing = siteSuggestionEditingOf(context);
    final hero = DiveDetailHeroSection(dive: shown, embedded: embedded);
    // What the banners offer acts on the whole dive at once: only on an
    // unlocked page with nothing to save (issue #4527).
    final operationReason = recordOperationReason(
      context.l10n,
      recordOperationBlockOf(controller),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The site suggestion sits above the header card, never inside
        // it. Embedded mode has its own copy under the toolbar (which
        // stays put while the body scrolls), so only the standalone page
        // renders one here; otherwise the banner would appear twice.
        // Collapses to nothing when there is no suggestion, so no
        // spacing of its own is needed.
        if (!embedded && !creating) ...[
          if (stored.isPlanned)
            PlannedDiveBanner(
              diveId: stored.id,
              onMarkLogged: onMarkLogged,
              operationReason: operationReason,
            ),
          if (stored.isDraft)
            DraftDiveBanner(
              dive: stored,
              onMarkComplete: onMarkLogged,
              onDownload: onDownloadDraft,
              onSurfaced: onSurfaceDraft,
              operationReason: operationReason,
            ),
          SiteSuggestionCard(
            diveId: stored.id,
            currentSite: stored.site,
            editing: editing,
          ),
        ],
        RecordCardFrame<Dive>(card: diveHeaderCard, child: hero),
      ],
    );
  }
}
