import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Always-visible floating readout for the fullscreen profile page.
///
/// Renders the latest externally emitted tooltip rows (see
/// [DiveProfileChart.onTooltipData]) in a compact card the user can drag
/// anywhere within the enclosing [Stack]. Position is a fraction of the
/// movable range (the stack area minus a 12 px inset margin, minus the card
/// size): (0,0) puts the card at the inset top-left corner, (1,1) at the
/// inset bottom-right. Out-of-range fractions are clamped so a bad persisted
/// value can never strand the card outside the visible (clipped) area. Must
/// be placed directly inside a [Stack].
class DraggableReadoutCard extends StatefulWidget {
  /// Latest tooltip rows; null or empty shows the placeholder hint.
  final List<TooltipRow>? rows;

  /// Starting position fraction; null uses [defaultFraction].
  final Offset? initialFraction;

  /// Called with the final position fraction when a drag ends. The caller
  /// persists it (the fullscreen page saves it to settings).
  final ValueChanged<Offset> onDragEnd;

  const DraggableReadoutCard({
    super.key,
    required this.rows,
    required this.initialFraction,
    required this.onDragEnd,
  });

  /// Default position: top-right corner.
  static const Offset defaultFraction = Offset(1, 0);

  @override
  State<DraggableReadoutCard> createState() => _DraggableReadoutCardState();
}

class _DraggableReadoutCardState extends State<DraggableReadoutCard> {
  static const _inset = 12.0;
  final GlobalKey _cardKey = GlobalKey();
  late Offset _fraction = _clamp01(
    widget.initialFraction ?? DraggableReadoutCard.defaultFraction,
  );

  /// Nothing enforces the 0..1 contract on persisted values, and the Stack
  /// clips: an out-of-range fraction would render the card invisible and
  /// undraggable with no way to recover.
  static Offset _clamp01(Offset fraction) =>
      Offset(fraction.dx.clamp(0.0, 1.0), fraction.dy.clamp(0.0, 1.0));

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final cardSize = _cardKey.currentContext?.size;
    if (cardSize == null) return;
    final movableW = constraints.maxWidth - cardSize.width;
    final movableH = constraints.maxHeight - cardSize.height;
    setState(() {
      _fraction = Offset(
        movableW <= 0
            ? 0
            : (_fraction.dx + details.delta.dx / movableW).clamp(0.0, 1.0),
        movableH <= 0
            ? 0
            : (_fraction.dy + details.delta.dy / movableH).clamp(0.0, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rows = widget.rows;

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: FractionalOffset(_fraction.dx, _fraction.dy),
            child: GestureDetector(
              // Sized by its child: measuring this context yields the card
              // size for the fraction math in _onPanUpdate.
              key: _cardKey,
              onPanUpdate: (details) => _onPanUpdate(details, constraints),
              onPanEnd: (_) => widget.onDragEnd(_fraction),
              child: Container(
                key: const ValueKey('readout-card'),
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: rows == null || rows.isEmpty
                    ? Text(
                        context.l10n.diveLog_fullscreenProfile_readoutHint,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final row in rows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: row.bulletColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      row.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(row.value, style: textTheme.bodySmall),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
