import 'package:flutter/material.dart';

/// A day card's outline: the theme's own card corners (they run from 4 to 20
/// across the app's themes) with [side], so an outlined day never has
/// different corners from the cards around it.
RoundedRectangleBorder dayCardShape(ThemeData theme, BorderSide side) {
  final themed = theme.cardTheme.shape;
  return RoundedRectangleBorder(
    borderRadius: themed is RoundedRectangleBorder
        ? themed.borderRadius
        : BorderRadius.circular(12),
    side: side,
  );
}

/// Today's card: the theme's corners with a primary edge, so today stands
/// out without its shape differing from its neighbours.
RoundedRectangleBorder todayCardShape(ThemeData theme) =>
    dayCardShape(theme, BorderSide(color: theme.colorScheme.primary, width: 2));
