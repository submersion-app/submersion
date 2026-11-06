import 'dart:typed_data';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_csv_parser.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';

/// A parsed route, ready for the review page: everything it needs to show
/// before anything is written (spec 2026-09-10-underwater-nav-track-design.md,
/// "Import and format detection", "Review page").
class NavTrackImportPreview {
  final ParsedNavTrack parsed;
  final NavTrackStats stats;
  final NavTrackSegmentation segmentation;

  /// Dives whose time window overlaps the route's recording window
  /// (`NavTrackMatcher.candidatesFor`). Empty means no match; more than one
  /// means the diver must choose; exactly one is the pre-selected proposal.
  final List<Dive> candidateDives;

  /// The dives nearest the recording's start by time
  /// (`NavTrackMatcher.nearestByStart`), offered for a manual link only
  /// when [candidateDives] is empty: a recording device's clock set too far
  /// off for any dive to overlap (issue #2691). Empty whenever
  /// [candidateDives] is not, and never pre-selected.
  final List<Dive> nearbyDives;

  /// An existing route already stored from the same file (same [sourceRef],
  /// recorded within [NavTrackImportService.duplicateWindow] of this one),
  /// or null when this looks like a fresh import. The review page asks
  /// whether to update that route or import a new one (issue #4231).
  final String? duplicateOfRouteId;

  /// True when [duplicateOfRouteId]'s recording overlaps this one in time:
  /// the same recording read again, which the review page proposes to
  /// update. A file of the same name recorded at another time within the
  /// window may be a different dive (a console that started its numbering
  /// over), so the page leaves that choice to the diver.
  final bool duplicateIsSameRecording;

  final String sourceRef;

  /// The diver this preview was prepared for: whose dives it proposes and
  /// whose routes it checked for a duplicate. Saving passes it back to
  /// [NavTrackImportService.commit], so switching profile while the review
  /// is open cannot apply this preview to another diver's data. Null with no
  /// diver profile (every dive and route was considered).
  final String? diverId;

  const NavTrackImportPreview({
    required this.parsed,
    required this.stats,
    required this.segmentation,
    required this.candidateDives,
    required this.nearbyDives,
    required this.duplicateOfRouteId,
    this.duplicateIsSameRecording = false,
    required this.sourceRef,
    this.diverId,
  });

  /// True when the recording shows no movement at all: distance and speed
  /// stay at zero throughout (the design spec's "no movement recorded"
  /// warning; the ENC3 bench-test fixture is exactly this shape).
  bool get hasNoMovement =>
      stats.totalDistance <= 0 &&
      (stats.maxSpeed == null || stats.maxSpeed == 0);
}

/// Prepares and commits a Seacraft ENC route import in two steps, so the
/// review page can let the diver adjust the dive link, the site and the
/// clock offset before anything is persisted.
class NavTrackImportService {
  final NavTrackRepository _routeRepository;
  final DiveRepository _diveRepository;
  final Future<String?> Function() _currentDiverId;

  /// [currentDiverId] resolves the active diver, whose dives the review
  /// proposes and who owns the new route. Omitted (or resolving to null),
  /// every dive is considered and the route is ownerless.
  NavTrackImportService({
    NavTrackRepository? routeRepository,
    DiveRepository? diveRepository,
    Future<String?> Function()? currentDiverId,
  }) : _routeRepository = routeRepository ?? NavTrackRepository(),
       _diveRepository = diveRepository ?? DiveRepository(),
       _currentDiverId = currentDiverId ?? _noDiver;

  static Future<String?> _noDiver() async => null;

  /// Parses [bytes] as a Seacraft ENC CSV. Throws [NavTrackParseException]
  /// (with its [NavTrackParseReason]) on anything the diver needs to act on;
  /// callers surface that through `navTrackParseErrorText`, never a raw
  /// message. Writes nothing.
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final parsed = parseSeacraftEncCsv(bytes);
    final stats = NavTrackStats.of(parsed.points);
    final segmentation = NavTrackSegmenter.classify(parsed.points);

    final routeStartSeconds = parsed.points.first.timestamp;
    final routeEndSeconds = parsed.points.last.timestamp;

    // Resolved once: the proposal and the duplicate check must agree on
    // whose dives and routes they read.
    final diverId = await _currentDiverId();
    final dives = await _diveRepository.getAllDives(diverId: diverId);
    final candidates = NavTrackMatcher.candidatesFor(
      routeStartSeconds: routeStartSeconds,
      routeEndSeconds: routeEndSeconds,
      dives: dives,
    );
    final nearby = candidates.isEmpty
        ? NavTrackMatcher.nearestByStart(
            routeStartSeconds: routeStartSeconds,
            dives: dives,
          )
        : const <Dive>[];

    final sourceRef = fileName ?? 'import.csv';
    final duplicate = await _findDuplicate(
      sourceRef,
      routeStartSeconds,
      routeEndSeconds,
      diverId: diverId,
    );

