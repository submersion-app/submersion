import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Two cards side by side in equal-width columns that end level, with room
/// for a third card, [slot], in the space the shorter one leaves.
///
/// Each card is first laid out at its column width and its natural height.
/// When they differ, the shorter column has space under its card. If [slot]
/// fits in that space at column width, it goes there, under the shorter card
/// and [rowGap] below it. Otherwise it goes full width below the row,
/// [rowGap] down. Either way, the last card in each column is then laid out
/// again with a minimum height that brings its column level with the other,
/// so a [Card] at its root grows to fill the row, its content staying at the
/// top, and no blank space is left under it (issue #4583).
///
/// The slot is always the same child, wherever it is placed, so moving it
/// between the column and the row below keeps its state.
///
/// While [holdPlacement] is true the slot keeps the place it last had: a card
/// being edited must not jump out from under the diver when its editor makes
/// it taller. Its partner grows to match instead. The place held belongs to
/// the slot's [Widget.key]: a slot with another key is a different card and
/// is placed afresh, while the same card opening its editor, which swaps the
/// widgets inside it, keeps its place.
///
/// An [IntrinsicHeight] around a stretched [Row] would end the cards level
/// too, but it asks every descendant for its intrinsic height first, which a
/// [LayoutBuilder] (a map, a chart) cannot answer. This never asks: the
/// price is a second layout of the cards that grow.
///
/// The first pass offers the height this row is offered, which inside a
/// scroll view is unbounded, so a card must cope with that the way it would
/// in a [Column]: no [Expanded] at its root.
class PairedCardsRow extends MultiChildRenderObjectWidget {
  PairedCardsRow({
    super.key,
    required Widget first,
    required Widget second,
    Widget? slot,
    this.columnGap = 16,
    this.rowGap = 24,
    this.holdPlacement = false,
  }) : slotKey = slot?.key,
       super(children: [first, second, ?slot]);

  /// The horizontal space between the two columns.
  final double columnGap;

  /// The vertical space between a card and the slot below it.
  final double rowGap;

  /// Whether the slot keeps the place it last had.
  final bool holdPlacement;

  /// The slot's key, which says which card the place held belongs to.
  final Key? slotKey;

  @override
  RenderPairedCardsRow createRenderObject(BuildContext context) =>
      RenderPairedCardsRow(
        columnGap: columnGap,
        rowGap: rowGap,
        holdPlacement: holdPlacement,
        slotKey: slotKey,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPairedCardsRow renderObject,
  ) {
    renderObject
      ..columnGap = columnGap
      ..rowGap = rowGap
      ..holdPlacement = holdPlacement
      ..slotKey = slotKey
      ..textDirection = Directionality.of(context);
  }
}

/// Parent data for the children of a [RenderPairedCardsRow].
class PairedCardsRowParentData extends ContainerBoxParentData<RenderBox> {}

/// Where the slot goes: under the card in [column], or below the row when
/// [column] is null, and how tall that makes the whole.
typedef _Arrangement = ({int? column, double height});

/// The render object behind [PairedCardsRow].
class RenderPairedCardsRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, PairedCardsRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, PairedCardsRowParentData> {
  RenderPairedCardsRow({
    required double columnGap,
    required double rowGap,
    required bool holdPlacement,
    required TextDirection textDirection,
    this.slotKey,
  }) : _columnGap = columnGap,
       _rowGap = rowGap,
       _holdPlacement = holdPlacement,
       _textDirection = textDirection;

  /// Which card is in the slot; see [PairedCardsRow.slotKey]. A new card
  /// arrives as a new child, which lays the row out again, so this needs no
  /// layout of its own.
  Key? slotKey;

  double get columnGap => _columnGap;
  double _columnGap;
  set columnGap(double value) {
    if (value == _columnGap) return;
    _columnGap = value;
    markNeedsLayout();
  }

  double get rowGap => _rowGap;
  double _rowGap;
  set rowGap(double value) {
    if (value == _rowGap) return;
    _rowGap = value;
    markNeedsLayout();
  }

  bool get holdPlacement => _holdPlacement;
  bool _holdPlacement;
  set holdPlacement(bool value) {
    if (value == _holdPlacement) return;
    _holdPlacement = value;
    markNeedsLayout();
  }

