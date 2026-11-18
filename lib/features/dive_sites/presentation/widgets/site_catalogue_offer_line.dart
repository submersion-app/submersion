import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_gap_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_gap_display.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// On a site's page: that the built-in catalogue has something for this
/// site, with the way to see it beside the site's own values.
///
/// Nothing shows for a site with no pair. For a site already linked the
/// catalogue has more details; for one that is not, it may hold the site,
/// and the diver says whether it does.
class SiteCatalogueOfferLine extends ConsumerWidget {
  const SiteCatalogueOfferLine({
    super.key,
    required this.site,
    this.onReviewed,
    this.reviewable = true,
  });

  final DiveSite site;

  /// Takes what the diver chose in the comparison in place of writing it:
  /// a sitting on the site holds it until Save (issue #4527, phase 2).
  final void Function(CataloguePair pair, CatalogueComparisonResult result)?
  onReviewed;

  /// Offers Review. A page that edits in place shows the locked line
  /// without it: the header block's editor reviews.
  final bool reviewable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(catalogueGapPairForSiteProvider(site.id));
    if (pair == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            pair.addsLink
                ? l10n.diveSites_gapLine_unlinked
                : l10n.diveSites_gapLine_linked,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (reviewable)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _review(context, pair, onReviewed),
              child: Text(l10n.diveSites_gapNotice_review),
            ),
        ],
      ),
    );
  }
}

/// Opens the comparison for [pair] and does what the diver chose there.
///
/// Everything after the sheet goes through the provider container, not
/// this widget: the diver may leave the site's page while a write is under
/// way, and the write and what follows it must still finish.
Future<void> _review(
  BuildContext context,
  CataloguePair pair,
  void Function(CataloguePair, CatalogueComparisonResult)? onReviewed,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final result = await showCatalogueGapComparison(context, pair: pair);
  // Closed without acting: nothing to remember outside the review list.
  if (result is ComparisonKept) return;
  // Held by a sitting: written, or not, with it.
  if (onReviewed != null) {
    onReviewed(pair, result);
    return;
  }

  final service = container.read(catalogueGapServiceProvider);
  try {
    final diverId = await container.read(
      validatedCurrentDiverIdProvider.future,
    );
    switch (result) {
      case ComparisonApply(:final fields):
        final applied = await service.apply([
          CatalogueApplyRequest(pair, fields),
        ], diverId: diverId);
        messenger.showSnackBar(
          SnackBar(content: Text(catalogueApplyResultMessage(applied, l10n))),
        );
      case ComparisonNotSame():
        await service.answerNotSame(pair, diverId: diverId);
      case ComparisonNoThanks():
        await service.declineAll(pair, diverId: diverId);
      case ComparisonKept():
        // Answered above; the switch has to name every result.
        break;
    }
    catalogueGapWritten(container);
  } catch (_) {
    // The service has logged it.
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveSites_gapReview_error)),
    );
  }
}
