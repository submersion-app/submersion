import 'dart:math' as math;

import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/data/repositories/emergency_chamber_repository.dart';
import 'package:submersion/features/safety/data/services/emergency_data_service.dart';
import 'package:submersion/features/safety/domain/entities/chamber_listing.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final emergencyChamberRepositoryProvider = Provider<EmergencyChamberRepository>(
  (ref) {
    return EmergencyChamberRepository();
  },
);

/// ISO country code driving hotline/EMS/chamber selection: the manual
/// settings override wins, else the most recent dive's site country.
/// Null means "unknown" (worldwide hotline + default EMS number).
final emergencyRegionProvider = FutureProvider<String?>((ref) async {
  final override = _manualRegion(
    ref.watch(settingsProvider.select((s) => s.emergencyRegion)),
  );
  if (override != null) return override;

  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  // Scope to the effective diver so the region isn't derived from another
  // profile's most recent dive in a multi-diver database.
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final summaries = await repository.getDiveSummaries(
    limit: 1,
    diverId: diverId,
  );
  if (summaries.isEmpty) return null;
  // The same recognizer that puts a flag beside the site (issue #4426), so
  // the card and the flag always agree about the country.
  return countryCodeFor(summaries.first.siteCountry);
});

/// The diver's manual region override as an upper-case ISO code, or null
/// when none is set. Chamber countries and the dataset keys are upper-case,
/// so the override is normalized to match same-country comparisons.
String? _manualRegion(String? override) {
  final code = override?.trim().toUpperCase();
  return code == null || code.isEmpty ? null : code;
}

/// How many chambers the emergency card shows before deferring to the full
/// directory. The card is read under stress; it is not a browsing surface.
const chamberCardLimit = 5;

/// Beyond this, a chamber is not meaningfully "near" and the card says so
/// instead of listing a facility on another continent. The full directory
/// still lists it.
const chamberNearbyRadiusMeters = 500000.0;

/// Ordering band. Lower sorts first.
///
/// Distance alone would rank an elective wound-care clinic 5 km away above an
/// on-call dive chamber 80 km away, which is the whole hazard of listing
/// elective facilities. Banding defuses it. A chamber the diver added
/// themselves always leads: they added it on purpose.
int _orderingBand(EmergencyChamber chamber) {
  if (!chamber.isBuiltIn) return 0;
  return switch (chamber.capability) {
    ChamberCapability.divingEmergency => 1,
    ChamberCapability.hyperbaricUnit => 2,
    ChamberCapability.unknown => 3,
    ChamberCapability.elective => 4,
  };
}

/// Every chamber the diver can see, ordered by band then distance. Backs both
/// the emergency card (which takes the head of this list) and the directory
/// page (which shows all of it).
final chamberListingsProvider = FutureProvider<List<ChamberListing>>((
  ref,
) async {
  final bundled = await EmergencyDataService.loadBundledChambers();
  final countryCode = await ref.watch(emergencyRegionProvider.future);
  final diver = await ref.watch(currentDiverProvider.future);
  final hidden = ref.watch(settingsProvider.select((s) => s.hiddenChamberIds));

  final chamberRepo = ref.watch(emergencyChamberRepositoryProvider);
  ref.invalidateSelfWhen(chamberRepo.watchChanges());
  final userChambers = await chamberRepo.getUserChambers(diverId: diver?.id);

  // Re-run when dives change so the distance anchor stays fresh even when a
  // manual region override makes emergencyRegionProvider return early and skip
  // its own subscription.
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  // Scope the GPS anchor to the active diver's most recent dive, not another
  // profile's.
  final summaries = await repository.getDiveSummaries(
    limit: 1,
    diverId: diver?.id,
  );
  final lat = summaries.isNotEmpty ? summaries.first.siteLatitude : null;
  final lon = summaries.isNotEmpty ? summaries.first.siteLongitude : null;

  final chambers = [
    ...userChambers,
    ...bundled.where((c) => !hidden.contains(c.id)),
  ];

  final listings = [
    for (final chamber in chambers)
      ChamberListing(
        chamber: chamber,
        distanceMeters:
            (lat != null &&
                lon != null &&
                chamber.latitude != null &&
                chamber.longitude != null)
            ? _distanceKm(lat, lon, chamber.latitude, chamber.longitude) * 1000
            : null,
      ),
  ];

  listings.sort((a, b) {
    final band = _orderingBand(a.chamber).compareTo(_orderingBand(b.chamber));
    if (band != 0) return band;
    // Chambers with no distance (no GPS anchor, or no coordinates) sort last
    // within their band rather than jumping to the front on a null compare.
    final da = a.distanceMeters ?? double.maxFinite;
    final db = b.distanceMeters ?? double.maxFinite;
    final byDistance = da.compareTo(db);
    if (byDistance != 0) return byDistance;
    // With no GPS anchor every distance is null and the comparison above is a
    // tie, which is where same-country chambers earn their place at the top.
    final byCountry = _countryRank(
      a.chamber,
      countryCode,
    ).compareTo(_countryRank(b.chamber, countryCode));
    if (byCountry != 0) return byCountry;
    // List.sort is not stable, so break remaining ties deterministically or
    // the widget tests flake on reordering.
    return a.chamber.name.compareTo(b.chamber.name);
  });

  return listings;
});

