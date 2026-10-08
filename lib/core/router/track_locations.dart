/// Where the Tracks area's pages live (spec
/// 2026-10-02-tracks-navigation-consolidation-design.md).
///
/// The router, the nav destination and every feature that links into the
/// area build their paths here, so a hand-written path cannot drift from the
/// route table. Every page is a top-level sibling of [kTracksLocation]; see
/// the router for why.
const kTracksLocation = '/tracks';

/// Full-screen overview map, for phones where the landing page is one
/// column.
const kTracksMapLocation = '$kTracksLocation/map';

/// The landing page with the kind filter set to underwater tracks.
const kUnderwaterTracksLocation = '$kTracksLocation?kind=underwater';

String gpsTrackLocation(String id) => '$kTracksLocation/gps/$id';

String underwaterTrackLocation(String id) => '$kTracksLocation/underwater/$id';

String underwaterTrackAlignLocation(String id) =>
    '${underwaterTrackLocation(id)}/align';

String underwaterTrackSeascapeLocation(String id) =>
    '${underwaterTrackLocation(id)}/3d';