    return NavTrackImportPreview(
      parsed: parsed,
      stats: stats,
      segmentation: segmentation,
      candidateDives: candidates,
      nearbyDives: nearby,
      duplicateOfRouteId: duplicate?.id,
      duplicateIsSameRecording: duplicate?.sameRecording ?? false,
      sourceRef: sourceRef,
      diverId: diverId,
    );
  }

  /// Writes [parsed] as a new route, optionally pre-linked to [dive] (the
  /// diver's own choice on the review page) and anchored to [site].
  ///
  /// A null [dive] leaves the route unlinked. No match sweep runs here: the
  /// review page already proposes the unique time-window match, so arriving
  /// without a dive means the diver chose "Leave unlinked" (or there was no
  /// single match to propose), and a sweep would only override that choice.
  ///
  /// [diverId] is the preview's own [NavTrackImportPreview.diverId], never
  /// the active diver re-read at save time: [dive] came from that diver's
  /// scope. It owns an unlinked route.
  ///
  /// [sourceFile] is the file [parsed] came from, stored with the route
  /// (issue #4231).
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    required String? diverId,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
    Uint8List? sourceFile,
  }) => _routeRepository.insertImportedRoute(
    points: parsed.points,
    source: NavTrackSource.seacraftEnc,
    sourceRef: sourceRef,
    deviceName: deviceName,
    name: name,
    diveId: dive?.id,
    diverId: diverId,
    siteId: siteId,
    equipmentId: equipmentId,
    sourceFile: sourceFile,
  );

  /// Replaces [routeId]'s data with [parsed], the file [sourceFile] read
  /// again, and keeps every setting on the route (issue #4231): the dive
  /// link, site, name, device, anchor and correction. A non-null
  /// [sourceRef] also records the file's name. Returns false when the route
  /// no longer exists.
  Future<bool> updateFromFile({
    required String routeId,
    required ParsedNavTrack parsed,
    required Uint8List sourceFile,
    String? sourceRef,
  }) => _routeRepository.updateImportedData(
    routeId,
    points: parsed.points,
    sourceFile: sourceFile,
    sourceRef: sourceRef,
  );

  /// Parses [bytes], a file the diver picked to update a stored route from
  /// (issue #4231), so the caller can compare it with that route before
  /// anything is written. Throws [NavTrackParseException] when the file is
  /// not a route this app reads.
  ParsedNavTrack parseFile(Uint8List bytes) => parseSeacraftEncCsv(bytes);

  /// True when [parsed] is [route]'s own recording read again: the two
  /// recording windows overlap in time. A file of the same name recorded at
  /// another time may be a different dive.
  static bool isSameRecording(NavTrack route, ParsedNavTrack parsed) =>
      _overlaps(
        route,
        parsed.points.first.timestamp * 1000,
        parsed.points.last.timestamp * 1000,
      );

  static bool _overlaps(NavTrack route, int startMs, int endMs) =>
      route.startTime <= endMs && route.endTime >= startMs;

  /// How far apart two recordings from a file of the same name may start
  /// and still count as the same recording.
  ///
  /// A console numbers its files and starts over once it runs out (a
  /// Seacraft ENC from `001` to `050`), so a name alone matches different
  /// dives months apart. A week covers a re-import days later, a console
  /// clock set a few hours off and a dive spanning midnight.
  static const Duration duplicateWindow = Duration(days: 7);

  /// An existing route from the same source file recorded within
  /// [duplicateWindow] of this one, or null, preferring one whose recording
  /// overlaps this one ([sameRecording]). A cheap linear scan over every
  /// stored route: import happens rarely enough (one file at a time, by
  /// hand) that this need not be indexed.
  Future<({String id, bool sameRecording})?> _findDuplicate(
    String sourceRef,
    int startSeconds,
    int endSeconds, {
    String? diverId,
  }) async {
    final windowMs = duplicateWindow.inMilliseconds;
    final startMs = startSeconds * 1000;
    final endMs = endSeconds * 1000;
    // Only routes [diverId] can see: updating overwrites the duplicate's
    // data, so another diver's recording of the same file must never be
    // offered.
    final existing = await _routeRepository.getAll(diverId: diverId);
    String? nearId;
    for (final route in existing) {
      // Only an ENC route can be updated from an ENC file: a route of
      // another source with the same file name keeps its own data.
      if (route.source != NavTrackSource.seacraftEnc) continue;
      if (route.sourceRef != sourceRef) continue;
      if (_overlaps(route, startMs, endMs)) {
        return (id: route.id, sameRecording: true);
      }
      // The rule is about when the recordings start, not how close their
      // spans come: a stored recording running for days must not count
      // because its end reaches near this one's start.
      final near = (route.startTime - startMs).abs() <= windowMs;
      if (near) nearId ??= route.id;
    }
    return nearId == null ? null : (id: nearId, sameRecording: false);
  }
}
