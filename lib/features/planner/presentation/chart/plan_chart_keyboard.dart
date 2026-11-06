import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_edit_controller.dart';

/// Edits the waypoint at the end of [selectedId] from the keyboard: Delete or
/// Backspace removes it, Up and Down move it one display depth unit (the
/// depth axis grows downward, so Down deepens), Left and Right shorten or
/// lengthen its segment by a minute. [ordered] is the plan's segments in
/// order; [depthUnitScale] converts metres to the display unit.
KeyEventResult planChartKeyEdit(
  KeyEvent event, {
  required List<PlanSegment> ordered,
  required String? selectedId,
  required double depthUnitScale,
  required void Function(String id, PlanSegment segment) updateSegment,
  required void Function(String segmentId) removeWaypoint,
}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  if (selectedId == null) return KeyEventResult.ignored;
  final index = ordered.indexWhere((s) => s.id == selectedId);
  if (index < 0) return KeyEventResult.ignored;
  final segment = ordered[index];
  final key = event.logicalKey;

  if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
    removeWaypoint(selectedId);
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowUp) {
    final unitMeters = 1 / depthUnitScale;
    final delta = key == LogicalKeyboardKey.arrowDown
        ? unitMeters
        : -unitMeters;
    final result = dragVertex(
      ordered: ordered,
      vertexIndex: index,
      newDepthMeters: segment.targetDepth + delta,
      newTimeSeconds: _endTimeOf(ordered, index),
      depthUnitScale: depthUnitScale,
    );
    for (final (id, updated) in result.updates) {
      updateSegment(id, updated);
    }
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight) {
    final delta = key == LogicalKeyboardKey.arrowRight ? 60 : -60;
    final newDuration = (segment.durationSeconds + delta).clamp(60, 6000 * 60);
    updateSegment(selectedId, segment.copyWith(durationSeconds: newDuration));
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

double _endTimeOf(List<PlanSegment> ordered, int index) {
  var t = 0.0;
  for (var i = 0; i <= index; i++) {
    t += ordered[i].durationSeconds;
  }
  return t;
}
