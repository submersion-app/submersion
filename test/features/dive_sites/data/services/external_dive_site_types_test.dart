import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';

/// Bundled site database `features` as site types (issue #1765).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ExternalDiveSite withFeatures(List<String> features) => ExternalDiveSite(
    externalId: 'x',
    name: 'x',
    features: features,
    source: 'test',
  );

  test('maps bundled features to built-in site types, exact matches only', () {
    expect(
      withFeatures(['wreck', 'sharks', 'wall', 'speleology']).siteTypeIds,
      ['wreck', 'wall', 'cave'],
    );
    expect(withFeatures(['reef', 'lake', 'cavern']).siteTypeIds, [
      'reef',
      'lake',
      'cavern',
    ]);
    expect(withFeatures(['drift', 'training', 'sea']).siteTypeIds, isEmpty);
  });

  test('two features naming the same type yield it once', () {
    expect(withFeatures(['cave', 'speleology']).siteTypeIds, ['cave']);
  });

  test('the bundled asset loader reads features', () async {
    final sites = await DiveSiteApiService().allSitesWithCoordinates();
    expect(sites.any((s) => s.features.contains('wreck')), isTrue);
    expect(sites.any((s) => s.siteTypeIds.contains('wreck')), isTrue);
  });
}
