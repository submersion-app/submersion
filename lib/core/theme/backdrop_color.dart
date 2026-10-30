import 'package:flutter/material.dart';

/// The colour painted behind [context]: the fill of the nearest enclosing
/// [Card], or the page surface when there is no card.
///
/// A mark that punches itself out of what lies beneath it (the ring around a
/// chart dot) has to match this colour rather than assume the page: the
/// theme presets give cards their own colour (Console dark's #1A2230 card on
/// a #141A22 page), and a mismatch draws a visible halo.
///
/// The card's fill resolves as [Card] resolves it: its own colour, then the
/// theme's card colour, then Material 3's default of surfaceContainerLow. A
/// translucent fill (Deep dark's cards) is composited over the page. The
/// presets leave the card surface tint transparent, so no tint is applied.
Color backdropColorOf(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final card = context.findAncestorWidgetOfExactType<Card>();
  if (card == null) return scheme.surface;
  final fill =
      card.color ?? theme.cardTheme.color ?? scheme.surfaceContainerLow;
  return Color.alphaBlend(fill, scheme.surface);
}
