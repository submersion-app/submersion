/// The last good downloaded equipment catalogue, kept between launches.
///
/// Native builds keep it as a file in the app support directory
/// (`equipment_catalogue_cache_io.dart`). The web build never downloads the
/// catalogue, so its half keeps nothing.
library;

export 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_cache_io.dart'
    if (dart.library.js_interop) 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_cache_web.dart';
