import 'dart:ui' show Color;

import 'package:equatable/equatable.dart';

/// A label drawn on the scrubber track at [slot].
class ScrubberMarker extends Equatable {
  const ScrubberMarker({required this.slot, required this.label});

  final int slot;
  final String label;

  @override
  List<Object?> get props => [slot, label];
}

/// A coloured stripe in the scrubber's context column from [firstSlot] to
/// [lastSlot].
class ScrubberSegment extends Equatable {
  const ScrubberSegment({
    required this.firstSlot,
    required this.lastSlot,
    required this.color,
  });

  final int firstSlot;
  final int lastSlot;
  final Color color;

  @override
  List<Object?> get props => [firstSlot, lastSlot, color];
}

/// A coloured tick in the scrubber's context column at [slot].
class ScrubberTick extends Equatable {
  const ScrubberTick({required this.slot, required this.color});

  final int slot;
  final Color color;

  @override
  List<Object?> get props => [slot, color];
}

/// [count] items over the track slots [firstSlot] to [lastSlot].
class ScrubberDensityBin extends Equatable {
  const ScrubberDensityBin({
    required this.firstSlot,
    required this.lastSlot,
    required this.count,
  });

  final int firstSlot;
  final int lastSlot;
  final int count;

  @override
  List<Object?> get props => [firstSlot, lastSlot, count];
}
