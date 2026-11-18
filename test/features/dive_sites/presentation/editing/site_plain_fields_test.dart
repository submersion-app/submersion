import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// Every plain site value has a sitting field that reads and writes it
/// exactly (issue #4527, phase 2, plan 2).
void main() {
  const full = DiveSite(
    id: 's1',
    name: 'Blue Hole',
    location: GeoPoint(17.3, -87.5),
    minDepth: 5,
    maxDepth: 40,
    difficulty: SiteDifficulty.advanced,
    waterType: WaterType.salt,
    country: 'Belize',
    countryCode: 'BZ',
    region: 'Lighthouse Reef',
    city: 'Belize City',
    island: 'Ambergris',
    bodyOfWater: 'Caribbean Sea',
    rating: 4,
    hazards: 'Current at the arch',
    accessNotes: 'Boat only',
    mooringNumber: 'M12',
    parkingInfo: 'None',
    altitude: 3,
    entryMethods: [EntryMethod.backRoll],
    exitMethods: [EntryMethod.ladder],
  );

  // Each field is checked through a call typed for its own value: a field
  // reached through `EditField<DiveSite, Object?>` cannot have its typed
  // `write` called.
  void roundTrip<V>(EditField<DiveSite, V> field) =>
      expect(field.write(full, field.read(full)), full, reason: field.id);

  void clears<V>(EditField<DiveSite, V?> field) =>
      expect(field.read(field.write(full, null)), isNull, reason: field.id);

  test('every field writes back what it reads', () {
    roundTrip(siteNameField);
    roundTrip(siteWaterTypeField);
    roundTrip(siteLocationField);
    roundTrip(siteCountryField);
    roundTrip(siteCountryCodeField);
    roundTrip(siteRegionField);
    roundTrip(siteCityField);
    roundTrip(siteIslandField);
    roundTrip(siteBodyOfWaterField);
    roundTrip(siteAltitudeField);
    roundTrip(siteMinDepthField);
    roundTrip(siteMaxDepthField);
    roundTrip(siteDifficultyField);
    roundTrip(siteRatingField);
    roundTrip(siteHazardsField);
    roundTrip(siteParkingInfoField);
    roundTrip(siteAccessNotesField);
    roundTrip(siteMooringNumberField);
    roundTrip(siteEntryMethodsField);
    roundTrip(siteExitMethodsField);
  });

  test('a nullable field cleared reads back null', () {
    clears(siteWaterTypeField);
    clears(siteLocationField);
    clears(siteCountryField);
    clears(siteCountryCodeField);
    clears(siteRegionField);
    clears(siteCityField);
    clears(siteIslandField);
    clears(siteBodyOfWaterField);
    clears(siteAltitudeField);
    clears(siteMinDepthField);
    clears(siteMaxDepthField);
    clears(siteDifficultyField);
    clears(siteRatingField);
    clears(siteHazardsField);
    clears(siteParkingInfoField);
    clears(siteAccessNotesField);
    clears(siteMooringNumberField);
  });

  test('clearAltitude clears the altitude', () {
    expect(full.copyWith(clearAltitude: true).altitude, isNull);
  });

  test('entry methods in another order are the same', () {
    expect(
      siteEntryMethodsField.same(
        const [EntryMethod.shore, EntryMethod.backRoll],
        const [EntryMethod.backRoll, EntryMethod.shore],
      ),
      isTrue,
    );
  });

  test("every field's card is a section or the header block", () {
    final cards = {
      for (final id in SiteDetailSectionId.values) id.name,
      siteHeaderCardId,
    };
    for (final field in siteSittingFields) {
      expect(cards, contains(field.cardId), reason: field.id);
    }
  });

  test('hasAccessInfo is any of the access values', () {
    const bare = DiveSite(id: 's1', name: 'Hole');
    expect(bare.hasAccessInfo, isFalse);
    expect(bare.copyWith(parkingInfo: 'Lot').hasAccessInfo, isTrue);
    expect(
      bare.copyWith(exitMethods: const [EntryMethod.ladder]).hasAccessInfo,
      isTrue,
    );
  });
}
