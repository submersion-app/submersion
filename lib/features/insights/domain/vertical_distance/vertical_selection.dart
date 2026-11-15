import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';

/// What the pointer or finger is on: a level on one of the bars (issue
/// #4569).
class VerticalProbe {
  const VerticalProbe({
    required this.direction,
    required this.meters,
    this.landmark,
    this.ahead = false,
  });

  final VerticalLeg direction;

  /// The level, in metres from sea level.
  final double meters;

  /// The landmark the level snapped to, or the next landmark when [ahead].
  final VerticalLandmark? landmark;

  /// The level is the dashed next landmark, above the diver's total, so it
  /// has no date and no dive.
  final bool ahead;
}

/// The readout's state. Hovering follows the pointer; a click or a tap pins
/// a level so the pointer can leave the bar and reach the Open dive action.
sealed class VerticalSelection {
  const VerticalSelection();

  /// The selected level, or null when idle.
  VerticalProbe? get probe;
}

final class VerticalIdle extends VerticalSelection {
  const VerticalIdle();

  @override
  VerticalProbe? get probe => null;
}

final class VerticalHovering extends VerticalSelection {
  const VerticalHovering(this.probe);

  @override
  final VerticalProbe probe;
}

final class VerticalPinned extends VerticalSelection {
  const VerticalPinned(this.probe);

  @override
  final VerticalProbe probe;
}

/// The pointer moved. While pinned nothing changes; otherwise it hovers the
/// level under the pointer, or goes idle off the bars.
VerticalSelection hoverSelection(VerticalSelection s, VerticalProbe? probe) {
  if (s is VerticalPinned) return s;
  return probe == null ? const VerticalIdle() : VerticalHovering(probe);
}

/// The pointer left the scale. A pinned level stays.
VerticalSelection exitSelection(VerticalSelection s) =>
    s is VerticalPinned ? s : const VerticalIdle();

/// A click or tap. On a level it pins that level, from any state; away from
/// the bars it unpins.
VerticalSelection tapSelection(VerticalSelection s, VerticalProbe? probe) =>
    probe == null ? const VerticalIdle() : VerticalPinned(probe);
