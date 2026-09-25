import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure_painter.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';

/// How the figure is shown. Phase 1 ships the pair; later phases add a
/// thumbnail and a locate mode.
enum FigureMode { pair }

/// The front and back figures with a numbered disc per placed item, and a
/// tray of tiles for items with no place on the body.
class DiverFigure extends StatelessWidget {
  const DiverFigure({
    super.key,
    required this.model,
    required this.semanticsLabel,
    this.mode = FigureMode.pair,
    this.selectedItemId,
    this.onItemTap,
    this.discLabel,
    this.trayTitle,
  });

  static const double discSize = 20;
  static const double hitSize = 40;

  final FigureModel model;

  /// Read for the whole picture, for example "Reef set, 9 items".
  final String semanticsLabel;
  final FigureMode mode;
  final String? selectedItemId;
  final ValueChanged<PlacedItem>? onItemTap;

  /// The screen-reader label of one disc, for example "3, BCD, Hollis SMS75".
  final String Function(PlacedItem item)? discLabel;

  /// Heading over the tray. The tray is hidden when the model has none.
  final String? trayTitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final height = FigureLayout.preferredHeight(width);
        final layout = FigureLayout.forSize(Size(width, height));
        final positions = discPositions(model, layout);
        final palette = figurePaletteFor(Theme.of(context).colorScheme);
        final figures = SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Semantics(
                  label: semanticsLabel,
                  image: true,
                  excludeSemantics: true,
                  child: CustomPaint(
                    painter: DiverFigurePainter(model: model, palette: palette),
                  ),
                ),
              ),
              for (final item in model.placed)
                Positioned(
                  left: positions[item.item.id]!.dx - hitSize / 2,
                  top: positions[item.item.id]!.dy - hitSize / 2,
                  child: SizedBox(
                    key: ValueKey('figure-disc-${item.item.id}'),
                    width: hitSize,
                    height: hitSize,
                    child: Center(
                      child: FigureNumberBadge(
                        number: item.number,
                        size: discSize,
                        selected: item.item.id == selectedItemId,
                        semanticsLabel: discLabel?.call(item),
                        onTap: onItemTap == null
                            ? null
                            : () => onItemTap!(item),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        if (model.tray.isEmpty) return figures;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            figures,
            const SizedBox(height: 8),
            if (trayTitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  trayTitle!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in model.tray)
                  _TrayTile(
                    item: item,
                    selected: item.item.id == selectedItemId,
                    semanticsLabel: discLabel?.call(item),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Disc centres in box space, in number order, nudged down and right when
/// an earlier disc sits within 22 points.
Map<String, Offset> discPositions(FigureModel model, FigureLayout layout) {
  const minDistance = 22.0;
  const nudge = Offset(14, 14);
  final result = <String, Offset>{};
  final taken = <Offset>[];
  final items = [...model.placed]..sort((a, b) => a.number.compareTo(b.number));
  for (final item in items) {
    final zone = item.zone!;
    var p = layout.toBox(zone.view, zone.anchorX, zone.anchorY);
    while (taken.any((t) => (t - p).distance < minDistance)) {
      p += nudge;
    }
    taken.add(p);
    result[item.item.id] = p;
  }
  return result;
}

class _TrayTile extends StatelessWidget {
  const _TrayTile({
    required this.item,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  final PlacedItem item;
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
          constraints: const BoxConstraints(minHeight: DiverFigure.hitSize),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: highlight?.fill ?? scheme.surfaceContainerHighest,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FigureNumberBadge(
                number: item.number,
                size: DiverFigure.discSize,
              ),
              const SizedBox(width: 6),
              Icon(
                equipmentTypeIcon(item.item.type),
                size: 18,
                color: highlight?.onFill,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
