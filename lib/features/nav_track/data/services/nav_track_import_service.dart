import 'dart:typed_data';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
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

  /// An existing route already stored from the same file (same [sourceRef],
  /// overlapping recording window), or null when this looks like a fresh
  /// import. The review page offers "replace" rather than importing a twin.
  final String? duplicateOfRouteId;

  final String sourceRef;

  const NavTrackImportPreview({
    required this.parsed,
    required this.stats,
    required this.segmentation,
    required this.candidateDives,
    required this.duplicateOfRouteId,
    required this.sourceRef,
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
  final NavTrackMatchService _matchService;

  NavTrackImportService({
    NavTrackRepository? routeRepository,
    DiveRepository? diveRepository,
    NavTrackMatchService? matchService,
  }) : _routeRepository = routeRepository ?? NavTrackRepository(),
       _diveRepository = diveRepository ?? DiveRepository(),
       _matchService =
           matchService ??
           NavTrackMatchService(
             routeRepository: routeRepository ?? NavTrackRepository(),
             diveRepository: diveRepository ?? DiveRepository(),
           );

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

    final dives = await _diveRepository.getAllDives();
    final candidates = NavTrackMatcher.candidatesFor(
      routeStartSeconds: routeStartSeconds,
      routeEndSeconds: routeEndSeconds,
      dives: dives,
    );

    final sourceRef = fileName ?? 'import.csv';
    final duplicateOfRouteId = await _findDuplicate(
      sourceRef,
      routeStartSeconds,
      routeEndSeconds,
    );

    return NavTrackImportPreview(
      parsed: parsed,
      stats: stats,
      segmentation: segmentation,
      candidateDives: candidates,
      duplicateOfRouteId: duplicateOfRouteId,
      sourceRef: sourceRef,
    );
  }

  /// Writes [parsed] as a new route, optionally pre-linked to [dive] (the
  /// diver's own choice on the review page) and anchored to [site]. When no
  /// dive was chosen, the match sweep runs immediately afterward, limited to
  /// the new route, so an unambiguous time-window match still links it
  /// automatically rather than waiting for the next general sweep.
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
  }) async {
    final id = await _routeRepository.insertImportedRoute(
      points: parsed.points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: sourceRef,
      deviceName: deviceName,
      name: name,
      diveId: dive?.id,
      siteId: siteId,
      equipmentId: equipmentId,
    );
    if (dive == null) {
      await _matchService.sweep(limitToRouteIds: [id]);
    }
    return id;
  }

  /// An existing route from the same source file whose recording window
  /// overlaps this one, or null. A cheap linear scan over every stored
  /// route: import happens rarely enough (one file at a time, by hand) that
  /// this need not be indexed.
  Future<String?> _findDuplicate(
    String sourceRef,
    int startSeconds,
    int endSeconds,
  ) async {
    final startMs = startSeconds * 1000;
    final endMs = endSeconds * 1000;
    final existing = await _routeRepository.getAll();
    for (final route in existing) {
      if (route.sourceRef != sourceRef) continue;
      final overlaps = route.startTime <= endMs && route.endTime >= startMs;
      if (overlaps) return route.id;
    }
    return null;
  }
}
