import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;

/// Credit for the built-in dive site catalogue.
abstract final class SiteCatalogueAttribution {
  /// The heading the credit is filed under on the license page.
  static const String packageName = 'Dive site data';

  /// Adds the catalogue's credits to the app's license page.
  ///
  /// The built-in sites are compiled from OpenStreetMap, which is under
  /// the Open Database License, and from open wreck and reef registers.
  /// Shipping them means crediting every source, saying the database is
  /// ODbL and offering it, and carrying each publisher's own required
  /// words. Four sources allow reuse only on their own terms; their
  /// records are named apart, as not part of the ODbL database.
  ///
  /// The sources and their licences are the ones the catalogue file
  /// declares (`metadata.sources`, written by
  /// scripts/site_catalogue_format.py); a test fails when the file
  /// declares one this text does not credit. Called once from `main()`.
  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      yield licenceEntry;
    });
  }

  /// The credit itself, as the license page shows it.
  static const licenceEntry = LicenseEntryWithLineBreaks(
    <String>[packageName],
    '''
Built-in dive sites (assets/data/site_catalogue.json) contain information
from OpenStreetMap, which is made available under the Open Database
License (ODbL).

© OpenStreetMap contributors
https://www.openstreetmap.org/copyright

Open Database License 1.0:
https://opendatacommons.org/licenses/odbl/1-0/

The built-in dive site data is a database compiled from OpenStreetMap and
the sources below, and is made available under the same licence. It is
published, with the scripts that produce it, in the Submersion source
repository:
https://github.com/submersion-app/submersion

Sites added by the Submersion project (scripts/dive_sites_curated.json),
under the Open Database License 1.0.

UK Hydrographic Office Wrecks and Obstructions. Contains public sector
information, licensed under the Open Government Licence v3.0, from the UK
Hydrographic Office.
https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/

NOAA Automated Wreck and Obstruction Information System, NOAA Office of
Coast Survey. Public domain (CC0 1.0).
https://nauticalcharts.noaa.gov/data/data-licensing.html

Artificial Reefs in Florida. Produced by the Florida Fish and Wildlife
Conservation Commission, Fish and Wildlife Research Institute (FWC-FWRI).
Public domain. The data set and its metadata:
https://www.arcgis.com/home/item.html?id=eb2bfd225149405bba23604f20159f56

MarineCadastre Artificial Reefs, NOAA Office for Coastal Management and
Bureau of Ocean Energy Management, compiled from the reef programs of the
states. Public domain.
https://www.fisheries.noaa.gov/inport/item/54191

Florida Keys National Marine Sanctuary buoys, NOAA Florida Keys National
Marine Sanctuary. A work of the United States Government, in the public
domain.
https://floridakeys.noaa.gov/mbuoy/allmbuoys.html

Wreck Inventory of Ireland Database, National Monuments Service,
Government of Ireland. Creative Commons Attribution 4.0.
https://creativecommons.org/licenses/by/4.0/

Wikidata. Public domain (CC0 1.0).
https://www.wikidata.org/wiki/Wikidata:Copyright

The records of the four sources below are not part of that database and
are not licensed under the ODbL. They remain under their publishers' own
terms.

Artificial Reef Deployments in New Jersey, New Jersey Department of
Environmental Protection (NJDEP), under its Data Distribution Agreement.
This application was developed using New Jersey Department of
Environmental Protection Geographic Information System digital data, but
this secondary product has not been verified by NJDEP and is not
state-authorized or endorsed. NJDEP's metadata for the data ships with
the app (assets/data/site_catalogue_njdep_metadata.xml).
https://www.arcgis.com/home/item.html?id=862307fcb54b4f70a6bdb9915d4c149f

Hawaii artificial reefs, Hawaii Department of Land and Natural Resources,
Division of Aquatic Resources. Copyright State of Hawaii. These records
may not be used commercially.
https://portal.ehawaii.gov/page/terms-of-use/

Texas artificial reefs, Texas Parks and Wildlife Department. Copyright
Texas Parks and Wildlife Department. These records may not be used
commercially or sold.
https://tpwd.texas.gov/site/policies/copyright-policy

North Carolina Artificial Reef Guide, N.C. Division of Marine Fisheries.
Reproduced without alteration for non-commercial use. These records may
not be used commercially.
https://www.nc.gov/disclaimer-terms-use

Positions and depths are as their sources published them. This data is
not for navigation.''',
  );
}
