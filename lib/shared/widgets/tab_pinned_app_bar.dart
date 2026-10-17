import 'package:flutter/material.dart';

/// Holds a [TabBarView] page's app bar still while the page slides.
///
/// A page whose own [Scaffold] carries the app bar slides out with it, so a
/// switch moved the whole window, header and all (issue #3465). This shifts
/// the bar back by however far its page sits from the centre, which keeps it
/// where the header always sits while the body under it slides, the way
/// Equipment's single app bar stays put over its sliding lists.
///
/// Only the bar of the page nearest the centre shows, so two bars never
/// blend mid-switch; the other is hidden and takes no taps. When both draw
/// the same section switch from the same [TabController], the handover shows
/// only in what differs between them, such as their actions and counts.
class TabPinnedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabPinnedAppBar({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  /// The [TabController.animation] driving the [TabBarView].
  final Animation<double> animation;

  /// This bar's page in the [TabBarView].
  final int index;

  final PreferredSizeWidget child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: animation,
        builder: (context, bar) {
          // Pages to the side of the centre: positive while this page is
          // still coming in from the trailing edge.
          final pages = index - animation.value;
          final dx = pages * constraints.maxWidth;
          return Transform.translate(
            offset: Offset(rtl ? dx : -dx, 0),
            child: Visibility(
              visible: animation.value.round() == index,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: bar!,
            ),
          );
        },
        child: child,
      ),
    );
  }
}
