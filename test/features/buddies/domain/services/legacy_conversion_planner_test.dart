import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

final _epoch = DateTime.utc(2026);

final _matcher = BuddyNameMatcher([
  MatchCandidate(
    id: 'jim',
    name: 'Jim Dunfield',
    diverId: 'me',
    createdAt: _epoch,
  ),
  MatchCandidate(id: 'leo', name: 'Leo Cox', diverId: 'me', createdAt: _epoch),
], diverId: 'me');

const _jim = ExistingBuddyTarget(buddyId: 'jim', name: 'Jim Dunfield');

void main() {
  group('planLegacyConversion', () {
    test('links known names and creates the rest', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Jim Dunfield, Ann',
        matcher: _matcher,
      );
      expect(plan.diveId, 'd1');
      expect(plan.buddyText, 'Jim Dunfield, Ann');
      expect(plan.links, const [
        PlannedLink(target: _jim, roleId: DiveRole.buddyId),
        PlannedLink(target: NewBuddyTarget('Ann'), roleId: DiveRole.buddyId),
      ]);
    });

    test('carries a prefix suggestion on a new name', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Leo',
        matcher: _matcher,
      );
      final link = plan.links.single;
      expect(link.target, const NewBuddyTarget('Leo'));
      expect(link.suggestion?.id, 'leo');
    });

    test('dive-master text links with the Dive Master role', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        diveMasterText: 'Ana',
        matcher: _matcher,
      );
      expect(plan.links.single.roleId, DiveRole.diveMasterId);
    });

    test('a name in both texts keeps one link with the Dive Master role', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Jim Dunfield, Ann',
        diveMasterText: 'jim dunfield',
        matcher: _matcher,
      );
      expect(plan.links, hasLength(2));
      expect(plan.links.first.target, _jim);
      expect(plan.links.first.roleId, DiveRole.diveMasterId);
    });

    test('placeholder-only texts plan nothing', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        buddyText: 'None',
        diveMasterText: 'n/a',
        matcher: _matcher,
      );
      expect(plan.isEmpty, isTrue);
    });
  });

  group('collapseLinks', () {
    test('keeps the first of two links to one buddy', () {
      final links = collapseLinks(const [
        PlannedLink(target: _jim, roleId: DiveRole.buddyId),
        PlannedLink(target: _jim, roleId: DiveRole.instructorId),
      ]);
      expect(links, const [
        PlannedLink(target: _jim, roleId: DiveRole.buddyId),
      ]);
    });

    test('lets a Dive Master duplicate upgrade the kept role', () {
      final links = collapseLinks(const [
        PlannedLink(target: _jim, roleId: DiveRole.buddyId),
        PlannedLink(target: _jim, roleId: DiveRole.diveMasterId),
      ]);
      expect(links.single.roleId, DiveRole.diveMasterId);
    });
  });

  test('summarizeCandidates counts dives, new names and existing buddies', () {
    CandidateDive dive(String id, String text) => CandidateDive(
      plan: planLegacyConversion(
        diveId: id,
        buddyText: text,
        matcher: _matcher,
      ),
      dateTime: _epoch,
    );
    final summary = summarizeCandidates([
      dive('d1', 'Jim Dunfield, Ann'),
      dive('d2', 'ann, Bob, Jim Dunfield'),
    ]);
    expect(summary.dives, 2);
    expect(summary.newBuddies, 2);
    expect(summary.existingBuddies, 1);
  });
}
