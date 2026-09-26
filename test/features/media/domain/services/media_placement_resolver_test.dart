import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/services/media_placement_resolver.dart';

void main() {
  test('the own fix wins over every other source', () {
    final r = resolveMediaPlacement(
      ownLatitude: 1,
      ownLongitude: 2,
      diveEntryLatitude: 3,
      diveEntryLongitude: 4,
      diveSiteLatitude: 5,
      diveSiteLongitude: 6,
      attachedSiteLatitude: 7,
      attachedSiteLongitude: 8,
    )!;
    expect(r.point, const LatLng(1, 2));
    expect(r.placement, MediaPlacement.ownGps);
  });

  test('a (0,0) own fix falls through to the dive entry fix', () {
    final r = resolveMediaPlacement(
      ownLatitude: 0,
      ownLongitude: 0,
      diveEntryLatitude: 3,
      diveEntryLongitude: 4,
    )!;
    expect(r.point, const LatLng(3, 4));
    expect(r.placement, MediaPlacement.diveEntry);
  });

  test('an implausible dive entry fix falls through to the dive site', () {
    final r = resolveMediaPlacement(
      diveEntryLatitude: 0,
      diveEntryLongitude: 0,
      diveSiteLatitude: 5,
      diveSiteLongitude: 6,
    )!;
    expect(r.point, const LatLng(5, 6));
    expect(r.placement, MediaPlacement.diveSite);
  });

  test('with no dive context the attached site places the item', () {
    final r = resolveMediaPlacement(
      attachedSiteLatitude: 7,
      attachedSiteLongitude: 8,
    )!;
    expect(r.point, const LatLng(7, 8));
    expect(r.placement, MediaPlacement.attachedSite);
  });

  test('nothing usable resolves to null', () {
    expect(resolveMediaPlacement(), isNull);
  });

  test('half a coordinate pair is not a position', () {
    expect(resolveMediaPlacement(ownLatitude: 1), isNull);
    expect(resolveMediaPlacement(diveSiteLongitude: 6), isNull);
  });

  test('an out-of-range site coordinate is skipped, not asserted on', () {
    final r = resolveMediaPlacement(
      diveSiteLatitude: 5,
      diveSiteLongitude: 190,
      attachedSiteLatitude: 7,
      attachedSiteLongitude: 8,
    )!;
    expect(r.placement, MediaPlacement.attachedSite);
  });

  test('a site at exactly (0,0) is trusted as stored', () {
    // Sites are typed by hand, so (0,0) is a real (if unlikely) position,
    // unlike a camera that wrote (0,0) for "no fix".
    final r = resolveMediaPlacement(diveSiteLatitude: 0, diveSiteLongitude: 0)!;
    expect(r.placement, MediaPlacement.diveSite);
  });
}
