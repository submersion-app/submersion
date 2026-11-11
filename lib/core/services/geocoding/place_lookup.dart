/// What a reverse geocode of one coordinate found.
///
/// Every field is optional: a point in open sea has no locality, a point on
/// land has no body of water. [networkFailed] is true when the lookup could
/// not reach the geocoder at all, so a caller iterating many sites can stop
/// early instead of collecting one failure per site.
class PlaceLookup {
  const PlaceLookup({
    this.country,
    this.countryCode,
    this.region,
    this.locality,
    this.bodyOfWater,
    this.networkFailed = false,
  });

  const PlaceLookup.empty() : this();

  const PlaceLookup.unavailable() : this(networkFailed: true);

  final String? country;

  /// The geocoder's ISO 3166-1 alpha-2 code for [country], upper-cased,
  /// when it gave one (issue #4426).
  final String? countryCode;
  final String? region;
  final String? locality;
  final String? bodyOfWater;
  final bool networkFailed;

  bool get isEmpty =>
      country == null &&
      region == null &&
      locality == null &&
      bodyOfWater == null;

  PlaceLookup copyWith({String? bodyOfWater}) => PlaceLookup(
    country: country,
    countryCode: countryCode,
    region: region,
    locality: locality,
    bodyOfWater: bodyOfWater ?? this.bodyOfWater,
    networkFailed: networkFailed,
  );

  @override
  String toString() =>
      'PlaceLookup(country: $country, countryCode: $countryCode, region: $region, locality: $locality, '
      'bodyOfWater: $bodyOfWater, networkFailed: $networkFailed)';
}
