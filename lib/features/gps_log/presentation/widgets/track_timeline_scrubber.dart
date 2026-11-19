import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// Whether the scrubber picks a range (trim) or a single instant (split).
enum TrackScrubberMode { range, single }

/// A timeline over a track's span, in wall-clock-as-UTC milliseconds.
///
/// Labels format the UTC components directly - the times belong to the
/// recording device's wall clock, so converting to the viewer's zone would
/// shift every label for anyone reviewing a track from another country.
class TrackTimelineScrubber extends ConsumerStatefulWidget {
  const TrackTimelineScrubber({
    super.key,
    required this.startMs,
    required this.endMs,
    required this.mode,
    required this.onChanged,
    this.initialStartMs,
    this.initialEndMs,
    this.onChangeEnd,
  });

  final int startMs;
  final int endMs;
  final TrackScrubberMode mode;

  /// Where a range's handles start, clamped to the span; the span's own
  /// ends when null. A trim editor opens on the trim it is changing.
  final int? initialStartMs;
  final int? initialEndMs;

  /// Called once when a drag ends, with the values it ended on, so a
  /// listener whose work is costly (a trim recalculating the whole track)
  /// does it once per drag rather than on every frame of it.
  final void Function(int startMs, int endMs)? onChangeEnd;

  /// For [TrackScrubberMode.range], both bounds. For
  /// [TrackScrubberMode.single], the same value is passed twice.
  final void Function(int startMs, int endMs) onChanged;

  @override
  ConsumerState<TrackTimelineScrubber> createState() =>
      _TrackTimelineScrubberState();
}

class _TrackTimelineScrubberState extends ConsumerState<TrackTimelineScrubber> {
  late double _low = _clamp(widget.initialStartMs ?? widget.startMs);
  late double _high = _clamp(widget.initialEndMs ?? widget.endMs);

  /// [ms] inside the span, as the slider requires.
  double _clamp(int ms) {
    final min = widget.startMs.toDouble();
    final max = widget.endMs.toDouble();
    if (max <= min) return min;
    return ms.toDouble().clamp(min, max);
  }

  late double _single = (widget.startMs + (widget.endMs - widget.startMs) / 2)
      .toDouble();

  /// Re-anchors the handles when the span itself changes.
  ///
  /// The handles were seeded once from the first build. Applying a trim
  /// shrinks effectivePoints, so the panel rebuilds with a narrower span
  /// while this State survives - and Slider asserts when its value falls
  /// outside min..max, so the old handles would take the page down rather
  /// than merely look wrong.
  @override
  void didUpdateWidget(TrackTimelineScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The starting bounds too: a trim changed underneath (a sync) over the
    // same recording moves the handles to it.
    if (oldWidget.startMs == widget.startMs &&
        oldWidget.endMs == widget.endMs &&
        oldWidget.initialStartMs == widget.initialStartMs &&
        oldWidget.initialEndMs == widget.initialEndMs) {
      return;
    }
    setState(() {
      _low = _clamp(widget.initialStartMs ?? widget.startMs);
      _high = _clamp(widget.initialEndMs ?? widget.endMs);
      _single = (widget.startMs + (widget.endMs - widget.startMs) / 2)
          .toDouble();
    });
  }

  /// Wall-clock-as-UTC, rendered in the diver's 12h/24h preference rather
  /// than a hardcoded 24-hour clock.
  String _label(num ms) => ref
      .watch(unitFormatterProvider)
      .formatTime(DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final min = widget.startMs.toDouble();
    final max = widget.endMs.toDouble();

    // A zero-length span would make the slider assert; show it disabled
    // rather than crashing on a degenerate track.
    if (max <= min) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_label(min), style: theme.textTheme.labelMedium),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mode == TrackScrubberMode.range)
          RangeSlider(
            values: RangeValues(_low, _high),
            min: min,
            max: max,
            labels: RangeLabels(_label(_low), _label(_high)),
            onChanged: (v) {
              setState(() {
                _low = v.start;
                _high = v.end;
              });
              widget.onChanged(v.start.toInt(), v.end.toInt());
            },
            onChangeEnd: widget.onChangeEnd == null
                ? null
                : (v) => widget.onChangeEnd!(v.start.toInt(), v.end.toInt()),
          )
        else
          Slider(
            value: _single,
            min: min,
            max: max,
            label: _label(_single),
            onChanged: (v) {
              setState(() => _single = v);
              widget.onChanged(v.toInt(), v.toInt());
            },
            onChangeEnd: widget.onChangeEnd == null
                ? null
                : (v) => widget.onChangeEnd!(v.toInt(), v.toInt()),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_label(min), style: theme.textTheme.labelSmall),
            Text(_label(max), style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}