  /// Which side the first card sits on: the left for left to right.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// The slot's column at the last layout, or null for below the row; kept
  /// for [holdPlacement]. [_placed] says whether there was a slot, and
  /// [_placedKey] which card it was: the place held was chosen for that
  /// card's height, so a different card is placed afresh.
  int? _slotColumn;
  bool _placed = false;
  Key? _placedKey;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! PairedCardsRowParentData) {
      child.parentData = PairedCardsRowParentData();
    }
  }

  RenderBox get _first => firstChild!;
  RenderBox get _second => childAfter(firstChild!)!;
  RenderBox? get _slot => childCount > 2 ? lastChild : null;

  double _columnWidth(double width) => math.max(0, (width - columnGap) / 2);

  /// Where the slot goes for cards [heights] tall, given its height at
  /// column width ([slotInColumn]) and full width ([slotBelow]), each asked
  /// only when needed. With no slot, both are null.
  _Arrangement _arrange(
    List<double> heights, {
    double Function()? slotInColumn,
    double Function()? slotBelow,
    bool? heldInColumn,
    int? heldColumn,
  }) {
    final tallest = math.max(heights[0], heights[1]);
    if (slotInColumn == null || slotBelow == null) {
      return (column: null, height: tallest);
    }
    int? column;
    if (heldInColumn != null) {
      column = heldInColumn ? heldColumn : null;
    } else if (heights[0] != heights[1]) {
      final shorter = heights[0] < heights[1] ? 0 : 1;
      final room = tallest - heights[shorter] - rowGap;
      if (room > 0 && slotInColumn() <= room) column = shorter;
    }
    if (column == null) {
      return (column: null, height: tallest + rowGap + slotBelow());
    }
    final stacked = heights[column] + rowGap + slotInColumn();
    return (column: column, height: math.max(tallest, stacked));
  }

  /// [_arrange] for children measured by [heightAt], a child's height at a
  /// width.
  double _arrangedHeight(
    double width,
    double Function(RenderBox child, double width) heightAt,
  ) {
    if (childCount < 2) return 0;
    final column = _columnWidth(width);
    final slot = _slot;
    return _arrange(
      [heightAt(_first, column), heightAt(_second, column)],
      slotInColumn: slot == null ? null : () => heightAt(slot, column),
      slotBelow: slot == null ? null : () => heightAt(slot, width),
    ).height;
  }

  // The columns are equal, so the pair needs both as wide as the wider card
  // needs, as a Row of Expanded children does; the slot may sit below at
  // full width.
  double _intrinsicWidth(double Function(RenderBox child) widthOf) {
    if (childCount < 2) return 0;
    final pair = math.max(widthOf(_first), widthOf(_second)) * 2 + columnGap;
    final slot = _slot;
    return slot == null ? pair : math.max(pair, widthOf(slot));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicWidth((c) => c.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicWidth((c) => c.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _arrangedHeight(width, (c, w) => c.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _arrangedHeight(width, (c, w) => c.getMaxIntrinsicHeight(w));

  /// A child's constraints at [width]: that exact width, and any height up
  /// to what the row is offered.
  BoxConstraints _at(double width, BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: constraints.maxHeight,
      );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    assert(constraints.hasBoundedWidth, 'PairedCardsRow needs a bounded width');
    final height = _arrangedHeight(
      constraints.maxWidth,
      (c, w) => c.getDryLayout(_at(w, constraints)).height,
    );
    return constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    assert(constraints.hasBoundedWidth, 'PairedCardsRow needs a bounded width');
    final width = constraints.maxWidth;
    if (childCount < 2) {
      size = constraints.constrain(Size(width, 0));
      return;
    }
    final columnWidth = _columnWidth(width);
    final inColumn = _at(columnWidth, constraints);
    final below = _at(width, constraints);
    final first = _first;
    final second = _second;
    final slot = _slot;

    first.layout(inColumn, parentUsesSize: true);
    second.layout(inColumn, parentUsesSize: true);
    final heights = [first.size.height, second.size.height];

    final hold =
        holdPlacement && slot != null && _placed && slotKey == _placedKey;
    final arrangement = _arrange(
      heights,
      slotInColumn: slot == null
          ? null
          : () {
              slot.layout(inColumn, parentUsesSize: true);
              return slot.size.height;
            },
      slotBelow: slot == null
          ? null
          : () {
              slot.layout(below, parentUsesSize: true);
              return slot.size.height;
            },
      heldInColumn: hold ? _slotColumn != null : null,
      heldColumn: hold ? _slotColumn : null,
    );
    _placed = slot != null;
    _placedKey = slotKey;
    _slotColumn = arrangement.column;

    final slotColumn = arrangement.column;
    final rowHeight = slotColumn == null
        ? math.max(heights[0], heights[1])
        : arrangement.height;
    // The last box in each column grows to bring its column level with the
    // row. A minimum, not a tight height: tight constraints would make it
    // its own relayout boundary, and content that grows inside it later (a
    // tide record arriving) would relayout it at this stale height without
    // telling the row.
    for (final column in [0, 1]) {
      final card = column == 0 ? first : second;
      final last = column == slotColumn ? slot! : card;
      final above = column == slotColumn ? heights[column] + rowGap : 0.0;
      final needed = rowHeight - above;
      if (last.size.height < needed) {
        last.layout(inColumn.copyWith(minHeight: needed), parentUsesSize: true);
      }
    }

    double columnX(int column) {
      final start = column * (columnWidth + columnGap);
      return switch (textDirection) {
        TextDirection.ltr => start,
        TextDirection.rtl => width - columnWidth - start,
      };
    }

    _offset(first, Offset(columnX(0), 0));
    _offset(second, Offset(columnX(1), 0));
    if (slot != null) {
      _offset(
        slot,
        slotColumn == null
            ? Offset(0, rowHeight + rowGap)
            : Offset(columnX(slotColumn), heights[slotColumn] + rowGap),
      );
    }
    final height = slotColumn == null && slot != null
        ? rowHeight + rowGap + slot.size.height
        : rowHeight;
    size = constraints.constrain(Size(width, height));
  }

  static void _offset(RenderBox child, Offset offset) =>
      (child.parentData! as PairedCardsRowParentData).offset = offset;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
