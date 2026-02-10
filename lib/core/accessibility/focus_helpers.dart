import 'package:flutter/material.dart';

/// Wraps a page's content with a [FocusTraversalGroup] using
/// [OrderedTraversalPolicy] for consistent keyboard tab order.
///
/// Every page should use this at its root to isolate focus
/// cycling within the page's content area.
class AccessiblePage extends StatelessWidget {
  const AccessiblePage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(policy: OrderedTraversalPolicy(), child: child);
  }
}

/// A card that can receive keyboard focus and shows a visible focus indicator.
///
/// Use this for any custom tappable card that uses [GestureDetector] or
/// [InkWell] instead of a standard Material button, to ensure keyboard
/// users can navigate to and activate it.
class FocusableCard extends StatefulWidget {
  const FocusableCard({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.onTap,
    this.borderRadius = 12.0,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: Focus(
        onFocusChange: (focused) {
          setState(() => _isFocused = focused);
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: _isFocused
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
