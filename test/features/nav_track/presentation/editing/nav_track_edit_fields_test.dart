import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The underwater track's values a sitting edits (issue #4527, plan 5).
void main() {
  const oldPin = GeoPoint(28.5, 34.5);
  const newPin = GeoPoint(27.9, 34.3);
  final created = DateTime.utc(2026);

  NavTrack track({GeoPoint? anchor = oldPin}) => NavTrack(
    id: 'r1',
    diveId: 'd1',
    siteId: 's1',
    source: NavTrackSource.seacraftEnc,
    sourceRef: 'r1.csv',
    name: 'Morning',
    deviceName: 'Seacraft',
    equipmentId: 'e1',
    startTime: 1,
    endTime: 2,
    pointCount: 0,
    anchorLatitude: anchor?.latitude,
    anchorLongitude: anchor?.longitude,
    endMode: NavTrackEndMode.sameAsStart,
    trustFraction: 0.3,
    createdAt: created,
    updatedAt: created,
  );

  DiveSite site(String id, GeoPoint? pin) =>
      DiveSite(id: id, name: id, location: pin);

  test('a site pick moves an anchor that followed the old pin', () {
    final session = EditSession(track());

    pickNavTrackSite(session, site('s2', newPin), oldSiteLocation: oldPin);

    expect(session.valueOf(navTrackSiteField), 's2');
    expect(session.valueOf(navTrackAnchorField), newPin);
    expect(session.changedCardIds, {'site', 'correction'});
  });

  test('a site pick leaves a hand-placed anchor', () {
    const handPlaced = GeoPoint(1, 2);
    final session = EditSession(track(anchor: handPlaced));

    pickNavTrackSite(session, site('s2', newPin), oldSiteLocation: oldPin);

    expect(session.valueOf(navTrackAnchorField), handPlaced);
    expect(session.changedCardIds, {'site'});
  });

  test('a site with no pin clears a following anchor', () {
    final session = EditSession(track());

    pickNavTrackSite(session, site('s2', null), oldSiteLocation: oldPin);

    expect(session.valueOf(navTrackAnchorField), isNull);
    expect(session.applyTo(track()).anchor, isNull);
  });

  test('the rule reads the anchor the sitting holds', () {
    final session = EditSession(track())..set(navTrackAnchorField, null);

    pickNavTrackSite(session, site('s2', newPin), oldSiteLocation: oldPin);

    // No anchor in the sitting: it follows the new site's pin.
    expect(session.valueOf(navTrackAnchorField), newPin);
  });

  test('a blank name stores null', () {
    final session = EditSession(track())..set(navTrackNameField, '  ');

    expect(session.applyTo(track()).name, isNull);
  });

  test('the device clears both values together', () {
    final session = EditSession(track())
      ..set(navTrackDeviceField, (equipmentId: null, deviceName: null));

    final applied = session.applyTo(track());
    expect(applied.equipmentId, isNull);
    expect(applied.deviceName, isNull);
    expect(session.changedCardIds, {'device'});
  });

  test('the correction in the sitting combines its two fields', () {
    final session = EditSession(track());
    setNavTrackCorrection(
      session,
      const NavTrackCorrection(anchor: newPin, scaleFactor: 2),
    );

    final correction = navTrackCorrectionIn(session);
    expect(correction.anchor, newPin);
    expect(correction.scaleFactor, 2);
    expect(correction.endMode, NavTrackEndMode.none);
    final applied = session.applyTo(track());
    expect(applied.anchor, newPin);
    expect(applied.trustFraction, 0);
  });

  test('every value no field owns is kept', () {
    final session = EditSession(track())
      ..set(navTrackNameField, null)
      ..set(navTrackDiveField, null)
      ..set(navTrackSiteField, null);

    final applied = session.applyTo(track());
    expect(applied.sourceRef, 'r1.csv');
    expect(applied.startTime, 1);
    expect(applied.endTime, 2);
    expect(applied.endMode, NavTrackEndMode.sameAsStart);
    expect(applied.createdAt, created);
  });

  test(
    'a site pick that moves the anchor says so; the align page clears it',
    () {
      final session = EditSession(track());

      pickNavTrackSite(session, site('s2', newPin), oldSiteLocation: oldPin);
      expect(navTrackAnchorFromSite(session), (anchor: newPin));

      setNavTrackCorrection(session, const NavTrackCorrection(anchor: newPin));
      expect(navTrackAnchorFromSite(session), isNull);
    },
  );

  test('a site pick that leaves the anchor says nothing moved', () {
    final session = EditSession(track(anchor: const GeoPoint(1, 2)));

    pickNavTrackSite(session, site('s2', newPin), oldSiteLocation: oldPin);

    expect(navTrackAnchorFromSite(session), isNull);
  });
}
