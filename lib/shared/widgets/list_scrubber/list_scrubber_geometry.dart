import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

/// Where [pixels] falls among the loaded slots, between slots as a fraction,
/// so the thumb can follow every pixel of scrolling.
double slotPositionForScroll({
  required double pixels,
  required double maxScrollExtent,
  required int loadedSlotCount,
}) {
  if (loadedSlotCount <= 1 || maxScrollExtent <= 0) return 0;
  final share = (pixels / maxScrollExtent).clamp(0.0, 1.0);
  return share * (loadedSlotCount - 1);
}

/// The scroll offset showing [slot], which may fall between two slots.
double scrollForSlot({
  required num slot,
  required double maxScrollExtent,
  required int loadedSlotCount,
}) {
  if (loadedSlotCount <= 1) return 0;
  final share = (slot / (loadedSlotCount - 1)).clamp(0.0, 1.0);
  return share * maxScrollExtent;
}

/// Where [dy] falls among all slots, between slots as a fraction, so a drag
/// can scroll the list by the pixel.
double slotPositionForTrack({
  required double dy,
  required double trackExtent,
  required int slotCount,
}) {
  if (slotCount <= 1 || trackExtent <= 0) return 0;
  final share = (dy / trackExtent).clamp(0.0, 1.0);
  return share * (slotCount - 1);
}

/// The track position of [slot], which may fall between two slots.
double trackForSlot({
  required num slot,
  required double trackExtent,
  required int slotCount,
}) {
  if (slotCount <= 1) return 0;
  return (slot / (slotCount - 1)).clamp(0.0, 1.0) * trackExtent;
}

/// The loaded rows' height, scaled up to every slot, is over three viewports.
bool scrubberWanted({
  required int slotCount,
  required int loadedSlotCount,
  required double maxScrollExtent,
  required double viewportDimension,
}) {
  if (loadedSlotCount <= 0 || viewportDimension <= 0) return false;
  final loadedExtent = maxScrollExtent + viewportDimension;
  return loadedExtent * slotCount / loadedSlotCount > 3 * viewportDimension;
}

List<ScrubberMarker> thinMarkers(
  List<ScrubberMarker> markers, {
  required int slotCount,
  required double trackExtent,
  required double minSpacing,
}) {
  final kept = <ScrubberMarker>[];
  double? last;
  for (final marker in markers) {
    final y = trackForSlot(
      slot: marker.slot,
      trackExtent: trackExtent,
      slotCount: slotCount,
    );
    if (last != null && y - last < minSpacing) continue;
    kept.add(marker);
    last = y;
  }
  return kept;
}
