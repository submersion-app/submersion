import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Counts shown in the bulk page's header.
typedef LinkSummary = ({int dives, int newBuddies, int existingBuddies});

/// The link one legacy [name] becomes: an existing buddy on an exact match,
/// otherwise a new one carrying any prefix suggestion.
PlannedLink planLink(String name, String roleId, BuddyNameMatcher matcher) =>
    switch (matcher.match(name)) {
      ExactMatch(:final candidate, :final tieCount) => PlannedLink(
        target: ExistingBuddyTarget(
          buddyId: candidate.id,
          name: candidate.name,
        ),
        roleId: roleId,
        tieCount: tieCount,
      ),
      NoMatch(:final suggestion) => PlannedLink(
        target: NewBuddyTarget(name.trim()),
        roleId: roleId,
        suggestion: suggestion,
      ),
    };

/// One link per person. The first occurrence keeps its position and role,
/// except that a Dive Master duplicate upgrades it: a name in both the buddy
/// and the dive-master text is the dive's dive master.
List<PlannedLink> collapseLinks(Iterable<PlannedLink> links) {
  final result = <PlannedLink>[];
  final indexByIdentity = <String, int>{};
  for (final link in links) {
    final at = indexByIdentity[link.identity];
    if (at == null) {
      indexByIdentity[link.identity] = result.length;
      result.add(link);
    } else if (link.roleId == DiveRole.diveMasterId) {
      result[at] = result[at].copyWith(roleId: DiveRole.diveMasterId);
    }
  }
  return List.unmodifiable(result);
}

/// The plan for one dive's legacy `buddy` (Buddy role) and `dive_master`
/// (Dive Master role) texts (#1831).
ConversionPlan planLegacyConversion({
  required String diveId,
  String? buddyText,
  String? diveMasterText,
  required BuddyNameMatcher matcher,
}) => ConversionPlan(
  diveId: diveId,
  buddyText: buddyText,
  diveMasterText: diveMasterText,
  links: collapseLinks([
    for (final name in LegacyNameParser.parse(buddyText))
      planLink(name, DiveRole.buddyId, matcher),
    for (final name in LegacyNameParser.parse(diveMasterText))
      planLink(name, DiveRole.diveMasterId, matcher),
  ]),
);

/// Dives, distinct new names, and distinct existing buddies across [dives].
LinkSummary summarizeCandidates(Iterable<CandidateDive> dives) {
  var count = 0;
  final newKeys = <String>{};
  final existingIds = <String>{};
  for (final dive in dives) {
    count++;
    for (final link in dive.plan.links) {
      switch (link.target) {
        case NewBuddyTarget(:final name):
          newKeys.add(legacyNameKey(name));
        case ExistingBuddyTarget(:final buddyId):
          existingIds.add(buddyId);
      }
    }
  }
  return (
    dives: count,
    newBuddies: newKeys.length,
    existingBuddies: existingIds.length,
  );
}
