import 'dart:math' as math;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/data/repositories/emergency_chamber_repository.dart';
import 'package:submersion/features/safety/data/services/emergency_data_service.dart';
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

/// Everything the offline emergency card renders, assembled from local data
/// only (bundled assets, DB, settings). No network, no location permission.
class EmergencyCardData {
  final String? countryCode;
  final EmergencyRegion hotline;
  final String emsNumber;
  final Diver? diver;
  final List<EmergencyChamber> chambers;

  const EmergencyCardData({
    required this.countryCode,
    required this.hotline,
    required this.emsNumber,
    required this.diver,
    required this.chambers,
  });
}

final emergencyCardDataProvider = FutureProvider<EmergencyCardData>((
  ref,
) async {
  final numbers = await EmergencyDataService.loadNumbers();
  final bundled = await EmergencyDataService.loadBundledChambers();
  final countryCode = await ref.watch(emergencyRegionProvider.future);
  final diver = await ref.watch(currentDiverProvider.future);
  final hidden = ref.watch(settingsProvider.select((s) => s.hiddenChamberIds));

  final chamberRepo = ref.watch(emergencyChamberRepositoryProvider);
  ref.invalidateSelfWhen(chamberRepo.watchChanges());
  final userChambers = await chamberRepo.getUserChambers(diverId: diver?.id);

  // User chambers first, then bundled chambers (hidden entries filtered out).
  // The final ordering is applied below: by distance when the last dive has
  // GPS, else same-country-first, else this insertion order.
  final visibleBundled = bundled.where((c) => !hidden.contains(c.id)).toList();
  final chambers = [...userChambers, ...visibleBundled];

  // Distance sort when the most recent dive site has GPS. Re-run when dives
  // change so the sort stays fresh even when a manual region override makes
  // emergencyRegionProvider return early (and skip its own subscription).
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
  if (lat != null && lon != null) {
    chambers.sort((a, b) {
      final da = _distanceKm(lat, lon, a.latitude, a.longitude);
      final db = _distanceKm(lat, lon, b.latitude, b.longitude);
      return da.compareTo(db);
    });
  } else if (countryCode != null) {
    // No GPS: same-country chambers first.
    chambers.sort((a, b) {
      final aMatch = a.country == countryCode ? 0 : 1;
      final bMatch = b.country == countryCode ? 0 : 1;
      return aMatch.compareTo(bMatch);
    });
  }

  return EmergencyCardData(
    countryCode: countryCode,
    hotline: numbers.hotlineFor(countryCode),
    emsNumber: numbers.emsFor(countryCode),
    diver: diver,
    chambers: chambers,
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
