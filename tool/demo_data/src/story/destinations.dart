import 'dart:math';

import 'catalog.dart';
import 'story_plan.dart';

/// Where the demo diver lives: Princeton, New Jersey, diving the central
/// Jersey shore, its wrecks and artificial reefs, from the shore and from
/// the Manasquan and Point Pleasant boats. The sites are the catalogue's
/// curated New Jersey supplement (`scripts/dive_sites_curated.json`).
///
/// Summer lays warm water over a cold bottom here, so its temperatures are
/// quoted for the deep water, as for a lake.
const homeDestination = Destination(
  key: 'home',
  label: 'Jersey shore',
  country: 'United States',
  region: 'New Jersey',
  area: (lat: 40.05, lon: -74.0, km: 45.0),
  waterTempC: (5.0, 14.0),
  freshwater: false,
  stratifies: true,
  nameRegion: 'en',
  utcOffsetMinutes: -300,
  daylightSaving: DaylightSaving.north,
);

/// The trip destinations in the Caribbean, where about half the trips go.
const caribbeanDestinations = {
  'bonaire',
  'curacao',
  'cozumel',
  'dominican',
  'guadeloupe',
  'san-andres',
  'santa-marta',
};

/// Every trip destination of the story, worldwide. Each one is a place in
/// the app's public catalogue, chosen by country, region and, where those
/// hold more than one place, a circle.
const tripDestinations = <Destination>[
  // The river's current mixes it, so it barely stratifies.
  Destination(
    key: 'st-lawrence',
    label: 'Kingston and the Thousand Islands',
    country: 'Canada',
    region: 'Ontario',
    area: (lat: 44.35, lon: -76.1, km: 80.0),
    waterTempC: (4.0, 22.0),
    freshwater: true,
    nameRegion: 'en',
    utcOffsetMinutes: -300,
    daylightSaving: DaylightSaving.north,
    nearHome: true,
    resortNames: ['Riverside Inn', 'Limestone Harbour Motel'],
  ),
  Destination(
    key: 'bonaire',
    label: 'Bonaire',
    country: 'Nederland',
    region: null,
    area: (lat: 12.17, lon: -68.28, km: 30.0),
    waterTempC: (26.0, 29.0),
    freshwater: false,
    nameRegion: 'nl',
    utcOffsetMinutes: -240,
    resortNames: ['Kas Flamingo', 'Bon Kunuku Dive Lodge'],
  ),
  Destination(
    key: 'guadeloupe',
    label: 'Guadeloupe',
    country: 'France',
    region: 'Guadeloupe',
    waterTempC: (26.0, 29.0),
    freshwater: false,
    nameRegion: 'fr',
    utcOffsetMinutes: -240,
    resortNames: ['Ti Kaz Corail', 'Résidence Anse Bleue'],
  ),
  Destination(
    key: 'santa-marta',
    label: 'Santa Marta and Taganga',
    country: 'Colombia',
    region: null,
    area: (lat: 11.25, lon: -74.2, km: 40.0),
    waterTempC: (24.0, 28.0),
    freshwater: false,
    nameRegion: 'es',
    utcOffsetMinutes: -300,
    resortNames: ['Posada Bahía Taganga', 'Casa Sierra Mar'],
  ),
  Destination(
    key: 'florida-springs',
    label: 'Florida springs',
    country: 'United States',
    region: 'Florida',
    waterTempC: (21.0, 23.0),
    freshwater: true,
    nameRegion: 'en',
    utcOffsetMinutes: -300,
    daylightSaving: DaylightSaving.north,
    area: (lat: 29.6, lon: -82.5, km: 130.0),
    scooterOk: false,
    maxDepthM: 20,
    resortNames: ['Cypress Hollow Lodge', 'Spring Run Cabins'],
  ),
  Destination(
    key: 'red-sea',
    label: 'Red Sea',
    country: 'مصر',
    region: 'البحر الأحمر',
    waterTempC: (22.0, 28.0),
    freshwater: false,
    nameRegion: 'ar',
    utcOffsetMinutes: 120,
    liveaboard: true,
    boatNames: ['MV Tarvenna', 'MV Seluna'],
  ),
  Destination(
    key: 'sinai',
    label: 'Sinai coast',
    country: 'مصر',
    region: 'جنوب سيناء',
    waterTempC: (21.0, 27.0),
    freshwater: false,
    nameRegion: 'ar',
    utcOffsetMinutes: 120,
    resortNames: ['Coral Moon Lodge', 'Wadi Breeze Camp'],
  ),
  Destination(
    key: 'maldives',
    label: 'Maldives',
    country: 'ދިވެހިރާއްޖެ',
    region: 'މާލެ އަތޮޅު',
    waterTempC: (27.0, 30.0),
    freshwater: false,
    nameRegion: 'dv',
    utcOffsetMinutes: 300,
    liveaboard: true,
    boatNames: ['MV Ameeru Dhoni', 'MV Falhu Star'],
  ),
  Destination(
    key: 'ari-atoll',
    label: 'Ari Atoll',
    country: 'ދިވެހިރާއްޖެ',
    region: 'އަރިއަތޮޅު އުތުރުބުރި',
    waterTempC: (27.0, 30.0),
    freshwater: false,
    nameRegion: 'dv',
    utcOffsetMinutes: 300,
    resortNames: ['Kandu Reef Island', 'Thila Sands'],
  ),
  Destination(
    key: 'bali',
    label: 'Bali',
    country: 'Indonesia',
    region: 'Bali',
    waterTempC: (26.0, 29.0),
    freshwater: false,
    nameRegion: 'id',
    utcOffsetMinutes: 480,
    resortNames: ['Pondok Laut Biru', 'Rumah Karang'],
  ),
  Destination(
    key: 'raja-ampat',
    label: 'Raja Ampat',
    country: 'Indonesia',
    region: 'Papua Barat Daya',
    waterTempC: (27.0, 30.0),
    freshwater: false,
    nameRegion: 'id',
    utcOffsetMinutes: 540,
    liveaboard: true,
    boatNames: ['KLM Bintang Senja', 'KLM Arus Biru'],
  ),
  Destination(
    key: 'komodo',
    label: 'Komodo',
    country: 'Indonesia',
    region: 'Nusa Tenggara Timur',
    waterTempC: (24.0, 28.0),
    freshwater: false,
    nameRegion: 'id',
    utcOffsetMinutes: 480,
    liveaboard: true,
    boatNames: ['KLM Naga Laut', 'KLM Pelangi Timur'],
  ),
  Destination(
    key: 'lembeh',
    label: 'North Sulawesi',
    country: 'Indonesia',
    region: 'Sulawesi Utara',
    waterTempC: (26.0, 29.0),
    freshwater: false,
    nameRegion: 'id',
    utcOffsetMinutes: 480,
    resortNames: ['Selat Muck Lodge', 'Rumah Pasir Hitam'],
  ),
  Destination(
    key: 'cebu',
    label: 'Cebu',
    country: 'Philippines',
    region: 'Cebu',
    waterTempC: (26.0, 29.0),
    freshwater: false,
    nameRegion: 'fil',
    utcOffsetMinutes: 480,
    resortNames: ['Bahay Dagat Resort', 'Isla Banog Lodge'],
  ),
  Destination(
    key: 'palawan',
    label: 'Coron and Palawan',
    country: 'Philippines',
    region: 'Palawan',
    waterTempC: (27.0, 30.0),
    freshwater: false,
    nameRegion: 'fil',
    utcOffsetMinutes: 480,
    resortNames: ['Bangka Cove Lodge', 'Lagoon Hut Resort'],
  ),
  Destination(
    key: 'similan',
    label: 'Similan Islands',
    country: 'ประเทศไทย',
    region: 'จังหวัดพังงา',
    waterTempC: (27.0, 29.0),
    freshwater: false,
    nameRegion: 'th',
    utcOffsetMinutes: 420,
    liveaboard: true,
    boatNames: ['MV Sai Nam', 'MV Talay Fah'],
  ),
  Destination(
    key: 'koh-tao',
    label: 'Koh Tao',
    country: 'ประเทศไทย',
    region: 'จังหวัดสุราษฎร์ธานี',
    waterTempC: (28.0, 30.0),
    freshwater: false,
    nameRegion: 'th',
    utcOffsetMinutes: 420,
    resortNames: ['Baan Hin Sai', 'Ao Leuk Cabanas'],
  ),
  Destination(
    key: 'sabah',
    label: 'Sabah',
    country: 'Malaysia',
    region: 'Sabah',
    waterTempC: (27.0, 30.0),
    freshwater: false,
    nameRegion: 'ms',
    utcOffsetMinutes: 480,
    resortNames: ['Pulau Teduh Lodge', 'Rumah Penyu'],
  ),
  Destination(
    key: 'chuuk',
    label: 'Chuuk Lagoon',
    country: 'Micronesia',
    region: 'Chuuk',
    waterTempC: (28.0, 30.0),
    freshwater: false,
    nameRegion: 'pacific',
    utcOffsetMinutes: 600,
    minPhase: StoryPhase.technicalOc,
    resortNames: ['Lagoon Anchor Hotel', 'Weno Shore Lodge'],
  ),
  Destination(
    key: 'palau',
    label: 'Palau',
    country: 'Belau',
    region: 'Koror',
    waterTempC: (27.0, 30.0),
    freshwater: false,
    nameRegion: 'pacific',
    utcOffsetMinutes: 540,
    liveaboard: true,
    boatNames: ['MV Rock Island Wren', 'MV Ngemelis Drift'],
  ),
  Destination(
    key: 'bikini',
    label: 'Marshall Islands wrecks',
    country: 'Ṃajeḷ',
    region: 'Rālik',
    waterTempC: (27.0, 29.0),
    freshwater: false,
    nameRegion: 'pacific',
    utcOffsetMinutes: 720,
    liveaboard: true,
    minPhase: StoryPhase.technicalOc,
    boatNames: ['MV Atoll Sentry', 'MV Lagoon Runner'],
  ),
  Destination(
    key: 'okinawa',
    label: 'Okinawa',
    country: '日本',
    region: '沖縄県',
    waterTempC: (21.0, 28.0),
    freshwater: false,
    nameRegion: 'ja',
    utcOffsetMinutes: 540,
    resortNames: ['Umikaze Guesthouse', 'Sango Minshuku'],
  ),
  Destination(
    key: 'nsw',
    label: 'New South Wales',
    country: 'Australia',
    region: 'New South Wales',
    waterTempC: (17.0, 23.0),
    freshwater: false,
    nameRegion: 'en',
    utcOffsetMinutes: 600,
    daylightSaving: DaylightSaving.south,
    resortNames: ['Headland Dive Lodge', 'Bay Swell Cabins'],
  ),
  Destination(
    key: 'curacao',
    label: 'Curaçao',
    country: 'Curaçao',
    region: null,
    waterTempC: (26.0, 28.0),
    freshwater: false,
    nameRegion: 'nl',
    utcOffsetMinutes: -240,
    resortNames: ['Kas di Laman', 'Bon Bida Lodge'],
  ),
  Destination(
    key: 'dominican',
    label: 'Dominican Republic',
    country: 'República Dominicana',
    region: null,
    waterTempC: (26.0, 28.0),
    freshwater: false,
    nameRegion: 'es',
    utcOffsetMinutes: -240,
    resortNames: ['Casa Arrecife', 'Bahía Clara Lodge'],
  ),
  Destination(
    key: 'san-andres',
    label: 'San Andrés',
    country: 'Colombia',
    region: 'Archipiélago de San Andrés, Providencia y Santa Catalina',
    waterTempC: (26.0, 29.0),
    freshwater: false,
    nameRegion: 'es',
    utcOffsetMinutes: -300,
    resortNames: ['Posada Mar de Siete Colores', 'Cayo Brisa'],
  ),
  Destination(
    key: 'galapagos',
    label: 'Galápagos',
    country: 'Ecuador',
    region: 'Galápagos',
    waterTempC: (18.0, 25.0),
    freshwater: false,
    nameRegion: 'es',
    utcOffsetMinutes: -360,
    liveaboard: true,
    boatNames: ['MV Garúa', 'MV Corriente Fría'],
  ),
  Destination(
    key: 'polynesia',
    label: 'French Polynesia',
    country: 'France',
    region: 'Polynésie Française',
    waterTempC: (25.0, 28.0),
    freshwater: false,
    nameRegion: 'fr',
    utcOffsetMinutes: -600,
    resortNames: ['Fare Lagon', 'Pension Hoa Nui'],
  ),
  Destination(
    key: 'hawaii',
    label: 'Hawaii',
    country: 'United States',
    region: 'Hawaii',
    waterTempC: (24.0, 27.0),
    freshwater: false,
    nameRegion: 'en',
    utcOffsetMinutes: -600,
    resortNames: ['Lava Point Inn', 'Makai Reef Cottages'],
  ),
  Destination(
    key: 'cozumel',
    label: 'Cozumel',
    country: 'México',
    region: null,
    waterTempC: (26.0, 29.0),
    freshwater: false,
    nameRegion: 'es',
    utcOffsetMinutes: -300,
    area: (lat: 20.4, lon: -86.95, km: 35.0),
    resortNames: ['Posada Arrecife', 'Casa Corriente'],
  ),
  Destination(
    key: 'med',
    label: 'Mediterranean wrecks',
    country: 'France',
    region: 'Occitanie',
    waterTempC: (14.0, 22.0),
    freshwater: false,
    nameRegion: 'fr',
    utcOffsetMinutes: 60,
    daylightSaving: DaylightSaving.north,
    minPhase: StoryPhase.technicalOc,
    resortNames: ['Hôtel du Phare', 'Mas des Épaves'],
  ),
  Destination(
    key: 'croatia',
    label: 'Kvarner Gulf',
    country: 'Hrvatska',
    region: 'Primorsko-goranska županija',
    waterTempC: (14.0, 23.0),
    freshwater: false,
    nameRegion: 'hr',
    utcOffsetMinutes: 60,
    daylightSaving: DaylightSaving.north,
    resortNames: ['Pansion Uvala', 'Kuća Kvarner'],
  ),
  Destination(
    key: 'malta',
    label: 'Malta and Gozo',
    country: 'Malta',
    region: null,
    waterTempC: (15.0, 25.0),
    freshwater: false,
    nameRegion: 'mt',
    utcOffsetMinutes: 60,
    daylightSaving: DaylightSaving.north,
    resortNames: ['Dar il-Baħar', 'Kantuniera Guesthouse'],
  ),
  Destination(
    key: 'cyprus',
    label: 'Cyprus',
    country: 'Κύπρος - Kıbrıs',
    region: 'Κύπρος',
    waterTempC: (17.0, 27.0),
    freshwater: false,
    nameRegion: 'el',
    utcOffsetMinutes: 120,
    daylightSaving: DaylightSaving.north,
    resortNames: ['Spiti Akti', 'Limani Rooms'],
  ),
  Destination(
    key: 'norway',
    label: 'Southern Norway',
    country: 'Norge',
    region: 'Agder',
    waterTempC: (6.0, 13.0),
    freshwater: false,
    nameRegion: 'no',
    utcOffsetMinutes: 60,
    daylightSaving: DaylightSaving.north,
    resortNames: ['Fjordbu Rorbuer', 'Skjærgård Hytter'],
  ),
  Destination(
    key: 'scotland',
    label: 'Scapa Flow and Scotland',
    country: 'United Kingdom',
    region: 'Alba / Scotland',
    waterTempC: (8.0, 12.0),
    freshwater: false,
    nameRegion: 'en',
    utcOffsetMinutes: 0,
    daylightSaving: DaylightSaving.north,
    minPhase: StoryPhase.technicalOc,
    resortNames: ['Harbour Brae House', 'Stromness Quay Rooms'],
  ),
];

