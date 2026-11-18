import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/helpers/site_suggestion_actions.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../support/fake_matching_service.dart';

/// A sitting holds the dive's link until Save (issue #4527): each action
/// makes the site it needs and links nothing.
void main() {
  late FakeMatchingService service;

  setUp(() => service = FakeMatchingService());

  test('resolve asks the service for the site and links nothing', () async {
    service.resolvesTo['s1'] = const DiveSite(id: 's1', name: 'Blue Hole');
    service.createdBy['s1'] = const ['s1'];
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service, recommended: 's1'),
    );

    final resolved = await actions.resolve('s1');

    expect(resolved.site.name, 'Blue Hole');
    expect(resolved.createdSiteIds, ['s1']);
    expect(service.resolved.single.diveId, 'd1');
    expect(service.applied, isEmpty);
  });

  test('createUnlinked makes the site and links nothing', () async {
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service, status: ProposalStatus.none),
    );

    final made = await actions.createUnlinked(
      const DiveSite(id: '', name: 'Wall', location: GeoPoint(20.5, -87.25)),
    );

    expect(made.id, 'made');
    expect(service.created, isEmpty);
  });
}
