import 'package:flutter/material.dart';

/// The outline for today's day card: the theme's own card corners (they run
/// from 4 to 20 across the app's themes) with a primary edge, so today stands
/// out without its corners differing from the cards around it.
RoundedRectangleBorder todayCardShape(ThemeData theme) {
  final themed = theme.cardTheme.shape;
  return RoundedRectangleBorder(
    borderRadius: themed is RoundedRectangleBorder
        ? themed.borderRadius
        : BorderRadius.circular(12),
    side: BorderSide(color: theme.colorScheme.primary, width: 2),
  );
}
