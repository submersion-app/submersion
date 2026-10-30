import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// What identifies a dive or site in a change list (#3513): a dive by its
/// number, site and date as on the dive list; a site by its name and place.
class RuleTargetInfo {
  const RuleTargetInfo({
    required this.name,
    this.number,
    this.date,
    this.place,
  });

  /// The dive's site name, or the site's name; null for a dive with none.
  final String? name;
  final int? number;

  /// The dive's wall clock, flagged UTC.
  final DateTime? date;

  /// The site's place, as the site list shows it.
  final String? place;
}

/// Labels through the repositories' own readers: a dive's summary as the
/// dive list reads it, a site's place as the site list words it.
class RuleTargetLabels {
  RuleTargetLabels({DiveRepository? dives, SiteRepository? sites})
    : _dives = dives ?? DiveRepository(),
      _sites = sites ?? SiteRepository();

  final DiveRepository _dives;
  final SiteRepository _sites;

  /// Info for each of [ids] that still exists.
  Future<Map<String, RuleTargetInfo>> infoFor(
    RuleSubject subject,
    Iterable<String> ids,
  ) async {
    final out = <String, RuleTargetInfo>{};
    for (final chunk in ruleIdChunks(ids.toSet().toList())) {
      if (subject == RuleSubject.dives) {
        for (final d in await _dives.getSummariesByIds(chunk)) {
          out[d.id] = RuleTargetInfo(
            name: d.siteName,
            number: d.diveNumber,
            date: d.dateTime,
          );
        }
      } else {
        for (final s in await _sites.getSitesByIds(chunk)) {
          final place = s.locationString;
          out[s.id] = RuleTargetInfo(
            name: s.name,
            place: place.isEmpty ? null : place,
          );
        }
      }
    }
    return out;
  }
}
