import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/utils/water_type_autofill.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  DiveSite site({WaterType? waterType}) =>
      DiveSite(id: 's', name: 'S', waterType: waterType);

  group('waterTypeAfterSiteAssign', () {
    test('snaps to the site water type when the site has one', () {
      expect(
        waterTypeAfterSiteAssign(null, site(waterType: WaterType.salt)),
        WaterType.salt,
      );
    });

    test('overwrites the current value when the new site has a water type', () {
      expect(
        waterTypeAfterSiteAssign(
          WaterType.fresh,
          site(waterType: WaterType.salt),
        ),
        WaterType.salt,
      );
    });

    test('keeps the current value when the site has no water type', () {
      expect(
        waterTypeAfterSiteAssign(WaterType.fresh, site()),
        WaterType.fresh,
      );
    });

    test('keeps the current value when the site is cleared (null)', () {
      expect(
        waterTypeAfterSiteAssign(WaterType.brackish, null),
        WaterType.brackish,
      );
    });
  });
}
