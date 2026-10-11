import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Gives a modal sheet its own snackbar host (#2365). A snackbar raised from
/// inside a modal bottom sheet otherwise goes to the page's
/// ScaffoldMessenger, which renders it underneath the sheet where the diver
/// never sees it. Transparent and non-resizing, so the sheet's own layout
/// and keyboard handling are unchanged.
///
/// The host is a [Scaffold], which takes all the height it is offered. That
/// suits a sheet that fills its space anyway, but turns a content-sized sheet
/// opened with `isScrollControlled` into a full-screen one. [shrinkWrap]
/// keeps such a sheet at its content's height: the snackbar then shows over
/// the sheet's bottom edge, as it would over the bottom of a page.
class SheetMessengerScope extends StatefulWidget {
  const SheetMessengerScope({
    super.key,
    required this.child,
    this.shrinkWrap = false,
  });

  final Widget child;

  /// Size the scope to [child] instead of to the space the sheet allows.
  final bool shrinkWrap;

  @override
  State<SheetMessengerScope> createState() => _SheetMessengerScopeState();
}

class _SheetMessengerScopeState extends State<SheetMessengerScope> {
  /// Carries the body's natural height from inside the Scaffold's layout out
  /// to the box that sizes the Scaffold. Held by the state so the two render
  /// objects keep sharing one instance across rebuilds.
  ///
  /// The body publishes its own height here because Flutter lets only a
  /// box's parent read its size: the sizing box, several levels up, would
  /// trip the size-access assertion if it read the body's size directly.
  final _bodyHeight = _BodyHeight();

  @override
  Widget build(BuildContext context) {
    if (!widget.shrinkWrap) {
      return ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: widget.child,
        ),
      );
    }
    return ScaffoldMessenger(
      child: _SizeToBody(
        bodyHeight: _bodyHeight,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: _MeasureBody(bodyHeight: _bodyHeight, child: widget.child),
        ),
      ),
    );
  }
}

class _BodyHeight {
  double? value;
}

/// Records the height the body lays out at. A Scaffold gives its body loose
/// height constraints, so this is the content's own height, not the
/// Scaffold's.
class _MeasureBody extends SingleChildRenderObjectWidget {
  const _MeasureBody({required this.bodyHeight, super.child});

  final _BodyHeight bodyHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureBody(bodyHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureBody renderObject,
  ) => renderObject.bodyHeight = bodyHeight;
}

class _RenderMeasureBody extends RenderProxyBox {
  _RenderMeasureBody(this.bodyHeight);

  _BodyHeight bodyHeight;

  @override
  void performLayout() {
    super.performLayout();
    bodyHeight.value = size.height;
  }
}

/// Lays the Scaffold out once to learn its body's height, then again capped
/// at that height.
///
/// The cap goes on maxHeight alone. Tight constraints would make the Scaffold
/// a relayout boundary, and a body that later grew or shrank would then
/// relayout inside the old height instead of resizing the sheet.
class _SizeToBody extends SingleChildRenderObjectWidget {
  const _SizeToBody({required this.bodyHeight, super.child});

  final _BodyHeight bodyHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeToBody(bodyHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeToBody renderObject,
  ) => renderObject.bodyHeight = bodyHeight;
}

class _RenderSizeToBody extends RenderProxyBox {
  _RenderSizeToBody(this.bodyHeight);

  _BodyHeight bodyHeight;

  @override
  void performLayout() {
    final scaffold = child!;
    scaffold.layout(constraints, parentUsesSize: true);
    final natural = bodyHeight.value;
    if (natural != null && natural < scaffold.size.height) {
      final capped = constraints.constrainHeight(natural);
      scaffold.layout(
        constraints.copyWith(maxHeight: capped),
        parentUsesSize: true,
      );
    }
    size = scaffold.size;
  }
}
