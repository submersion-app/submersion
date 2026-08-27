import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'allSitesWithCoordinates returns only sites that have coordinates',
    () async {
      final service = DiveSiteApiService();
      final sites = await service.allSitesWithCoordinates();

      expect(sites, isNotEmpty);
      expect(sites.every((s) => s.hasCoordinates), isTrue);
    },
  );
}
