import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_chip_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_figure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_figure_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_gauges.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_pieces_list.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_test_item_form.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_tryout_controller.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One sample of the dive the time slider can stop at.
class TrimMoment {
  const TrimMoment({required this.timestamp, required this.depthM});

  final int timestamp;
  final double depthM;
}

/// Opens the try-out sheet (issue #5028), at [openingTimestamp] of the dive
/// (null: the rest anchor). Nothing in it is saved; closing it discards it.
Future<void> showTrimTryoutSheet(
  BuildContext context, {
  required TrimSceneAt sceneAt,
  required int? openingTimestamp,
  required List<TrimMoment> moments,
  required UnitFormatter units,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _TrimTryoutSheet(
    sceneAt: sceneAt,
    openingTimestamp: openingTimestamp,
    moments: moments,
    units: units,
  ),
);

class _TrimTryoutSheet extends StatefulWidget {
  const _TrimTryoutSheet({
    required this.sceneAt,
    required this.openingTimestamp,
    required this.moments,
    required this.units,
  });

  final TrimSceneAt sceneAt;
  final int? openingTimestamp;
  final List<TrimMoment> moments;
  final UnitFormatter units;

  @override
  State<_TrimTryoutSheet> createState() => _TrimTryoutSheetState();
}

class _TrimTryoutSheetState extends State<_TrimTryoutSheet> {
  late final _controller = TrimTryoutController(
    sceneAt: widget.sceneAt,
    openingTimestamp: widget.openingTimestamp,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.9,
    child: SingleChildScrollView(
      child: TrimTryoutView(
        controller: _controller,
        moments: widget.moments,
        units: widget.units,
      ),
    ),
  );
}

/// The try-out sheet's content: the figure (drag a chip to move it, tap it
/// to change its side), the gauges and moments, then pose, time, a test
/// item, the pieces list and Reset.
class TrimTryoutView extends StatefulWidget {
  const TrimTryoutView({
    super.key,
    required this.controller,
    required this.moments,
    required this.units,
  });

  final TrimTryoutController controller;
  final List<TrimMoment> moments;
  final UnitFormatter units;

  static const armsKey = ValueKey('trim-arms');
  static const kneesKey = ValueKey('trim-knees');
  static const timeKey = ValueKey('trim-time');

  @override
  State<TrimTryoutView> createState() => _TrimTryoutViewState();
}

class _TrimTryoutViewState extends State<TrimTryoutView> {
  TrimFigureGeometry? _geometry;
  TrimChipLayout? _chips;
  String? _dragId;
  Offset? _downAt;
  Offset? _dragAt;

  TrimTryoutController get _c => widget.controller;

  String? _chipAt(Offset p) {
    for (final chip
        in (_chips?.chips ?? const <TrimChipPlacement>[]).reversed) {
      if (chip.rect.inflate(4).contains(p)) return chip.elementId;
    }
    return null;
  }

  /// A finger lifted near where it landed taps the chip (its side cycles);
  /// further away, the chip drops on the nearest spot it may use.
  void _drop() {
    final id = _dragId;
    final at = _dragAt;
    final down = _downAt;
    final geometry = _geometry;
    _dragId = null;
    _dragAt = null;
    _downAt = null;
    if (id == null || at == null || down == null || geometry == null) return;
    if ((at - down).distance < kTouchSlop) {
      _c.cycleSide(id);
      return;
    }
    final e = _c.scene.elements.where((x) => x.id == id).firstOrNull;
    if (e == null || !_c.canMove(e)) return;
    _c.move(id, geometry.nearestSpot(at, _c.spotsFor(e)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [_header(context), _controls(context)],
        ),
      );
    },
  );

  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final result = _c.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.trim_tryout_title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          l10n.trim_tryout_hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _ChipPanRecognizer:
                GestureRecognizerFactoryWithHandlers<_ChipPanRecognizer>(
                  () => _ChipPanRecognizer(onChip: (p) => _chipAt(p) != null),
                  (r) => r
                    // The chip is taken where the finger came down: the
                    // pan reports only once the finger has moved off it.
                    ..onDown = (d) {
                      _dragId = _chipAt(d.localPosition);
                      _downAt = d.localPosition;
                      _dragAt = d.localPosition;
                    }
                    ..onUpdate = (d) {
                      _dragAt = d.localPosition;
                    }
                    ..onEnd = (_) => _drop(),
                ),
          },
          child: TrimFigure(
            scene: _c.scene,
            pose: _c.pose,
            result: result,
            units: widget.units,
            showAllChips: true,
            onLayout: (geometry, chips) {
              _geometry = geometry;
              _chips = chips;
            },
          ),
        ),
        const SizedBox(height: 8),
        TrimGauges(result: result),
        const SizedBox(height: 4),
        Text(
          l10n.trim_tryout_moments(
            _formatMoment(result.pitchKgM),
            _formatMoment(result.rollKgM),
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatMoment(double kgM) =>
      widget.units.settings.weightUnit == WeightUnit.pounds
      ? '${(kgM * _lbFtPerKgM).toStringAsFixed(2)} lb·ft'
      : '${kgM.toStringAsFixed(2)} kg·m';

  /// 1 kg m in pound-feet.
  static const _lbFtPerKgM = 2.20462262 * 3.2808399;

  Widget _controls(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pose = _c.pose;
    final moments = widget.moments;
    final small = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget slider({
      required Key key,
      required String label,
      required double value,
      required double max,
      required String start,
      required String end,
      required ValueChanged<double> onChanged,
      int? divisions,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        Slider(
          key: key,
          value: value,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        Row(
          children: [
            Expanded(child: Text(start, style: small)),
            Text(end, style: small),
          ],
        ),
      ],
    );

    final timeIndex = moments.isEmpty
        ? 0
        : _nearestIndex(moments, _c.timestamp ?? moments.last.timestamp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        slider(
          key: TrimTryoutView.armsKey,
          label: l10n.trim_tryout_arms,
          value: pose.armReach,
          max: 1,
          start: l10n.trim_tryout_armsSides,
          end: l10n.trim_tryout_armsAhead,
          // The pose now, not the build's: a second slider moved before the
          // rebuild must not undo the first.
          onChanged: (v) => _c.setPose(_c.pose.copyWith(armReach: v)),
        ),
        slider(
          key: TrimTryoutView.kneesKey,
          label: l10n.trim_tryout_knees,
          value: pose.kneeBendDeg,
          max: 90,
          start: l10n.trim_tryout_kneesStraight,
          end: l10n.trim_tryout_kneesBent,
          onChanged: (v) => _c.setPose(_c.pose.copyWith(kneeBendDeg: v)),
        ),
        if (moments.length > 1) ...[
          Text(l10n.trim_tryout_time, style: theme.textTheme.labelLarge),
          Text(
            l10n.trim_tryout_timeLabel(
              _clock(moments[timeIndex].timestamp),
              widget.units.formatDepth(moments[timeIndex].depthM),
            ),
            style: small,
          ),
          Slider(
            key: TrimTryoutView.timeKey,
            value: timeIndex.toDouble(),
            max: (moments.length - 1).toDouble(),
            divisions: moments.length - 1,
            onChanged: (v) => _c.setTimestamp(moments[v.round()].timestamp),
          ),
        ],
        const SizedBox(height: 8),
        TrimTestItemForm(units: widget.units, onAdd: _c.addTestItem),
        const SizedBox(height: 16),
        Text(l10n.trim_tryout_pieces, style: theme.textTheme.titleSmall),
        TrimPiecesList(controller: _c, units: widget.units),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _c.reset,
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.trim_tryout_reset),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static int _nearestIndex(List<TrimMoment> moments, int timestamp) {
    var best = 0;
    for (var i = 1; i < moments.length; i++) {
      if ((moments[i].timestamp - timestamp).abs() <
          (moments[best].timestamp - timestamp).abs()) {
        best = i;
      }
    }
    return best;
  }

  static String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// A pan that wins at once when the finger lands on a chip, so dragging a
/// chip never scrolls the sheet, and leaves every other touch to the scroll.
class _ChipPanRecognizer extends PanGestureRecognizer {
  _ChipPanRecognizer({required this.onChip});

  final bool Function(Offset localPosition) onChip;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!onChip(event.localPosition)) return;
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