int _countryRank(EmergencyChamber chamber, String? countryCode) {
  if (countryCode == null) return 0;
  return chamber.country == countryCode ? 0 : 1;
}

/// Picks what the card shows.
///
/// A chamber the diver added themselves always qualifies. A bundled chamber
/// qualifies when it is within [chamberNearbyRadiusMeters], or, when the
/// diver's position is unknown, when it is in the resolved country.
List<ChamberListing> _selectNearby(
  List<ChamberListing> listings,
  String? countryCode,
) {
  final picked = <ChamberListing>[];
  for (final listing in listings) {
    if (picked.length >= chamberCardLimit) break;

    if (!listing.chamber.isBuiltIn) {
      picked.add(listing);
      continue;
    }

    final distance = listing.distanceMeters;
    if (distance != null) {
      if (distance.isFinite && distance <= chamberNearbyRadiusMeters) {
        picked.add(listing);
      }
      continue;
    }

    if (countryCode != null && listing.chamber.country == countryCode) {
      picked.add(listing);
    }
  }
  return picked;
}

/// Everything the offline emergency card renders, assembled from local data
/// only (bundled assets, DB, settings). No network, no location permission.
class EmergencyCardData {
  final String? countryCode;

  /// True when [countryCode] is the diver's manual override rather than the
  /// country of their most recent dive.
  final bool regionIsManual;

  /// Every ISO code the region picker offers, sorted: the countries the
  /// bundled hotlines, EMS numbers and chambers know, plus a manual override
  /// outside them so the picker can still show it as selected.
  final List<String> regionChoices;
  final EmergencyRegion hotline;
  final String emsNumber;
  final Diver? diver;

  /// At most [chamberCardLimit] chambers worth showing on the card.
  final List<ChamberListing> nearbyChambers;

  /// Everything in the directory, for the "view all" affordance.
  final int totalChamberCount;

  const EmergencyCardData({
    required this.countryCode,
    this.regionIsManual = false,
    this.regionChoices = const [],
    required this.hotline,
    required this.emsNumber,
    required this.diver,
    required this.nearbyChambers,
    required this.totalChamberCount,
  });
}

final emergencyCardDataProvider = FutureProvider<EmergencyCardData>((
  ref,
) async {
  final numbers = await EmergencyDataService.loadNumbers();
  final bundledChambers = await EmergencyDataService.loadBundledChambers();
  final regionIsManual =
      _manualRegion(
        ref.watch(settingsProvider.select((s) => s.emergencyRegion)),
      ) !=
      null;
  final countryCode = await ref.watch(emergencyRegionProvider.future);
  final diver = await ref.watch(currentDiverProvider.future);
  final listings = await ref.watch(chamberListingsProvider.future);

  final regionChoices = <String>{
    ...numbers.emsByCountry.keys,
    for (final region in numbers.regions) ...region.countries,
    for (final chamber in bundledChambers) chamber.country,
    if (regionIsManual && countryCode != null) countryCode,
  }.toList()..sort();

  return EmergencyCardData(
    countryCode: countryCode,
    regionIsManual: regionIsManual,
    regionChoices: regionChoices,
    hotline: numbers.hotlineFor(countryCode),
    emsNumber: numbers.emsFor(countryCode),
    diver: diver,
    nearbyChambers: _selectNearby(listings, countryCode),
    totalChamberCount: listings.length,
  );
});

/// Haversine distance; entries without coordinates sort last.
double _distanceKm(double lat, double lon, double? lat2, double? lon2) {
  if (lat2 == null || lon2 == null) return double.maxFinite;
  const r = 6371.0;
  final dLat = _rad(lat2 - lat);
  final dLon = _rad(lon2 - lon);
  final aRaw =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  // Clamp to [0, 1]: floating-point drift can push `a` just past 1 for very
  // small distances, and asin(sqrt(a > 1)) is NaN, which corrupts the chamber
  // sort comparator.
  final a = aRaw.clamp(0.0, 1.0);
  return 2 * r * math.asin(math.sqrt(a));
}

double _rad(double deg) => deg * math.pi / 180;
