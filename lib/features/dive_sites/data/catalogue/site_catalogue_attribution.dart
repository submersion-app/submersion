import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;

/// Credit for the built-in dive site catalogue.
abstract final class SiteCatalogueAttribution {
  /// The heading the credit is filed under on the license page.
  static const String packageName = 'Dive site data';

  /// Adds the catalogue's credit to the app's license page.
  ///
  /// The built-in sites are drawn from OpenStreetMap, which is under the
  /// Open Database License: shipping them inside the app means crediting
  /// OpenStreetMap, saying the data is ODbL, and offering the database.
  /// Called once from `main()`.
  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(
        <String>[packageName],
        '''
Built-in dive sites (assets/data/site_catalogue.json) contain information
from OpenStreetMap, which is made available under the Open Database
License (ODbL).

© OpenStreetMap contributors
https://www.openstreetmap.org/copyright

Open Database License 1.0:
https://opendatacommons.org/licenses/odbl/1-0/

The built-in dive site data as a whole is made available under the same
licence. It is published, with the scripts that produce it, in the
Submersion source repository:
https://github.com/submersion-app/submersion''',
      );
    });
  }
}
