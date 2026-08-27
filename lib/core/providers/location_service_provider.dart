import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';

/// Injectable handle to [LocationService].
///
/// Production resolves to the process-wide singleton. Tests override this with
/// a fake to supply deterministic geocoding results without real network or
/// platform-channel calls.
final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService.instance,
);
