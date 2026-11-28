import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Brings a Show all / Show fewer button back into view after it collapsed
/// its list, once the shorter list has been laid out.
///
/// Show fewer at the foot of a long list takes away what was above the
/// reader, which leaves the page scrolled past the list onto whatever
/// follows it. When the button has gone above the viewport, the page moves
/// so the button sits at the viewport's foot, the shortened list above it.
/// A button still in view stays where it is.
void revealCollapsedToggle(GlobalKey toggleKey) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = toggleKey.currentContext;
    if (context == null || !context.mounted) return;
    final toggle = context.findRenderObject();
    final position = Scrollable.maybeOf(context)?.position;
    if (toggle == null || position == null) return;
    final viewport = RenderAbstractViewport.maybeOf(toggle);
    if (viewport == null) return;
    final atTop = viewport.getOffsetToReveal(toggle, 0).offset;
    if (position.pixels <= atTop) return;
    final atFoot = viewport.getOffsetToReveal(toggle, 1).offset;
    position.jumpTo(
      atFoot.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  });
}
