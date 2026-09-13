/// Column headers of the dives CSV that `CsvExportService` writes.
///
/// The built-in Submersion CSV import preset reads the same constants, so the
/// export and the importer that recognizes it cannot drift apart (#1814).
/// Values are canonical metric regardless of the diver's unit settings.
abstract final class DiveCsvColumns {
  static const diveNumber = 'Dive Number';
  static const name = 'Name';
  static const date = 'Date';
  static const time = 'Time';
  static const site = 'Site';

  /// The site's one-line display location (`locality · region, country`,
  /// where the locality is the city, else the island). Display text only;
  /// [siteCity], [siteIsland], [siteRegion] and [siteCountry] carry the same
  /// data in a form an import can read back.
  static const location = 'Location';
  static const maxDepth = 'Max Depth (m)';
  static const avgDepth = 'Avg Depth (m)';
  static const bottomTime = 'Bottom Time (min)';
  static const runtime = 'Runtime (min)';
  static const waterTemp = 'Water Temp (°C)';
  static const airTemp = 'Air Temp (°C)';

  // Split at v144: the measured distance is machine-readable, the rating
  // column carries a pre-v144 dive's bucket label.
  static const visibility = 'Visibility (m)';
  static const visibilityRating = 'Visibility Rating';
  static const diveType = 'Dive Type';
  static const buddy = 'Buddy';
  static const diveMaster = 'Dive Master';
  static const rating = 'Rating';
  static const startPressure = 'Start Pressure (bar)';
  static const endPressure = 'End Pressure (bar)';
  static const tankVolume = 'Tank Volume (L)';
  static const o2Percent = 'O2 %';
  static const diveComputer = 'Dive Computer';
  static const serialNumber = 'Serial Number';
  static const firmwareVersion = 'Firmware Version';
  static const notes = 'Notes';
  static const windSpeed = 'Wind Speed (m/s)';
  static const windDirection = 'Wind Direction';
  static const cloudCover = 'Cloud Cover';
  static const precipitation = 'Precipitation';
  static const humidity = 'Humidity (%)';
  static const weatherDescription = 'Weather Description';

  // Appended after the pre-#1814 columns so spreadsheets that address the
  // export by column position keep their offsets.
  static const siteCity = 'Site City';
  static const siteRegion = 'Site Region';
  static const siteCountry = 'Site Country';
  static const siteIsland = 'Site Island';

  /// Helium of the first tank. [o2Percent] alone would read a trimix tank
  /// back as nitrox.
  static const hePercent = 'He %';

  /// The dive's custom fields as a JSON list of `{key, value}` objects, in
  /// the dive's own order. Unlike the per-key columns, it keeps a field
  /// whose value is empty and the order the diver set; an import prefers it.
  static const customFields = 'Custom Fields';

  /// Separator between a dive's types in the [diveType] cell.
  static const diveTypeSeparator = '; ';

  /// Prefix of the per-key custom field columns that follow the fixed ones.
  /// They are a spreadsheet view of [customFields].
  static const customFieldPrefix = 'custom:';

  /// Every fixed column, in export order. Custom field columns follow.
  static const fixed = [
    diveNumber,
    name,
    date,
    time,
    site,
    location,
    maxDepth,
    avgDepth,
    bottomTime,
    runtime,
    waterTemp,
    airTemp,
    visibility,
    visibilityRating,
    diveType,
    buddy,
    diveMaster,
    rating,
    startPressure,
    endPressure,
    tankVolume,
    o2Percent,
    diveComputer,
    serialNumber,
    firmwareVersion,
    notes,
    windSpeed,
    windDirection,
    cloudCover,
    precipitation,
    humidity,
    weatherDescription,
    siteCity,
    siteRegion,
    siteCountry,
    siteIsland,
    hePercent,
    customFields,
  ];
}
