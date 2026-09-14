import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;

/// Credit for the depth grids the seascape and site depths are drawn from.
abstract final class BathymetryAttribution {
  /// The heading the credit is filed under on the license page.
  static const String packageName = 'Bathymetry data';

  /// Adds the bathymetry sources' credit to the app's license page.
  ///
  /// GMRT and EMODnet are CC BY 4.0 and swissBATHY3D requires naming its
  /// source, so drawing their grids inside the app means carrying the credit
  /// with them. The NOAA tiers are US public domain and are credited as a
  /// courtesy. Called once from `main()`.
  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(
        <String>[packageName],
        '''
Seascape and site depth data are fetched at run time from the sources
below. Each grid is drawn from whichever source covers a site best.

GMRT (Global Multi-Resolution Topography) synthesis, Lamont-Doherty
Earth Observatory, Columbia University. Licensed under Creative
Commons Attribution 4.0 (CC BY 4.0). https://www.gmrt.org

EMODnet Bathymetry Digital Terrain Model, European Marine Observation
and Data Network. Licensed under Creative Commons Attribution 4.0
(CC BY 4.0). https://emodnet.ec.europa.eu

NOAA ETOPO 2022 Global Relief Model and the NOAA NCEI DEM mosaic,
NOAA National Centers for Environmental Information. US public
domain. https://www.ncei.noaa.gov

swissBATHY3D lake-bed elevation model, Federal Office of Topography.
Open government data, free use with source attribution required.
© swisstopo. https://www.swisstopo.admin.ch''',
      );
    });
  }
}
