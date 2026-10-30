import 'package:flutter/widgets.dart';

/// The shared label column of one [DetailRowGroup]: the widest label cell
/// any of its rows reported.
///
/// Rows report from their render objects, which they update while the
/// widget tree builds, and read [width] when they lay out. Every row of a
/// group has built before any of them lays out, so a card's values are
/// aligned in its first frame. Listeners (the rows) relayout whenever the
/// width changes, such as when a row arrives, leaves or changes its label.
class DetailLabelColumn extends ChangeNotifier {
  final Map<Object, double> _widths = {};
  double _width = 0;

  /// The widest reported label cell, or 0 when no row has reported.
  double get width => _width;

  /// Records [owner]'s label cell width, replacing any earlier report.
  void report(Object owner, double width) {
    if (_widths[owner] == width) return;
    _widths[owner] = width;
    _recompute();
  }

  /// Forgets [owner], for a row that left the tree.
  void remove(Object owner) {
    if (_widths.remove(owner) == null) return;
    _recompute();
  }

  void _recompute() {
    var widest = 0.0;
    for (final w in _widths.values) {
      if (w > widest) widest = w;
    }
    if (widest == _width) return;
    _width = widest;
    notifyListeners();
  }
}

/// Lines up the values of every `DetailRow` below it on one label column,
/// as wide as the group's widest label (capped by each row).
///
/// Wrap a card's rows in one group. Rows need not be direct children: a
/// row built by another widget, or one that appears once its data loads,
/// joins the nearest group. Nested groups are independent; a row joins the
/// nearest one.
///
/// Rows must be built in an ordinary build pass, not by a builder that runs
/// during layout (a `LayoutBuilder`, or a lazy list such as
/// `ListView.builder`) below the group. A row built there reports its width
/// after its siblings have laid out for the frame, and they keep the old
/// column. Put the group inside such a builder instead.
class DetailRowGroup extends StatefulWidget {
  const DetailRowGroup({super.key, required this.child});

  final Widget child;

  /// The column of the nearest enclosing group, or null outside any group.
  static DetailLabelColumn? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_DetailRowGroupScope>()
      ?.column;

  @override
  State<DetailRowGroup> createState() => _DetailRowGroupState();
}

class _DetailRowGroupState extends State<DetailRowGroup> {
  final DetailLabelColumn _column = DetailLabelColumn();

  @override
  void dispose() {
    _column.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _DetailRowGroupScope(column: _column, child: widget.child);
}

class _DetailRowGroupScope extends InheritedWidget {
  const _DetailRowGroupScope({required this.column, required super.child});

  final DetailLabelColumn column;

  @override
  bool updateShouldNotify(_DetailRowGroupScope oldWidget) =>
      column != oldWidget.column;
}
