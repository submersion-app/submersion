import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_chip_layout.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_figure_geometry.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_figure_painter.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_strings.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The posable side-view diver for one trim scene (issue #5028): tilted by
/// [result]'s pitch, with a chip naming each lead weight (every element
/// with [showAllChips], as the trim calculator shows them).
class TrimFigure extends StatelessWidget {
  const TrimFigure({
    super.key,
    required this.scene,
    required this.pose,
    required this.result,
    required this.units,
    this.showAllChips = false,
    this.selectedElementId,
    this.maxFigureHeight = 260,
    this.onLayout,
    this.dragTarget,
    this.dragGhost,
  });

  final TrimScene scene;
  final TrimPose pose;
  final TrimResult result;
  final UnitFormatter units;
  final bool showAllChips;
  final String? selectedElementId;
  final double maxFigureHeight;

  /// Called with the geometry and chips each build, for a host that hit-tests
  /// drags (the trim calculator).
  final void Function(TrimFigureGeometry geometry, TrimChipLayout chips)?
  onLayout;

  /// While a chip is dragged: the spot anchor it would land on and its
  /// outline under the finger (see [TrimFigurePainter.dragTarget]).
  final Offset? dragTarget;
  final Rect? dragGhost;

  /// Lead and test items always; with [showAllChips], tanks and any gear
  /// heavy or light enough to matter too. Gear lighter than [minChipKg], and
  /// a suit spread over the body, would only crowd the figure; the trim
  /// calculator's Pieces list names them.
  bool _chipped(TrimElement e) => switch (e.kind) {
    TrimElementKind.lead || TrimElementKind.test => true,
    TrimElementKind.tank => showAllChips,
    _ =>
      showAllChips &&
          e.spot != TrimSpot.floatPoint &&
          e.totalSinkKg.abs() >= minChipKg,
  };

  static const double minChipKg = 0.2;

  String chipText(TrimElement e, BuildContext context) {
    final l10n = context.l10n;
    final side = trimSideMark(e, l10n);
    final text = l10n.trim_chip_weight(
      trimElementName(e, l10n),
      units.formatWeight(trimShownKg(e.totalSinkKg)),
    );
    final sided = side.isEmpty ? text : '$text $side';
    return e.spotUnknown ? '$sided (${l10n.trim_chip_note})' : sided;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle =
        theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11);
    final direction = Directionality.of(context);
    final chipped = [
      for (final e in scene.elements)
        if (_chipped(e)) e,
    ];
    final texts = {for (final e in chipped) e.id: chipText(e, context)};
    final styles = {
      for (final e in chipped)
        e.id: switch (e.kind) {
          TrimElementKind.lead => TrimChipStyle(
            fill: scheme.secondaryContainer,
            text: scheme.onSecondaryContainer,
            textStyle: textStyle,
          ),
          TrimElementKind.test => TrimChipStyle(
            fill: scheme.tertiaryContainer,
            text: scheme.onTertiaryContainer,
            textStyle: textStyle,
          ),
          _ => TrimChipStyle(
            fill: scheme.surfaceContainerHighest,
            text: scheme.onSurface,
            textStyle: textStyle,
          ),
        },
    };

    return Semantics(
      container: true,
      label: _summary(context),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final figureHeight = math.min(
              width / TrimFigureGeometry.aspect,
              maxFigureHeight,
            );
            TrimFigureGeometry geometryAt(double top) => TrimFigureGeometry(
              box: Rect.fromLTWH(0, top, width, figureHeight),
              body: scene.body,
              pose: pose,
              tiltDeg: result.tiltDeg,
            );
            TrimChipLayout chipsFor(TrimFigureGeometry g, double top) =>
                packTrimChips(
                  [
                    for (final e in chipped)
                      TrimChipRequest(
                        elementId: e.id,
                        anchor: g.anchorOfElement(e),
                        size: _measure(
                          texts[e.id]!,
                          textStyle,
                          width,
                          direction,
                        ),
                        above: e.spot.pointOn(scene.body, pose).z > 0,
                      ),
                  ],
                  width: width,
                  figureTop: top,
                  figureBottom: top + figureHeight,
                );
            final first = chipsFor(geometryAt(0), 0);
            final shift = -first.topOf(0);
            final geometry = geometryAt(shift);
            final chips = chipsFor(geometry, shift);
            onLayout?.call(geometry, chips);
            return SizedBox(
              width: width,
              height: chips.bottomOf(shift + figureHeight),
              child: CustomPaint(
                painter: TrimFigurePainter(
                  elements: scene.elements,
                  geometry: geometry,
                  palette: figurePaletteFor(scheme),
                  chips: chips.chips,
                  chipTexts: texts,
                  chipStyles: styles,
                  leaderColor: scheme.onSurfaceVariant,
                  selectedElementId: selectedElementId,
                  selectedColor: scheme.primary,
                  textDirection: direction,
                  dragTarget: dragTarget,
                  dragGhost: dragGhost,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Size _measure(
    String text,
    TextStyle style,
    double maxWidth,
    TextDirection direction,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: direction,
    )..layout();
    // Padding of 6 each side; a chip never takes more than half the width,
    // so a long name ellipsizes rather than crowding out the rest.
    final size = Size(math.min(tp.width + 12, maxWidth / 2), tp.height + 6);
    tp.dispose();
    return size;
  }

  /// An element as a screen reader says it: the side as a word, not the
  /// chip's letter.
  String _spokenText(TrimElement e, BuildContext context) {
    final l10n = context.l10n;
    final text = l10n.trim_chip_weight(
      trimElementName(e, l10n),
      units.formatWeight(trimShownKg(e.totalSinkKg)),
    );
    final side = !e.spot.sided
        ? null
        : switch (e.lateral) {
            TrimLateral.left => l10n.diveLog_weight_side_left,
            TrimLateral.right => l10n.diveLog_weight_side_right,
            TrimLateral.centre => null,
          };
    final where = trimSpotLabelFor(e, l10n);
    return [
      text,
      ?side,
      where,
      if (e.spotUnknown) l10n.trim_chip_note,
    ].join(' ');
  }

  String _summary(BuildContext context) {
    final l10n = context.l10n;
    final lead = [
      for (final e in scene.elements)
        if (e.kind == TrimElementKind.lead || e.kind == TrimElementKind.test)
          _spokenText(e, context),
    ].join(', ');
    final verdict = trimVerdictLine(result, l10n);
    return lead.isEmpty
        ? l10n.trim_figure_summaryNoLead(verdict)
        : l10n.trim_figure_summary(verdict, lead);
  }
}
