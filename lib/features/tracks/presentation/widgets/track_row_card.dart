import 'package:flutter/material.dart';

/// Wraps one track row (either kind) in the same card shape the dive list
/// uses for its own rows (`dive_list_page.dart`): rounded corners, the same
/// margin, and a background fill while [highlighted] (issue #4024).
///
/// The tap handler lives on this card's [InkWell], not on [child]'s own
/// `ListTile.onTap`: a [ListTile] only adds its own ink response when given
/// a tap callback, so leaving that null lets this card's splash show
/// instead, in its own rounded shape.
class TrackRowCard extends StatelessWidget {
  const TrackRowCard({
    super.key,
    required this.onTap,
    required this.highlighted,
    required this.child,
  });

  final VoidCallback onTap;

  /// Selected in the split layout's map pane, or the row last opened in
  /// either layout -- either way, the row the diver is currently looking at
  /// or just came back from.
  final bool highlighted;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        color: highlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: InkWell(
          onTap: onTap,
          customBorder:
              theme.cardTheme.shape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          // The inner ListTile carries no onTap of its own (see above), so
          // without this the row's tap target would announce none of its
          // text as actionable.
          child: Semantics(button: true, child: child),
        ),
      ),
    );
  }
}