final _notASite = RegExp(
  r'\b(shop|shops|tours?|shuttle|scuba|diving|divers|dive cent(er|re)|dive club|school|hotel|resort|rental|marina)\b',
  caseSensitive: false,
);

/// The catalogue's dive sites at [d], in id order so a seed picks the same
/// ones. Shops, tour operators and anything sharing a dive centre's name are
/// left out: the public catalogue tags some of them as dive sites.
List<CatalogSite> catalogSitesFor(Destination d, Catalog catalog) {
  final centreNames = {for (final c in catalog.centers) c.name};
  bool inArea(CatalogSite s) {
    final a = d.area;
    if (a == null) return true;
    return kmBetween(a.lat, a.lon, s.latitude, s.longitude) <= a.km;
  }

  return catalog.sites
      .where(
        (s) =>
            s.country == d.country &&
            (d.region == null || s.region == d.region) &&
            inArea(s) &&
            !centreNames.contains(s.name) &&
            !_notASite.hasMatch(s.name),
      )
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
}

/// Great-circle distance in kilometres.
double kmBetween(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double deg) => deg * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(sqrt(h));
}

/// [d]'s offset from UTC in minutes on [when], with its daylight saving
/// (taken as April to October in the north, October to March in the south).
int utcOffsetOn(Destination d, DateTime when) {
  final summer = switch (d.daylightSaving) {
    DaylightSaving.north => when.month >= 4 && when.month <= 10,
    DaylightSaving.south => when.month >= 10 || when.month <= 3,
    null => false,
  };
  return d.utcOffsetMinutes + (summer ? 60 : 0);
}
