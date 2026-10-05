import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports [child]'s laid-out size whenever it changes, once the frame is
/// done, so a widget in a different part of the tree can lay itself out
/// around it.
///
/// Built for the terrain pane: its docked control card sits in the pane's
/// outer Stack while the source caption sits in the scene's inner Stack, and
/// the caption has to stop short of a card whose width depends on how many
/// actions the host seats in it.
class SizeReporter extends SingleChildRenderObjectWidget {
  const SizeReporter({super.key, required this.onChange, super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderSizeReporter createRenderObject(BuildContext context) =>
      RenderSizeReporter(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSizeReporter renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

/// The render object behind [SizeReporter].
class RenderSizeReporter extends RenderProxyBox {
  RenderSizeReporter(this.onChange);

  ValueChanged<Size> onChange;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final laidOut = size;
    if (laidOut == _reported) return;
    _reported = laidOut;
    // After the frame: the listener may rebuild, which layout must not do.
    // Skipped if this left the tree in the meantime: a subtree can be
    // removed after its layout (a LayoutBuilder rebuilding during layout),
    // and its owner's State is disposed before post-frame callbacks run.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onChange(laidOut);
    });
  }

  @override
  void detach() {
    // A report may have been skipped above, so one that comes back to the
    // tree reports its size again rather than assuming it was delivered.
    _reported = null;
    super.detach();
  }
}
