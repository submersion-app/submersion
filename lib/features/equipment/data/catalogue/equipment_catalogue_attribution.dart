import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;

/// Credit for the built-in equipment catalogue (issue #5118).
abstract final class EquipmentCatalogueAttribution {
  /// The heading the credit is filed under on the license page.
  static const String packageName = 'Equipment data';

  /// Adds the catalogue's credit to the app's license page. Called once
  /// from `main()`.
  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      yield licenceEntry;
    });
  }

  /// The credit itself, as the license page shows it.
  static const licenceEntry = LicenseEntryWithLineBreaks(
    <String>[packageName],
    '''
The built-in equipment catalogue (assets/data/equipment_catalogue.json) is
published, with the scripts that build it, in the Submersion equipment
catalogue repository:
https://github.com/submersion-app/equipment-catalogue

Dive computer names, types and connectivity come from the device table of
libdivecomputer, as carried by Submersion's fork of it:
https://github.com/libdivecomputer/libdivecomputer
https://github.com/submersion-app/libdivecomputer

Manufacturer product, manual and support links point at each maker's own
pages. No text, image or document from those pages is copied into the
catalogue; each link cites the page it was read from.''',
  );
}
