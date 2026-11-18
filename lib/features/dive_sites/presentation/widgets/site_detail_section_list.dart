import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_section_pairs.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_fold_pencil.dart';
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
/// right come from the pair definition. The card right after the pair moves
/// up into the space under the shorter half when it fits there at half width,
/// unless it is one of [kSiteDetailFullWidthSections] or forms a pair of its
/// own (issue #4583).
class SiteDetailSectionList extends StatelessWidget {
  const SiteDetailSectionList({
    super.key,
    required this.sections,
    required this.layout,
    required this.cards,
    required this.onFoldChanged,
    this.alsoShown = const {},
  });

  /// The diver's card configuration, in order.
  final List<SiteDetailSectionConfig> sections;

  final DiveDetailLayout layout;

  /// Card builders, keyed by id; missing or null means nothing to show.
  final Map<SiteDetailSectionId, WidgetBuilder?> cards;

  /// Called when a folded header is tapped in the list layout, with the
  /// requested new state.
  final void Function(SiteDetailSectionId id, bool expanded) onFoldChanged;

  /// Sections the diver hid that are shown all the same: brought onto the
  /// page by an editing sitting (issue #4527).
  final Set<SiteDetailSectionId> alsoShown;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final section in sections)
        if ((section.visible || alsoShown.contains(section.id)) &&
            cards[section.id] != null)
          section.id,
    ];
    // While the site is unlocked, a section with a card the diver can edit
    // gets the pencil on its folded row, and is unfolded while its card is
    // open: that is not the diver's saved choice, so it is not written back.
    final edit = RecordEditScope.maybeOf<DiveSite>(context);
    final session = edit?.session;
    final open = edit?.openCardIds ?? const <String>{};
    final shownIds = shown.toSet();
    final unfolded = {
      for (final section in sections)
        if (section.expanded) section.id,
    };

    final children = <Widget>[];
    final consumed = <SiteDetailSectionId>{};

    bool pairs(SiteDetailSectionId id) {
      final pair = layout.pairsSections ? siteDetailSectionPairFor(id) : null;
      return pair != null && shownIds.contains(pair.partnerOf(id));
    }

    for (final (index, id) in shown.indexed) {
      // The trailing half of a pair, or the card that moved up beside it,
      // already rendered at the pair's slot.
      if (consumed.contains(id)) continue;

      if (layout.foldsSections) {
        // Each folded row draws its own divider, so rows take no gap.
        final title = id.localizedDisplayName(context.l10n);
        final isOpen = open.contains(id.name);
        final canOpen =
            edit != null &&
            session != null &&
            siteEditCards.containsKey(id) &&
            !isOpen;
        children.add(
          SectionFold(
            key: ValueKey('siteSectionFold_${id.name}'),
            title: title,
            icon: id.icon,
            isExpanded: unfolded.contains(id) || isOpen,
            trailing: canOpen
                ? RecordFoldPencil(
                    title: title,
                    // Open, the card's own header carries the dot.
                    isChanged: session.changedCardIds.contains(id.name),
                    onOpen: () => edit.openCard(id.name),
                  )
                : null,
            // A card being edited stays unfolded whatever is saved, so a
            // tap here could only change the saved choice unseen.
            onToggle: (expanded) {
              if (isOpen) return;
              onFoldChanged(id, expanded);
            },
            contentBuilder: cards[id]!,
          ),
        );
        continue;
      }

      if (children.isNotEmpty) {
        children.add(const SizedBox(height: kSiteDetailCardGap));
      }

      if (pairs(id)) {
        final pair = siteDetailSectionPairFor(id)!;
        consumed.addAll([pair.left, pair.right]);
        final next = shown.skip(index + 1).where((n) => !consumed.contains(n));
        final candidate = next.isEmpty ? null : next.first;
        final slots =
            candidate != null &&
            !kSiteDetailFullWidthSections.contains(candidate) &&
            !pairs(candidate);
        if (slots) consumed.add(candidate);
        children.add(
          ResponsiveSectionPair(
            first: cards[pair.left]!(context),
            second: cards[pair.right]!(context),
            minRowWidth: pair.minRowWidth,
            stackGap: kSiteDetailCardGap,
            slot: slots ? cards[candidate]!(context) : null,
          ),
        );
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
