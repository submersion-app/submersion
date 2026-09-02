import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';

void main() {
  final adapter = SiteFieldAdapter.instance;

  SiteWithCount wrap(DiveSite site) =>
      SiteWithDiveCount(site: site, diveCount: 0);

  test('entryType extracts the real entry method column', () {
    // The enum member keeps its historical name so saved table layouts that
    // reference "entryType" keep loading; only what it reads changed.
    const site = DiveSite(id: 's', name: 'S', entryMethod: EntryMethod.boat);
    expect(
      adapter.extractValue(SiteField.entryType, wrap(site)),
      EntryMethod.boat.displayName,
    );
  });

  test('exitMethod extracts the real exit method column', () {
    const site = DiveSite(id: 's', name: 'S', exitMethod: EntryMethod.ladder);
    expect(
      adapter.extractValue(SiteField.exitMethod, wrap(site)),
      EntryMethod.ladder.displayName,
    );
  });

  test('both are null when unset', () {
    const site = DiveSite(id: 's', name: 'S');
    expect(adapter.extractValue(SiteField.entryType, wrap(site)), isNull);
    expect(adapter.extractValue(SiteField.exitMethod, wrap(site)), isNull);
  });

  test('waterType still extracts the real column', () {
    const site = DiveSite(id: 's', name: 'S', waterType: WaterType.salt);
    expect(
      adapter.extractValue(SiteField.waterType, wrap(site)),
      WaterType.salt.displayName,
    );
  });
}
