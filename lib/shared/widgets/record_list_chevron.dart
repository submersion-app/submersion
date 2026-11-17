import 'package:flutter/material.dart';

/// The padding inside a detailed record card, on every side. Every list
/// shares it so that the chevron sits at the same place in all of them.
const double kRecordCardDetailedPadding = 12;

/// The padding inside a compact record card, on every side.
const double kRecordCardCompactPadding = 10;

/// The start and end padding of a dense, borderless record row.
const double kRecordRowDenseHorizontalPadding = 16;

/// The ">" at the end of a record row in a list, shared so that it sits at
/// the same place in every list (issue #4639).
///
/// `Icons.chevron_right` draws its ink from 8.6 to 16 of its 24-unit box, so
/// a bare icon adds a third of its size as blank space after the tip. A row
/// that pads both sides by the same amount then showed the chevron that much
/// further from the right edge than its content sat from the left, and the
/// distance changed with every icon size and every tile's padding.
///
/// This box ends at the tip of the ink instead: the icon overflows into its
/// own blank margin, which paints nothing. A row that puts this widget last
/// therefore shows the chevron exactly its end padding away from the edge,
/// mirrored in right-to-left text with the glyph.
class RecordListChevron extends StatelessWidget {
  const RecordListChevron({super.key, this.size = detailedSize, this.color});

  /// The chevron on a detailed card.
  static const double detailedSize = 24;

  /// The chevron on a compact card.
  static const double compactSize = 20;

  /// The chevron on a dense, borderless row.
  static const double denseSize = 18;

  /// The space between the content and the chevron's layout box, on top of
  /// the blank space the glyph keeps before its own ink.
  static const double gap = 4;

  // The share of the icon box from its start to the tip of the ink.
  static const double _inkEndFraction = 16 / 24;

  /// The width a detailed chevron takes in a row, gap included.
  static const double detailedExtent = gap + detailedSize * _inkEndFraction;

  final double size;

  /// Null takes the ambient icon colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: gap),
        child: SizedBox(
          width: size * _inkEndFraction,
          height: size,
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            minWidth: size,
            maxWidth: size,
            child: Icon(Icons.chevron_right, size: size, color: color),
          ),
        ),
      ),
    );
  }
}

/// A record row's content with a [RecordListChevron] after it, centred on
/// the whole height of the content.
///
/// The content's own lines (stats, badges, tags) all end before the chevron,
/// so right-aligned badges line up with each other rather than with
/// whichever line happened to hold the chevron.
class RecordListChevronRow extends StatelessWidget {
  const RecordListChevronRow({
    super.key,
    required this.child,
    this.showChevron = true,
    this.chevronSize = RecordListChevron.detailedSize,
    this.chevronColor,
  });

  final Widget child;

  /// False drops the chevron (as in selection mode, where a tap checks the
  /// row rather than opening it) and gives the content the full width.
  final bool showChevron;

  final double chevronSize;
  final Color? chevronColor;

  @override
  Widget build(BuildContext context) {
    if (!showChevron) return child;
    return Row(
      children: [
        Expanded(child: child),
        RecordListChevron(size: chevronSize, color: chevronColor),
      ],
    );
  }
}

/// The content padding for a `ListTile` that fills a detailed record card
/// under a [RecordListChevronOverlay]: the card's padding at the start, and
/// at the end the same padding plus room for the chevron.
const EdgeInsetsDirectional kRecordListTileContentPadding =
    EdgeInsetsDirectional.only(
      start: kRecordCardDetailedPadding,
      end: kRecordCardDetailedPadding + RecordListChevron.detailedExtent,
    );

/// A detailed [RecordListChevron] laid over a record card built on a
/// `ListTile`, centred on the card's whole height and
/// [kRecordCardDetailedPadding] from its end.
///
/// A three-line `ListTile` pins its trailing widget to the top, so a chevron
/// placed there sat level with the title on some lists and in the middle on
/// others. Laid over the tile instead, it lands where the hand-built cards
/// put theirs, and the tile keeps its trailing slot for a status or badge.
/// The chevron ignores pointers, so a tap on it reaches the tile beneath.
/// The tile reserves the room with [kRecordListTileContentPadding].
class RecordListChevronOverlay extends StatelessWidget {
  const RecordListChevronOverlay({
    super.key,
    required this.child,
    this.showChevron = true,
    this.chevronColor,
  });

  final Widget child;

  /// False drops the chevron, as in selection mode.
  final bool showChevron;

  /// Null takes the colour a `ListTile` gives its own icons, as the chevron
  /// had when it sat in the tile's trailing slot.
  final Color? chevronColor;

  @override
  Widget build(BuildContext context) {
    if (!showChevron) return child;
    final color =
        chevronColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Stack(
      children: [
        child,
        PositionedDirectional(
          top: 0,
          bottom: 0,
          end: kRecordCardDetailedPadding,
          child: IgnorePointer(
            child: Center(child: RecordListChevron(color: color)),
          ),
        ),
      ],
    );
  }
}
