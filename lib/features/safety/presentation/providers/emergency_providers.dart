import 'dart:math' as math;

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
  final override = ref.watch(settingsProvider.select((s) => s.emergencyRegion));
  if (override != null && override.trim().isNotEmpty) {
    // Chamber countries and the dataset keys are upper-case ISO codes, so
    // normalize the manual override to match same-country comparisons.
    return override.trim().toUpperCase();
  }

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
  final country = summaries.first.siteCountry;
  if (country == null || country.isEmpty) return null;
  return _isoFromCountry(country);
});

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
  final EmergencyRegion hotline;
  final String emsNumber;
  final Diver? diver;

  /// At most [chamberCardLimit] chambers worth showing on the card.
  final List<ChamberListing> nearbyChambers;

  /// Everything in the directory, for the "view all" affordance.
  final int totalChamberCount;

  const EmergencyCardData({
    required this.countryCode,
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
  final countryCode = await ref.watch(emergencyRegionProvider.future);
  final diver = await ref.watch(currentDiverProvider.future);
  final listings = await ref.watch(chamberListingsProvider.future);

  return EmergencyCardData(
    countryCode: countryCode,
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

/// Site countries are stored as display names ("Australia"), not ISO codes.
/// Best-effort mapping for the countries the bundled dataset knows about;
/// unknown names return null (worldwide fallback).
String? _isoFromCountry(String country) {
  final normalized = country.trim().toUpperCase();
  if (normalized.length == 2) return normalized;
  const names = {
    'UNITED STATES': 'US',
    'USA': 'US',
    'CANADA': 'CA',
    'MEXICO': 'MX',
    'AUSTRALIA': 'AU',
    'NEW ZEALAND': 'NZ',
    'UNITED KINGDOM': 'GB',
    'IRELAND': 'IE',
    'FRANCE': 'FR',
    'SPAIN': 'ES',
    'PORTUGAL': 'PT',
    'ITALY': 'IT',
    'MALTA': 'MT',
    'GREECE': 'GR',
    'CROATIA': 'HR',
    'GERMANY': 'DE',
    'AUSTRIA': 'AT',
    'SWITZERLAND': 'CH',
    'NETHERLANDS': 'NL',
    'BELGIUM': 'BE',
    'NORWAY': 'NO',
    'SWEDEN': 'SE',
    'DENMARK': 'DK',
    'FINLAND': 'FI',
    'POLAND': 'PL',
    'CZECHIA': 'CZ',
    'CZECH REPUBLIC': 'CZ',
    'HUNGARY': 'HU',
    'TURKEY': 'TR',
    'CYPRUS': 'CY',
    'EGYPT': 'EG',
    'ISRAEL': 'IL',
    'SOUTH AFRICA': 'ZA',
    'MOZAMBIQUE': 'MZ',
    'TANZANIA': 'TZ',
    'KENYA': 'KE',
    'SEYCHELLES': 'SC',
    'MAURITIUS': 'MU',
    'JAPAN': 'JP',
    'SOUTH KOREA': 'KR',
    'TAIWAN': 'TW',
    'INDONESIA': 'ID',
    'MALAYSIA': 'MY',
    'THAILAND': 'TH',
    'PHILIPPINES': 'PH',
    'SINGAPORE': 'SG',
    'VIETNAM': 'VN',
    'CAMBODIA': 'KH',
    'MYANMAR': 'MM',
    'MALDIVES': 'MV',
    'SRI LANKA': 'LK',
    'FIJI': 'FJ',
    'PAPUA NEW GUINEA': 'PG',
    'VANUATU': 'VU',
    'PALAU': 'PW',
    'MICRONESIA': 'FM',
    'MARSHALL ISLANDS': 'MH',
    'BAHAMAS': 'BS',
    'CAYMAN ISLANDS': 'KY',
    'TURKS AND CAICOS': 'TC',
    'BERMUDA': 'BM',
    'COSTA RICA': 'CR',
    'PANAMA': 'PA',
    'BELIZE': 'BZ',
    'HONDURAS': 'HN',
    'COLOMBIA': 'CO',
    'ECUADOR': 'EC',
    'BRAZIL': 'BR',
    'ARGENTINA': 'AR',
    'CHILE': 'CL',
    'PERU': 'PE',
    // Localized country names for the supported (Latin-script) locales:
    // platform geocoding returns `Placemark.country` in the device language,
    // so an English-only map would fall back to the worldwide hotline for a
    // German device reporting "Deutschland". Best-effort for the common diving
    // and home countries; the complete fix is to persist Placemark's ISO code.
    'DEUTSCHLAND': 'DE',
    'ALLEMAGNE': 'DE',
    'ALEMANIA': 'DE',
    'GERMANIA': 'DE',
    'DUITSLAND': 'DE',
    'FRANKREICH': 'FR',
    'FRANCIA': 'FR',
    'FRANKRIJK': 'FR',
    'FRANÇA': 'FR',
    'ESPAÑA': 'ES',
    'SPANIEN': 'ES',
    'ESPAGNE': 'ES',
    'SPAGNA': 'ES',
    'SPANJE': 'ES',
    'ITALIA': 'IT',
    'ITALIEN': 'IT',
    'ITALIE': 'IT',
    'ITALIË': 'IT',
    'ITÁLIA': 'IT',
    'NIEDERLANDE': 'NL',
    'PAÍSES BAJOS': 'NL',
    'PAYS-BAS': 'NL',
    'PAESI BASSI': 'NL',
    'NEDERLAND': 'NL',
    'GRIECHENLAND': 'GR',
    'GRECIA': 'GR',
    'GRÈCE': 'GR',
    'GRIEKENLAND': 'GR',
    'KROATIEN': 'HR',
    'CROACIA': 'HR',
    'CROATIE': 'HR',
    'CROAZIA': 'HR',
    'ÄGYPTEN': 'EG',
    'EGIPTO': 'EG',
    'ÉGYPTE': 'EG',
    'EGITTO': 'EG',
    'EGITO': 'EG',
    'MEXIKO': 'MX',
    'MÉXICO': 'MX',
    'MEXIQUE': 'MX',
    'MESSICO': 'MX',
    'MALEDIVEN': 'MV',
    'MALDIVAS': 'MV',
    'MALDIVE': 'MV',
    'INDONESIEN': 'ID',
    'INDONÉSIE': 'ID',
    'INDONÉSIA': 'ID',
    'INDONESIË': 'ID',
    'TAILANDIA': 'TH',
    'THAÏLANDE': 'TH',
    'THAILANDIA': 'TH',
    'TAILÂNDIA': 'TH',
    'FILIPINAS': 'PH',
    'PHILIPPINEN': 'PH',
    'FILIPPINE': 'PH',
    'FILIPIJNEN': 'PH',
    'TÜRKEI': 'TR',
    'TURQUÍA': 'TR',
    'TURQUIE': 'TR',
    'TURCHIA': 'TR',
    'TURQUIA': 'TR',
  };
  return names[normalized];
}
