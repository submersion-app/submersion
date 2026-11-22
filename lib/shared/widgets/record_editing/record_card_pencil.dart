import 'package:flutter/material.dart';

import 'package:submersion/core/theme/record_pencil_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// The pencil that opens a card: a filled disc in the theme's
/// [RecordPencilColors], the same on every card of every record page.
///
/// A plain pencil in the theme's own accent blended into the cards around
/// it, so the disc is a hue no preset's colour scheme uses (issue #4527).
/// It is no taller than a card title's line, at any system text size up to
/// 100%, so unlocking does not change a title row's height; larger text
/// leaves it at full size.
///
/// With [onTap] the disc is its own button. Its ink paints on the disc, so
/// a press, a hover or keyboard focus shows on the disc itself rather than
/// under it.
class RecordPencilDisc extends StatelessWidget {
  const RecordPencilDisc({super.key, this.onTap});

  /// The disc's diameter at full size.
  static const double size = 24;

  /// Opens the card; null when something around the disc does that.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = RecordPencilColors.of(context);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1);
    final glyph = Icon(
      Icons.edit,
      size: scaler.scale(16),
      color: colors.onFill,
    );
    return SizedBox.square(
      // Whole points, rounded down: a title's line can come out a fraction
      // under its scaled height, and the disc must not be the taller.
      dimension: scaler.scale(size).floorToDouble(),
      child: Material(
        color: colors.fill,
        shape: CircleBorder(side: BorderSide(color: colors.outline)),
        child: onTap == null
            ? glyph
            : InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: glyph,
              ),
      ),
    );
  }
}

/// The pencil that opens a card, drawn the same wherever a card's title row
/// is: in a [RecordCardHeader], or at the end of a title row the card draws
/// itself.
class RecordPencilIcon extends StatelessWidget {
  const RecordPencilIcon({super.key, required this.cardTitle, this.onTap});

  /// The card's title, named in the tooltip.
  final String cardTitle;

  /// Opens the card, when the pencil is a button of its own.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.recordEdit_editCardTooltip(cardTitle),
      child: RecordPencilDisc(onTap: onTap),
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
          // Exactly the disc, no padding round it: a title row's line is the
          // disc's height, so the pencil arriving does not make it taller.
          child: RecordPencilIcon(cardTitle: cardTitle, onTap: frame.onOpen),
        ),
      ],
    );
  }
}
