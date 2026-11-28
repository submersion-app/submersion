import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/utils/water_type_autofill.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  DiveSite site({WaterType? waterType}) =>
      DiveSite(id: 's', name: 'S', waterType: waterType);

  // Issue #5040: the site's water type is read through, never copied, so a
  // site that has one leaves the dive's own empty.
  group('waterTypeAfterSiteAssign', () {
    test('leaves the dive empty when the site has a water type', () {
      expect(
        waterTypeAfterSiteAssign(null, site(waterType: WaterType.salt)),
        isNull,
      );
    });

    test('drops the current value when the new site has a water type', () {
      expect(
        waterTypeAfterSiteAssign(
          WaterType.fresh,
          site(waterType: WaterType.salt),
        ),
        isNull,
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
