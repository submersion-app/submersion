import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure_painter.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_labels.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_leader_painter.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_name_label.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';

/// How the figure is shown. Phase 1 ships the pair; later phases add a
/// thumbnail and a locate mode.
enum FigureMode { pair }

/// The diver figure with every placed item named on it (spec section 8).
///
/// Below [wideBreakpoint] one side shows at a time behind a Front / Back
/// switch, with label columns either side; from it upward the front and
/// back sit side by side with a name pill beside each item. Items with no
/// place on the body are tiles in a tray beneath.
class DiverFigure extends StatefulWidget {
  const DiverFigure({
    super.key,
    required this.model,
    required this.semanticsLabel,
    required this.labelText,
    required this.sideLabel,
    this.mode = FigureMode.pair,
    this.selectedItemId,
    this.onItemTap,
    this.itemSemantics,
    this.trayTitle,
  });

  static const double wideBreakpoint = 600;

  /// The tallest single figure on a phone.
  static const double phoneMaxFigureHeight = 420;

  final FigureModel model;

  /// Read for the whole picture, for example "Reef set, 9 items".
  final String semanticsLabel;

  /// The name shown on an item's label.
  final String Function(PlacedItem item) labelText;

  /// A switch segment's text, for example "Front · 8".
  final String Function(FigureView view, int count) sideLabel;
  final FigureMode mode;
  final String? selectedItemId;
  final ValueChanged<PlacedItem>? onItemTap;

  /// The screen-reader label of an item, for example "3, BCD, Hollis SMS75".
  final String Function(PlacedItem item)? itemSemantics;

  /// Heading over the tray. The tray is hidden when the model has none.
  final String? trayTitle;

  @override
  State<DiverFigure> createState() => _DiverFigureState();
}

class _DiverFigureState extends State<DiverFigure> {
  FigureView _view = FigureView.front;

  @override
  void didUpdateWidget(DiverFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A newly selected item on the hidden side brings that side forward, so
    // tapping a back item's row on a phone shows its label.
    final id = widget.selectedItemId;
    if (id == null || id == oldWidget.selectedItemId) return;
    final zone = widget.model.byId(id)?.zone;
    if (zone != null) _view = zone.view;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final figures = width >= DiverFigure.wideBreakpoint
            ? _wide(context, width)
            : _phone(context, width);
        if (widget.model.tray.isEmpty) return figures;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            figures,
            const SizedBox(height: 8),
            if (widget.trayTitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  widget.trayTitle!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in widget.model.tray)
                  _TrayTile(
                    item: item,
                    name: widget.labelText(item),
                    selected: item.item.id == widget.selectedItemId,
                    semanticsLabel: widget.itemSemantics?.call(item),
                    onTap: widget.onItemTap == null
                        ? null
                        : () => widget.onItemTap!(item),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _phone(BuildContext context, double width) {
    final counts = {
      for (final view in FigureView.values)
        view: widget.model.placed.where((p) => p.zone!.view == view).length,
    };
    final layout = FigureLayout.forSingle(
      Size(width, DiverFigure.phoneMaxFigureHeight),
    );
    final slots = labelColumns(
      model: widget.model,
      view: _view,
      layout: layout,
      width: width,
      labelHeight: FigureNameLabel.heightFor(context, pill: false),
    );
    return Column(
      children: [
        SegmentedButton<FigureView>(
          segments: [
            for (final view in FigureView.values)
              ButtonSegment(
                value: view,
                label: Text(widget.sideLabel(view, counts[view]!)),
              ),
          ],
          selected: {_view},
          showSelectedIcon: false,
          onSelectionChanged: (views) => setState(() => _view = views.first),
        ),
        const SizedBox(height: 12),
        _canvas(context, width, layout, slots, only: _view),
      ],
    );
  }

  Widget _wide(BuildContext context, double width) {
    // The pair's spare width is split evenly between the two margins and the
    // gutter, so pills have room on every side of both figures.
    final height = FigureLayout.preferredHeight(width);
    final gutter = ((width - height) / 3).clamp(FigureLayout.gutter, 220.0);
    final layout = FigureLayout.forSize(Size(width, height), gutter: gutter);
    final style = FigureNameLabel.styleOf(context);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final slots = labelPills(
      model: widget.model,
      layout: layout,
      width: width,
      maxWidth: width / 4,
      labelHeight: FigureNameLabel.heightFor(context, pill: true),
      widthOf: (p) => FigureNameLabel.preferredWidth(
        widget.labelText(p),
        style,
        direction,
        textScaler: scaler,
      ),
    );
    return _canvas(context, width, layout, slots);
  }

  Widget _canvas(
    BuildContext context,
    double width,
    FigureLayout layout,
    List<FigureLabelSlot> slots, {
    FigureView? only,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final palette = figurePaletteFor(scheme);
    final height = [
      layout.front.bottom,
      for (final slot in slots) slot.rect.bottom,
    ].reduce(math.max);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Semantics(
              label: widget.semanticsLabel,
              image: true,
              excludeSemantics: true,
              child: CustomPaint(
                painter: DiverFigurePainter(
                  model: widget.model,
                  palette: palette,
                  layout: layout,
                  only: only,
                ),
                foregroundPainter: FigureLeaderPainter(
                  slots: slots,
                  color: scheme.outline,
                ),
              ),
            ),
          ),
          for (final slot in slots)
            Positioned.fromRect(
              rect: slot.rect,
              child: FigureNameLabel(
                key: ValueKey('figure-label-${slot.item.item.id}'),
                number: slot.item.number,
                text: widget.labelText(slot.item),
                alignEnd: slot.onLeft,
                pill: only == null,
                selected: slot.item.item.id == widget.selectedItemId,
                semanticsLabel: widget.itemSemantics?.call(slot.item),
                onTap: widget.onItemTap == null
                    ? null
                    : () => widget.onItemTap!(slot.item),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrayTile extends StatelessWidget {
  const _TrayTile({
    required this.item,
    required this.name,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  final PlacedItem item;
  final String name;
  final bool selected;
  final String? semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = selected ? figureHighlightFor(scheme) : null;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticsLabel != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: kFigureLabelHeight),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: (highlight ?? figurePillFor(scheme)).fill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FigureNumberBadge(
                number: item.number,
                size: FigureNameLabel.badgeSize,
              ),
              const SizedBox(width: 6),
              Icon(
                equipmentTypeIcon(item.item.type),
                size: 18,
                color: highlight?.onFill,
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: FigureNameLabel.styleOf(
                  context,
                ).copyWith(color: highlight?.onFill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
