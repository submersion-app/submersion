import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_section_pairs.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_fold.dart';

/// Gap between two consecutive cards in the detailed layout. Tighter than
/// Dive Details because a site stacks well over a dozen short cards.
const double kSiteDetailCardGap = 12;

/// The Site Details body: the diver's cards, in the diver's order, laid out
/// the diver's way.
///
/// [cards] holds a builder for every card the site can show right now. A
/// card that is missing or null has nothing to show for this site and is
/// skipped as if hidden, and never forms half of a pair (a pair with an
/// empty half would lay out a blank column beside a half-width card).
///
/// A builder runs only when its card is laid out. In the list layout a
/// folded card's builder never runs, so neither the card nor any lookup
/// behind it (dive statistics, map tiles, tide model, water conditions)
/// costs anything until the diver unfolds it.
///
/// In the detailed layout, a pair from [kSiteDetailSectionPairs] renders
/// side by side whenever both halves are shown, wherever they sit in the
/// order: the row takes the slot of whichever half comes first. Left and
/// right come from the pair definition.
class SiteDetailSectionList extends StatelessWidget {
  const SiteDetailSectionList({
    super.key,
    required this.sections,
    required this.layout,
    required this.cards,
    required this.onFoldChanged,
  });

  /// The diver's card configuration, in order.
  final List<SiteDetailSectionConfig> sections;

  final DiveDetailLayout layout;

  /// Card builders, keyed by id; missing or null means nothing to show.
  final Map<SiteDetailSectionId, WidgetBuilder?> cards;

  /// Called when a folded header is tapped in the list layout, with the
  /// requested new state.
  final void Function(SiteDetailSectionId id, bool expanded) onFoldChanged;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final section in sections)
        if (section.visible && cards[section.id] != null) section.id,
    ];
    final shownIds = shown.toSet();
    final unfolded = {
      for (final section in sections)
        if (section.expanded) section.id,
    };

    final children = <Widget>[];
    final consumed = <SiteDetailSectionId>{};

    for (final id in shown) {
      // The trailing half of a pair already rendered at the leading half's
      // slot.
      if (consumed.contains(id)) continue;

      if (layout.foldsSections) {
        // Each folded row draws its own divider, so rows take no gap.
        children.add(
          SectionFold(
            key: ValueKey('siteSectionFold_${id.name}'),
            title: id.localizedDisplayName(context.l10n),
            icon: id.icon,
            isExpanded: unfolded.contains(id),
            onToggle: (expanded) => onFoldChanged(id, expanded),
            contentBuilder: cards[id]!,
          ),
        );
        continue;
      }

      if (children.isNotEmpty) {
        children.add(const SizedBox(height: kSiteDetailCardGap));
      }

      final pair = layout.pairsSections ? siteDetailSectionPairFor(id) : null;
      if (pair != null && shownIds.contains(pair.partnerOf(id))) {
        children.add(
          ResponsiveSectionPair(
            first: cards[pair.left]!(context),
            second: cards[pair.right]!(context),
            minRowWidth: pair.minRowWidth,
            stackGap: kSiteDetailCardGap,
          ),
        );
        consumed.addAll([pair.left, pair.right]);
        continue;
      }

      children.add(cards[id]!(context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
