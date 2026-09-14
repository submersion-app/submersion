import 'package:flutter/material.dart';

/// The one column-header/value type pair every table-like display in the
/// blender feature shares (fill procedure, flush fee, tariff, cost lines,
/// billed lines), so the diver reads consistent sizing wherever a table
/// shows up instead of a different scale per card (issue #1876 follow-up).
///
/// Modelled on `EntityTableHeaderCell`, the closest existing "table header"
/// convention in the app; there is no app-wide theme token for this, so the
/// pair is kept local to the feature that needs it consistent.
///
/// [color] overrides the default `onSurfaceVariant`/`onSurface`-implied
/// colors for a card whose background is not the plain surface color (the
/// fill-procedure card sits on `colorScheme.primaryContainer` and needs its
/// `onPrimaryContainer` counterpart instead).
TextStyle? blenderTableHeaderStyle(BuildContext context, {Color? color}) {
  final theme = Theme.of(context);
  return theme.textTheme.labelSmall?.copyWith(
    fontWeight: FontWeight.w600,
    color: color ?? theme.colorScheme.onSurfaceVariant,
  );
}

/// The value/data-row counterpart to [blenderTableHeaderStyle].
TextStyle? blenderTableValueStyle(BuildContext context, {Color? color}) {
  final style = Theme.of(context).textTheme.bodyMedium;
  return color == null ? style : style?.copyWith(color: color);
}
