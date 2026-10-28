import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/media_people_chips_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Tag mode's guidance and actions over the viewer (issue #1745): a hint at
/// the top, and a bar at the bottom listing everyone tagged on the item.
/// Picking one there (or tapping their box) selects the tag, which is how a
/// tag without a spot, or a video moment off screen, is reached at all.
/// With nothing selected the bar offers "Tag without a spot" and Done; with
/// a tag selected it offers to change the person or remove the tag. A
/// [Stack] child: two [Positioned]s.
class PeopleTagHint extends StatelessWidget {
  /// Whether a tap can place a box; when not, the hint says so and only a
  /// tag without a spot is offered.
  final bool canPlaceSpot;
  final bool hasSelection;

  /// Whether the selected tag has a box to drag.
  final bool selectionHasBox;

  /// Everyone tagged on the item, and the selected tag's id.
  final List<MediaPersonChip> chips;
  final String? selectedTagId;
  final ValueChanged<MediaPersonTag> onSelectTag;
  final VoidCallback onWithoutSpot;
  final VoidCallback onDone;
  final VoidCallback onChangePerson;
  final VoidCallback onRemove;

  const PeopleTagHint({
    super.key,
    required this.canPlaceSpot,
    required this.hasSelection,
    this.selectionHasBox = false,
    this.chips = const [],
    this.selectedTagId,
    required this.onSelectTag,
    required this.onWithoutSpot,
    required this.onDone,
    required this.onChangePerson,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final padding = MediaQuery.paddingOf(context);
    final hint = hasSelection && selectionHasBox
        ? l10n.media_people_resizeHint
        : canPlaceSpot
        ? l10n.media_people_tagModeHint
        : l10n.media_people_noSpotHint;
    const onDark = TextStyle(color: Colors.white);
    final buttonStyle = TextButton.styleFrom(foregroundColor: Colors.white);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: padding.top + 64,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(hint, style: onDark),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (chips.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final chip in chips)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(personChipLabel(context, chip)),
                                  selected: chip.tag.id == selectedTagId,
                                  onSelected: (_) => onSelectTag(chip.tag),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (hasSelection) ...[
                          TextButton.icon(
                            style: buttonStyle,
                            onPressed: onChangePerson,
                            icon: const Icon(Icons.swap_horiz),
                            label: Text(l10n.media_people_changePerson),
                          ),
                          TextButton.icon(
                            style: buttonStyle,
                            onPressed: onRemove,
                            icon: const Icon(Icons.delete_outline),
                            label: Text(l10n.media_people_removeTag),
                          ),
                        ] else
                          TextButton.icon(
                            style: buttonStyle,
                            onPressed: onWithoutSpot,
                            icon: const Icon(Icons.person_add_alt),
                            label: Text(l10n.media_people_withoutSpot),
                          ),
                        FilledButton(
                          onPressed: onDone,
                          child: Text(l10n.media_people_done),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
