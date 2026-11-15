import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where the review of built-in details for existing sites lives.
const String kCatalogueReviewRoute = '/sites/catalogue-review';

/// The value of the Sites overflow menu's entry for that review.
const String kCatalogueReviewMenuValue = 'catalogue_review';

/// The Sites overflow menu's entry that opens the review, the same in each
/// of the three places that menu is built.
PopupMenuItem<String> catalogueReviewMenuItem(BuildContext context) =>
    PopupMenuItem(
      value: kCatalogueReviewMenuValue,
      child: ListTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: Text(context.l10n.diveSites_list_menu_catalogueReview),
        contentPadding: EdgeInsets.zero,
      ),
    );

/// One line above the site list while the built-in catalogue has details
/// waiting for the diver's sites, with the way to the review.
///
/// It takes no room when there is nothing new to say: no pairs, or none
/// since the diver last dismissed it. Dismissing remembers the pairs
/// waiting at that moment, so it returns only for a pair that is new or
/// has more to offer.
class CatalogueGapNotice extends ConsumerWidget {
  const CatalogueGapNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(catalogueGapNoticeCountProvider);
    if (count == 0) return const SizedBox.shrink();

    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 20,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          // The text and its action wrap together, so a long translation
          // drops the action to its own line and never pushes it off.
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(l10n.diveSites_gapNotice_text(count)),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => context.push(kCatalogueReviewRoute),
                  child: Text(l10n.diveSites_gapNotice_review),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: l10n.common_action_dismiss,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final pairs =
                  ref.read(catalogueGapPairsProvider).value ?? const [];
              ref.read(catalogueGapNoticeSeenProvider.notifier).dismiss([
                for (final pair in pairs) pair.key,
              ]);
            },
          ),
        ],
      ),
    );
  }
}
