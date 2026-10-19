import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Places the Adjust color panel beside a viewer (issue #3520): under the
/// photo on phones, docked to the right from the desktop breakpoint. The
/// viewer keeps working, so the diver can swipe to the next photo with the
/// panel open.
class ColorAdjustLayout extends StatelessWidget {
  const ColorAdjustLayout({
    super.key,
    required this.open,
    required this.panelBuilder,
    required this.child,
  });

  final bool open;

  /// Builds the panel for its layout: [Axis.vertical] when docked right.
  final Widget Function(Axis layout) panelBuilder;

  final Widget child;

  static const _dockedWidth = 320.0;

  @override
  Widget build(BuildContext context) {
    if (!open) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.desktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: child),
              SizedBox(
                width: _dockedWidth,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  // Docked at the end edge, the side away from the viewer
                  // (the left in a right-to-left locale) keeps its inset.
                  child: SafeArea(
                    left: Directionality.of(context) == TextDirection.rtl,
                    right: Directionality.of(context) == TextDirection.ltr,
                    child: SingleChildScrollView(
                      child: panelBuilder(Axis.vertical),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: child),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.45,
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: panelBuilder(Axis.horizontal),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
