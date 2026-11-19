import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_site_anchor_rule.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The underwater track page's values a sitting edits (issue #4527, phase
/// 3, plan 5): its name, dive, site, device and correction. What was
/// recorded, and how the route sits among its dive's others, is not here.

/// A route's device: an equipment item, a name, or both cleared together.
typedef NavTrackDevice = ({String? equipmentId, String? deviceName});

/// Everything in a correction but the anchor: how the route is turned,
/// sized and reconciled with its end. A record, so two compare by value.
typedef NavTrackAlignment = ({
  NavTrackEndMode endMode,
  GeoPoint? endPoint,
  double trustFraction,
  double headingOffsetDeg,
  double scaleFactor,
});

const Object _keep = Object();

T? _or<T>(Object? value, T? kept) =>
    identical(value, _keep) ? kept : value as T?;

/// [t] with the given values, every other one kept. [NavTrack.copyWith]
/// cannot clear a value, so the fields build the route whole.
NavTrack _with(
  NavTrack t, {
  Object? diveId = _keep,
  Object? siteId = _keep,
  Object? name = _keep,
  Object? equipmentId = _keep,
  Object? deviceName = _keep,
  Object? anchor = _keep,
  NavTrackAlignment? alignment,
}) {
  final GeoPoint? newAnchor = _or<GeoPoint>(anchor, t.anchor);
  final a = alignment ?? _alignmentOf(t);
  return NavTrack(
    id: t.id,
    diveId: _or<String>(diveId, t.diveId),
    linkMode: t.linkMode,
    isPrimary: t.isPrimary,
    siteId: _or<String>(siteId, t.siteId),
    source: t.source,
    sourceRef: t.sourceRef,
    deviceName: _or<String>(deviceName, t.deviceName),
    name: _or<String>(name, t.name),
    equipmentId: _or<String>(equipmentId, t.equipmentId),
    startTime: t.startTime,
    endTime: t.endTime,
    tzOffsetMinutes: t.tzOffsetMinutes,
    timeOffsetSeconds: t.timeOffsetSeconds,
    pointCount: t.pointCount,
    totalDistance: t.totalDistance,
    maxDepth: t.maxDepth,
    maxSpeed: t.maxSpeed,
    avgSpeed: t.avgSpeed,
    durationSeconds: t.durationSeconds,
    anchorLatitude: newAnchor?.latitude,
    anchorLongitude: newAnchor?.longitude,
    endMode: a.endMode,
    endLatitude: a.endPoint?.latitude,
    endLongitude: a.endPoint?.longitude,
    trustFraction: a.trustFraction,
    headingOffsetDeg: a.headingOffsetDeg,
    scaleFactor: a.scaleFactor,
    sourceMetadata: t.sourceMetadata,
    points: t.points,
    hasSourceFile: t.hasSourceFile,
    markers: t.markers,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  );
}

NavTrackAlignment _alignmentOf(NavTrack t) => (
  endMode: t.endMode,
  endPoint: t.endPoint,
  trustFraction: t.trustFraction,
  headingOffsetDeg: t.headingOffsetDeg,
  scaleFactor: t.scaleFactor,
);

/// A blank name is stored as none, so the route falls back to its file.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The route's own label, on the header block.
final navTrackNameField = EditField<NavTrack, String?>(
  id: 'name',
  cardId: NavTrackCardId.header.name,
  read: (t) => t.name,
  write: (t, v) => _with(t, name: _orNone(v)),
  equals: (a, b) => _orNone(a) == _orNone(b),
);

/// The dive the route is linked to. Saved through the repository's link,
/// relink and unlink, never as a bare column (see the save service).
final navTrackDiveField = EditField<NavTrack, String?>(
  id: 'dive',
  cardId: NavTrackCardId.dive.name,
  read: (t) => t.diveId,
  write: (t, v) => _with(t, diveId: v),
);

final navTrackSiteField = EditField<NavTrack, String?>(
  id: 'site',
  cardId: NavTrackCardId.site.name,
  read: (t) => t.siteId,
  write: (t, v) => _with(t, siteId: v),
);

/// The device, both values as one change.
final navTrackDeviceField = EditField<NavTrack, NavTrackDevice>(
  id: 'device',
  cardId: NavTrackCardId.device.name,
  read: (t) => (equipmentId: t.equipmentId, deviceName: t.deviceName),
  write: (t, v) =>
      _with(t, equipmentId: v.equipmentId, deviceName: v.deviceName),
);

/// Where the route starts on the map. A field of its own, so a site change
/// that moves only the anchor leaves the rest of a correction alone.
final navTrackAnchorField = EditField<NavTrack, GeoPoint?>(
  id: 'anchor',
  cardId: NavTrackCardId.correction.name,
  read: (t) => t.anchor,
  write: (t, v) => _with(t, anchor: v),
);

/// The rest of the correction, as the align page sets it.
final navTrackAlignmentField = EditField<NavTrack, NavTrackAlignment>(
  id: 'alignment',
  cardId: NavTrackCardId.correction.name,
  read: _alignmentOf,
  write: (t, v) => _with(t, alignment: v),
);

/// The correction [session] holds: its anchor and its alignment together.
NavTrackCorrection navTrackCorrectionIn(EditSession<NavTrack> session) {
  final a = session.valueOf(navTrackAlignmentField);
  return NavTrackCorrection(
    anchor: session.valueOf(navTrackAnchorField),
    endMode: a.endMode,
    endPoint: a.endPoint,
    trustFraction: a.trustFraction,
    headingOffsetDeg: a.headingOffsetDeg,
    scaleFactor: a.scaleFactor,
  );
}

const String _anchorFromSiteKey = 'navTrack.anchorFromSite';

/// The anchor a site pick moved in [session], while it is still the one
/// the pick put there: a Save that cannot set that site (deleted
/// meanwhile) takes this anchor back with it. Null when no pick moved it,
/// or the align page has set the correction since.
({GeoPoint? anchor})? navTrackAnchorFromSite(EditSession<NavTrack> session) =>
    session.recall<({GeoPoint? anchor})>(_anchorFromSiteKey);

/// Puts [correction] in [session], as the align page's Done does. The
/// anchor is then the diver's, whatever site pick moved it before.
void setNavTrackCorrection(
  EditSession<NavTrack> session,
  NavTrackCorrection correction,
) {
  session.remember(_anchorFromSiteKey, null);
  session
    ..set(navTrackAnchorField, correction.anchor)
    ..set(navTrackAlignmentField, (
      endMode: correction.endMode,
      endPoint: correction.endPoint,
      trustFraction: correction.trustFraction,
      headingOffsetDeg: correction.headingOffsetDeg,
      scaleFactor: correction.scaleFactor,
    ));
}

/// Sets [site] as the route's site in [session], and moves the anchor to
/// its pin when the anchor followed the old site's pin
/// ([navTrackAnchorChangeForSite]), judged on the anchor the sitting holds
/// and [oldSiteLocation], the pin of the site the sitting held until now.
void pickNavTrackSite(
  EditSession<NavTrack> session,
  DiveSite site, {
  required GeoPoint? oldSiteLocation,
}) {
  final change = navTrackAnchorChangeForSite(
    session.valueOf(navTrackAnchorField),
    oldSiteLocation,
    site.location,
  );
  session.set(navTrackSiteField, site.id);
  if (change.write) session.set(navTrackAnchorField, change.anchor);
  session.remember(
    _anchorFromSiteKey,
    change.write ? (anchor: change.anchor) : null,
  );
}
