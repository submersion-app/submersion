import 'package:flutter/widgets.dart';

/// The screen rectangle of the widget [context] resolves to, for anchoring the
/// iPad share popover.
///
/// On iPad the system share sheet is a popover and must point at the control
/// that opened it. `share_plus` takes this as `ShareParams.sharePositionOrigin`
/// in global (window) coordinates; when it is absent or empty the plugin falls
/// back to the centre of the screen, which reads as an arrow pointing at
/// nothing. iPhone ignores the value entirely, so passing it is always safe.
///
/// Pass the **button's** context, not the enclosing page's. `findRenderObject`
/// returns the render object of the element the context belongs to, so a page's
/// context yields a page-sized rect and anchors the popover to the whole
/// screen. The usual way to get a button's context without a [GlobalKey] is to
/// wrap it in a [Builder]: a [Builder] contributes no render object of its own,
/// so the lookup descends to the button below it.
///
/// Returns null when no usable rect exists -- an unmounted context, or a render
/// object that is not a laid-out [RenderBox]. Callers should treat null as "let
/// the platform decide" and pass it through unchanged, since resolving the
/// anchor after an `await` can legitimately race the widget being disposed.
Rect? shareAnchorFrom(BuildContext? context) {
  if (context == null || !context.mounted) return null;

  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox) return null;
  if (!renderObject.attached || !renderObject.hasSize) return null;

  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}
