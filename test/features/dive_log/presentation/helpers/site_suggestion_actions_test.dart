import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/helpers/site_suggestion_actions.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../support/fake_matching_service.dart';
import 'site_suggestion_actions_test.mocks.dart';

@GenerateMocks([DiveRepository])
void main() {
  late FakeMatchingService service;
  late MockDiveRepository dives;

  setUp(() {
    service = FakeMatchingService();
    dives = MockDiveRepository();
    when(dives.setSiteSuggestionDismissed(any, any)).thenAnswer((_) async {});
  });

  test('assign applies the chosen candidate through the service', () async {
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service, recommended: 's1'),
      diveRepository: dives,
    );
    await actions.assign('s1');
    expect(service.applied.single.diveId, 'd1');
    expect(service.applied.single.candidateId, 's1');
  });

  test('addLocation applies the current-site candidate', () async {
    const bare = DiveSite(id: 'bare', name: 'Typed Twice');
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service, site: bare),
      diveRepository: dives,
    );
    await actions.addLocation();
    expect(
      service.applied.single.candidateId,
      SiteMatchingService.currentSiteCandidateId('bare'),
    );
  });

  test('create routes through createAndLink', () async {
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service, status: ProposalStatus.none),
      diveRepository: dives,
    );
    final created = await actions.create(
      const DiveSite(id: '', name: 'Wall', location: GeoPoint(20.5, -87.25)),
    );
    expect(created.id, 'created');
    expect(service.created.single.name, 'Wall');
  });

  test('dismiss writes the synced flag', () async {
    final actions = SiteSuggestionActions(
      diveId: 'd1',
      suggestion: suggestionFor(service),
      diveRepository: dives,
    );
    await actions.dismiss();
    verify(dives.setSiteSuggestionDismissed('d1', true)).called(1);
  });
}
