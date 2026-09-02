import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';

/// Deterministic reverse geocoder for widget tests. Everything except
/// [reverseGeocode] falls through to noSuchMethod, so a test that reaches
/// another member fails loudly instead of hitting a platform channel.
class FakeLocationService implements LocationService {
  FakeLocationService(this.result, {this.fail = false});

  final PlaceLookup result;
  final bool fail;
  final calls = <({double lat, double lng, String languageCode})>[];

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    calls.add((lat: latitude, lng: longitude, languageCode: languageCode));
    if (fail) throw StateError('offline');
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
