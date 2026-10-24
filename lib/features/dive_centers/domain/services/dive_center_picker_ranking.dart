import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// How far from the dive a center may be and still count as nearby in the
/// picker (#3379): a whole island, or a boat ride out, but not the next
/// country.
const double kNearbyDiveCenterRadiusMeters = 50000;

/// What the picker's reference point came from, which names its section.
enum DiveCenterReferenceSource {
  /// The dive's site.
  site,

  /// The dive's own entry or exit GPS.
  dive,

  /// Where the device is now, for a new dive with neither: possibly far from
  /// the dive itself, so the section says so.
  device,
}

/// Where the picker measures "nearby" from.
class DiveCenterPickerReference {
  const DiveCenterPickerReference({
    required this.point,
    this.siteName,
    this.source = DiveCenterReferenceSource.dive,
  });

  final GeoPoint point;

  /// The site's name when [point] is the site's location; null when it came
  /// from the dive's own GPS or the device.
  final String? siteName;

  final DiveCenterReferenceSource source;
}

/// The point to measure from, in order: the site's coordinates, the dive's
/// entry GPS, its exit GPS, then the device location a new dive captures.
/// Null when there is nothing to measure from.
DiveCenterPickerReference? resolveDiveCenterPickerReference({
  DiveSite? site,
  GeoPoint? entryLocation,
  GeoPoint? exitLocation,
  GeoPoint? deviceLocation,
}) {
  final siteLocation = site?.location;
  if (siteLocation != null) {
    final name = site!.name.trim();
    return DiveCenterPickerReference(
      point: siteLocation,
      siteName: name.isEmpty ? null : name,
      source: DiveCenterReferenceSource.site,
    );
  }
  final divePoint = entryLocation ?? exitLocation;
  if (divePoint != null) {
    return DiveCenterPickerReference(point: divePoint);
  }
  return deviceLocation == null
      ? null
      : DiveCenterPickerReference(
          point: deviceLocation,
          source: DiveCenterReferenceSource.device,
        );
}

/// An open center within [kNearbyDiveCenterRadiusMeters] of the dive.
class NearbyDiveCenter {
  const NearbyDiveCenter(this.center, this.distanceMeters);

  final DiveCenter center;
  final double distanceMeters;
}

/// The picker's two sections. Every center is in exactly one of them.
class DiveCenterPickerSections {
  const DiveCenterPickerSections({required this.nearby, required this.others});

  /// Nearest first; ties by name.
  final List<NearbyDiveCenter> nearby;

  /// Open centers in their given order, then closed ones in theirs.
  final List<DiveCenter> others;
}

/// Splits [centers] (alphabetical, as the repository returns them) into the
/// nearby section and the rest. A permanently closed center, or one without
/// coordinates, is never nearby.
DiveCenterPickerSections rankDiveCentersForPicker(
  List<DiveCenter> centers, {
  DiveCenterPickerReference? reference,
}) {
  final nearby = <NearbyDiveCenter>[];
  final open = <DiveCenter>[];
  final closed = <DiveCenter>[];

  for (final center in centers) {
    if (center.isPermanentlyClosed) {
      closed.add(center);
      continue;
    }
    if (reference != null && center.hasCoordinates) {
      final distance = distanceMeters(
        reference.point,
        GeoPoint(center.latitude!, center.longitude!),
      );
      if (distance <= kNearbyDiveCenterRadiusMeters) {
        nearby.add(NearbyDiveCenter(center, distance));
        continue;
      }
    }
    open.add(center);
  }

  final collator = TextCollator();
  nearby.sort((a, b) {
    final byDistance = a.distanceMeters.compareTo(b.distanceMeters);
    return byDistance != 0
        ? byDistance
        : collator.compare(a.center.name, b.center.name);
  });

  return DiveCenterPickerSections(nearby: nearby, others: [...open, ...closed]);
}
