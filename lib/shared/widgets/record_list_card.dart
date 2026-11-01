import 'package:flutter/material.dart';

/// The fill a list card takes while its record is open in the detail pane,
/// was opened last, or is checked in a bulk selection.
Color recordCardSelectionFill(ColorScheme scheme) =>
    scheme.primaryContainer.withValues(alpha: 0.5);

/// Text and accent colours for the content of a [RecordListCard], picked by
/// how dark the card's fill is.
class RecordCardColors {
  const RecordCardColors._({
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
  });

  /// Colours for content on [fill]. A null fill is the theme's own card
  /// colour, read as `surfaceContainerHighest`.
  factory RecordCardColors.forFill(ColorScheme scheme, Color? fill) {
    final background = fill ?? scheme.surfaceContainerHighest;
    final light = background.computeLuminance() < 0.5;
    return RecordCardColors._(
      primaryText: light ? Colors.white : Colors.black87,
      secondaryText: light ? Colors.white70 : Colors.black54,
      accent: light ? Colors.cyan.shade200 : Colors.teal.shade800,
    );
  }

  final Color primaryText;
  final Color secondaryText;
  final Color accent;
}

/// The card one record takes in a list, shared so that every list built on
/// it looks and reacts the same in every theme preset: rounded corners and
/// card colour from the theme, the ink splash and hover on that shape, and
/// [recordCardSelectionFill] as [color] while the record is highlighted.
///
/// Everything that differs between looks of a card (a map background, a
/// highlight marker) belongs in [child], below the InkWell: the splash lives
/// in the InkWell's state, so a highlight that changed anything above it
/// would cut a running splash short (issue #3474).
class RecordListCard extends StatelessWidget {
  const RecordListCard({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.onDoubleTap,
    this.semanticsLabel,
    this.clipBehavior,
    this.margin,
  });

  final Widget child;

  /// Null keeps the theme's card colour.
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final String? semanticsLabel;
  final Clip? clipBehavior;

  /// Defaults to 16 horizontal and 4 vertical.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        color: color,
        clipBehavior: clipBehavior,
        child: Semantics(
          button: true,
          label: semanticsLabel,
          child: InkWell(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            // The card's own shape: a splash keeps the shape it started with,
            // and a card that switches to a layout without clipping before
            // the splash has finished would otherwise spill past its corners.
            // Card corners vary by theme, so the shape is the theme's,
            // falling back to Material's default card corners.
            customBorder:
                Theme.of(context).cardTheme.shape ??
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: child,
          ),
        ),
      ),
    );
  }
}
