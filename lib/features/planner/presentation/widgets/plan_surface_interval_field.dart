import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/utils/hours_minutes.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The surface interval before the selected dive (issue #3565), in h:mm with
/// 15-minute steppers.
///
/// The interval is the source of truth for when the dive starts: the end
/// of the dive before it plus this. Not [enabled] on a first dive that
/// follows no logged dive, where there is no interval to set: shown empty
/// and greyed out, so the panels below keep their place from dive to dive.
class PlanSurfaceIntervalField extends ConsumerStatefulWidget {
  const PlanSurfaceIntervalField({super.key, this.enabled = true});

  final bool enabled;

  @override
  ConsumerState<PlanSurfaceIntervalField> createState() =>
      _PlanSurfaceIntervalFieldState();
}

class _PlanSurfaceIntervalFieldState
    extends ConsumerState<PlanSurfaceIntervalField> {
  static const _step = Duration(minutes: 15);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _show(_interval);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && widget.enabled) _commit();
    });
  }

  @override
  void didUpdateWidget(PlanSurfaceIntervalField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    _invalid = false;
    if (widget.enabled) {
      _show(_interval);
    } else {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Duration get _interval =>
      ref.read(divePlanNotifierProvider).surfaceInterval ??
      defaultSeriesSurfaceInterval;

  void _show(Duration interval) {
    final text = formatHoursMinutes(interval);
    if (_controller.text != text) _controller.text = text;
  }

  void _set(Duration interval) {
    setState(() => _invalid = false);
    _show(interval);
    if (interval != ref.read(divePlanNotifierProvider).surfaceInterval) {
      ref.read(divePlanNotifierProvider.notifier).setSurfaceInterval(interval);
    }
  }

  void _commit() {
    // Untouched text is only the interval as shown, to the minute, so
    // leaving the field must not write it back over the real one.
    if (_controller.text == formatHoursMinutes(_interval)) return;
    final parsed = parseHoursMinutes(_controller.text);
    if (parsed == null) {
      setState(() => _invalid = true);
      return;
    }
    _set(parsed);
  }

  void _stepBy(Duration delta) {
    final next = _interval + delta;
    _set(next.isNegative ? Duration.zero : next);
  }

  @override
  Widget build(BuildContext context) {
    // Another dive in the editor: anything left in the field was not for it.
    ref.listen(divePlanNotifierProvider.select((s) => s.id), (_, _) {
      if (!widget.enabled) return;
      if (_invalid) setState(() => _invalid = false);
      _show(_interval);
    });
    // Follow changes made elsewhere (a followed dive) without fighting the
    // diver's typing.
    ref.listen(divePlanNotifierProvider.select((s) => s.surfaceInterval), (
      _,
      next,
    ) {
      if (_focusNode.hasFocus || !widget.enabled) return;
      if (_invalid) setState(() => _invalid = false);
      _show(next ?? defaultSeriesSurfaceInterval);
    });

    final l10n = context.l10n;
    final enabled = widget.enabled;
    // Greyed out like the disabled controls below it.
    final labelColor = enabled ? null : Theme.of(context).disabledColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.timer_outlined, size: 18, color: labelColor),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.plannerSeries_surfaceInterval,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: labelColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: l10n.plannerSeries_surfaceInterval_decrease,
              onPressed: enabled ? () => _stepBy(-_step) : null,
            ),
            Expanded(
              child: Semantics(
                label: l10n.plannerSeries_surfaceInterval,
                child: TextField(
                  key: const Key('surfaceIntervalField'),
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: enabled,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    errorText: _invalid
                        ? l10n.plannerSeries_surfaceInterval_invalid
                        : null,
                  ),
                  onChanged: (_) {
                    if (_invalid) setState(() => _invalid = false);
                  },
                  onSubmitted: (_) => _commit(),
                  // On every platform, so a touch on another dive or a stepper
                  // commits this one first: leaving the field does that.
                  onTapOutside: (_) => _focusNode.unfocus(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.plannerSeries_surfaceInterval_increase,
              onPressed: enabled ? () => _stepBy(_step) : null,
            ),
          ],
        ),
      ],
    );
  }
}
