import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/domain/value_objects/import_preview.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';

/// The three ways resolved network media gets its link: forced onto the
/// picker's target, decided in the review, or matched unattended.

final _log = LoggerService.forClass(NetworkInsertRequest);

NetworkInsertRequest _request(
  ResolvedNetworkMedia media,
  MediaAttachTarget target,
) {
  return switch (target) {
    DiveAttachTarget(:final diveId) => NetworkInsertRequest(
      media: media,
      diveId: diveId,
    ),
    SiteAttachTarget(:final siteId) => NetworkInsertRequest(
      media: media,
      siteId: siteId,
    ),
  };
}

/// Every item attaches to [target]: the picker was opened from a dive or a
/// site, and that is what the user is adding to.
List<NetworkInsertRequest> requestsForTarget(
  List<ResolvedNetworkMedia> media,
  MediaAttachTarget target,
) {
  return [for (final m in media) _request(m, target)];
}

/// Review rows for [media], keyed by the URI string.
List<ImportCandidate> candidatesFor(
  List<ResolvedNetworkMedia> media, {
  String Function(ResolvedNetworkMedia)? title,
}) {
  return [
    for (final m in media)
      ImportCandidate(
        key: m.uri.toString(),
        title:
            title?.call(m) ??
            (m.entry?.caption ??
                m.uri.pathSegments.lastOrNull ??
                m.uri.toString()),
        takenAt: m.takenAt,
        error: m.failure,
        // Set even for a failed probe: the art and the metadata resolve
        // independently, so a row that could not be examined may still
        // paint.
        preview: UrlImportPreview(m.uri.toString()),
      ),
  ];
}

/// Requests for the items the review decided on, in [media] order.
List<NetworkInsertRequest> requestsFromReview(
  List<ResolvedNetworkMedia> media,
  Map<String, MediaAttachTarget> targets,
) {
  return [
    for (final m in media)
      if (targets[m.uri.toString()] case final target?) _request(m, target),
  ];
}

/// Unattended path (subscription polling): only a confident timestamp
/// match earns a row. Everything else is skipped, not inserted, and will
/// be examined again the next time it shows up as new.
Future<({List<NetworkInsertRequest> requests, int skipped})>
requestsForConfidentMatches(
  List<ResolvedNetworkMedia> media,
  DiveLinkMatcher matcher, {
  String? diverId,
}) async {
  final requests = <NetworkInsertRequest>[];
  var skipped = 0;
  for (final m in media) {
    final takenAt = m.takenAt;
    if (m.failed || takenAt == null) {
      skipped++;
      continue;
    }
    // One entry's lookup failing must not take the whole poll down with
    // it; the entry stays absent and is examined again next time.
    final TimestampMatch match;
    try {
      match = await matcher.match(takenAt, diverId: diverId);
    } catch (e, stackTrace) {
      _log.warning(
        'Skipping ${m.uri}: dive lookup failed',
        error: e,
        stackTrace: stackTrace,
      );
      skipped++;
      continue;
    }
    if (match.kind != TimestampMatchKind.confident) {
      skipped++;
      continue;
    }
    requests.add(NetworkInsertRequest(media: m, diveId: match.diveId));
  }
  return (requests: requests, skipped: skipped);
}
