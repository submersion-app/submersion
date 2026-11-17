import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// The pencil that opens a card, drawn the same wherever a card's title row
/// is: in a [RecordCardHeader], or at the end of a title row the card draws
/// itself.
class RecordPencilIcon extends StatelessWidget {
  const RecordPencilIcon({super.key, required this.cardTitle});

  /// The card's title, named in the tooltip.
  final String cardTitle;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.recordEdit_editCardTooltip(cardTitle),
      child: Icon(
        Icons.edit_outlined,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// The changed dot and the pencil of a closed card whose title row is drawn
/// by the card itself, such as the dive page's header block (issue #4527).
///
/// Locked, or with no `RecordCardFrame` above it, it draws nothing and takes
/// no room, so unlocking does not change the row it sits in. Open, it draws
/// nothing: the open card has a header of its own. The dot's place is kept
/// while there is none, so its arrival cannot move the pencil.
class RecordCardPencil extends StatelessWidget {
  const RecordCardPencil({super.key, required this.cardTitle});

  /// The card's title, named to a screen reader and in the tooltip.
  final String cardTitle;

  @override
  Widget build(BuildContext context) {
    final frame = RecordCardFrameScope.maybeOf(context);
    if (frame == null || frame.isOpen) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 8,
          child: frame.isChanged ? const RecordChangedDot() : null,
        ),
        const SizedBox(width: 4),
        // The only way into the card: the body's own taps (the site, the
        // map) keep doing what they do while reading. A node of its own, or
        // a Card around the title row would merge it into one button named
        // for everything the card says.
        Semantics(
          container: true,
          button: true,
          label: context.l10n.recordEdit_editCardTooltip(cardTitle),
          onTap: frame.onOpen,
          excludeSemantics: true,
          child: InkWell(
            onTap: frame.onOpen,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: RecordPencilIcon(cardTitle: cardTitle),
            ),
          ),
        ),
      ],
    );
  }
}
