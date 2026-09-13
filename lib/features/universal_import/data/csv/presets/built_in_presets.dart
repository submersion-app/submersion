import 'package:submersion/core/services/export/csv/dive_csv_columns.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// All built-in CSV presets shipped with Submersion.
///
/// These cover the most common dive log export formats and are always
/// available without any user configuration.
const List<CsvPreset> builtInCsvPresets = [
  _subsurface,
  _macdive,
  _divingLog,
  _diveMate,
  _garminConnect,
  _shearwater,
  _submersionNative,
  _myssi,
];

// ======================== 8. MySSI (SSI website export) ========================

/// The CSV downloadable from my.divessi.com (#190). Country, Dive Activity,
/// Specialty Dive, and Dive type have no import target field and stay
/// unmapped.
const _myssi = CsvPreset(
  id: 'myssi',
  name: 'MySSI',
  source: PresetSource.builtIn,
  sourceApp: SourceApp.ssiMyDiveGuide,
  signatureHeaders: [
    'dive #',
    'dive site',
    'country',
    'date / time',
    'dive activity',
    'specialty dive',
    'dive type',
    'duration',
    'depth',
    'dive buddy / instructor / center',
  ],
  matchThreshold: 0.6,
  mappings: {
    'primary': FieldMapping(
      name: 'MySSI Default',
      sourceApp: SourceApp.ssiMyDiveGuide,
      columns: [
        ColumnMapping(sourceColumn: 'dive #', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'Dive Site', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'Date / Time', targetField: 'dateTime'),
        ColumnMapping(sourceColumn: 'Duration', targetField: 'duration'),
        ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
        ColumnMapping(
          sourceColumn: 'Dive Buddy / Instructor / Center',
          targetField: 'buddy',
        ),
      ],
    ),
  },
  supportedEntities: {ImportEntityType.dives},
);

// ======================== 1. Subsurface (multi-file) ========================

const _subsurface = CsvPreset(
  id: 'subsurface',
  name: 'Subsurface',
  source: PresetSource.builtIn,
  sourceApp: SourceApp.subsurface,
  signatureHeaders: [
    'dive number',
    'date',
    'time',
    'duration [min]',
    'sac [l/min]',
    'maxdepth [m]',
    'avgdepth [m]',
    'mode',
    'airtemp [C]',
    'watertemp [C]',
    'cylinder size (1) [l]',
    'startpressure (1) [bar]',
    'endpressure (1) [bar]',
    'o2 (1) [%]',
    'he (1) [%]',
    'location',
    'gps',
    'divemaster',
    'buddy',
    'suit',
    'rating',
    'visibility',
    'notes',
    'weight [kg]',
    'tags',
  ],
  matchThreshold: 0.5,
  fileRoles: [
    PresetFileRole(
      roleId: 'dive_list',
      label: 'Dive List',
      required: true,
      signatureHeaders: [
        'dive number',
        'maxdepth [m]',
        'sac [l/min]',
        'cylinder size (1) [l]',
      ],
    ),
    PresetFileRole(
      roleId: 'dive_profile',
      label: 'Dive Profile',
      required: false,
      signatureHeaders: [
        'sample time (min)',
        'sample depth (m)',
        'sample temperature (C)',
      ],
    ),
  ],
  mappings: {
    'dive_list': FieldMapping(
      name: 'Subsurface Dive List',
      sourceApp: SourceApp.subsurface,
      columns: [
        ColumnMapping(sourceColumn: 'dive number', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'time', targetField: 'time'),
        ColumnMapping(
          sourceColumn: 'duration [min]',
          targetField: 'duration',
          transform: ValueTransform.hmsToSeconds,
        ),
        ColumnMapping(sourceColumn: 'maxdepth [m]', targetField: 'maxDepth'),
        ColumnMapping(sourceColumn: 'avgdepth [m]', targetField: 'avgDepth'),
        ColumnMapping(sourceColumn: 'sac [l/min]', targetField: 'sac'),
        ColumnMapping(sourceColumn: 'mode', targetField: 'diveType'),
        ColumnMapping(sourceColumn: 'airtemp [C]', targetField: 'airTemp'),
        ColumnMapping(sourceColumn: 'watertemp [C]', targetField: 'waterTemp'),
        ColumnMapping(sourceColumn: 'location', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'gps', targetField: 'gps'),
        ColumnMapping(sourceColumn: 'divemaster', targetField: 'diveMaster'),
        ColumnMapping(sourceColumn: 'buddy', targetField: 'buddy'),
        ColumnMapping(sourceColumn: 'suit', targetField: 'suit'),
        ColumnMapping(sourceColumn: 'rating', targetField: 'rating'),
        ColumnMapping(
          sourceColumn: 'visibility',
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(sourceColumn: 'notes', targetField: 'notes'),
        ColumnMapping(sourceColumn: 'weight [kg]', targetField: 'weight'),
        ColumnMapping(sourceColumn: 'tags', targetField: 'tags'),
        // Tank group 1
        ColumnMapping(
          sourceColumn: 'cylinder size (1) [l]',
          targetField: 'tankVolume_1',
        ),
        ColumnMapping(
          sourceColumn: 'startpressure (1) [bar]',
          targetField: 'startPressure_1',
        ),
        ColumnMapping(
          sourceColumn: 'endpressure (1) [bar]',
          targetField: 'endPressure_1',
        ),
        ColumnMapping(sourceColumn: 'o2 (1) [%]', targetField: 'o2Percent_1'),
        ColumnMapping(sourceColumn: 'he (1) [%]', targetField: 'hePercent_1'),
        // Tank group 2
        ColumnMapping(
          sourceColumn: 'cylinder size (2) [l]',
          targetField: 'tankVolume_2',
        ),
        ColumnMapping(
          sourceColumn: 'startpressure (2) [bar]',
          targetField: 'startPressure_2',
        ),
        ColumnMapping(
          sourceColumn: 'endpressure (2) [bar]',
          targetField: 'endPressure_2',
        ),
        ColumnMapping(sourceColumn: 'o2 (2) [%]', targetField: 'o2Percent_2'),
        ColumnMapping(sourceColumn: 'he (2) [%]', targetField: 'hePercent_2'),
        // Tank group 3
        ColumnMapping(
          sourceColumn: 'cylinder size (3) [l]',
          targetField: 'tankVolume_3',
        ),
        ColumnMapping(
          sourceColumn: 'startpressure (3) [bar]',
          targetField: 'startPressure_3',
        ),
        ColumnMapping(
          sourceColumn: 'endpressure (3) [bar]',
          targetField: 'endPressure_3',
        ),
        ColumnMapping(sourceColumn: 'o2 (3) [%]', targetField: 'o2Percent_3'),
        ColumnMapping(sourceColumn: 'he (3) [%]', targetField: 'hePercent_3'),
        // Tank group 4
        ColumnMapping(
          sourceColumn: 'cylinder size (4) [l]',
          targetField: 'tankVolume_4',
        ),
        ColumnMapping(
          sourceColumn: 'startpressure (4) [bar]',
          targetField: 'startPressure_4',
        ),
        ColumnMapping(
          sourceColumn: 'endpressure (4) [bar]',
          targetField: 'endPressure_4',
        ),
        ColumnMapping(sourceColumn: 'o2 (4) [%]', targetField: 'o2Percent_4'),
        ColumnMapping(sourceColumn: 'he (4) [%]', targetField: 'hePercent_4'),
        // Tank group 5
        ColumnMapping(
          sourceColumn: 'cylinder size (5) [l]',
          targetField: 'tankVolume_5',
        ),
        ColumnMapping(
          sourceColumn: 'startpressure (5) [bar]',
          targetField: 'startPressure_5',
        ),
        ColumnMapping(
          sourceColumn: 'endpressure (5) [bar]',
          targetField: 'endPressure_5',
        ),
        ColumnMapping(sourceColumn: 'o2 (5) [%]', targetField: 'o2Percent_5'),
        ColumnMapping(sourceColumn: 'he (5) [%]', targetField: 'hePercent_5'),
        // Tank group 6
        ColumnMapping(
          sourceColumn: 'cylinder size (6) [l]',
          targetField: 'tankVolume_6',
        ),
        ColumnMapping(
          sourceColumn: 'startpressure (6) [bar]',
          targetField: 'startPressure_6',
        ),
        ColumnMapping(
          sourceColumn: 'endpressure (6) [bar]',
          targetField: 'endPressure_6',
        ),
        ColumnMapping(sourceColumn: 'o2 (6) [%]', targetField: 'o2Percent_6'),
        ColumnMapping(sourceColumn: 'he (6) [%]', targetField: 'hePercent_6'),
      ],
    ),
    'dive_profile': FieldMapping(
      name: 'Subsurface Dive Profile',
      sourceApp: SourceApp.subsurface,
      columns: [
        ColumnMapping(sourceColumn: 'dive number', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'time', targetField: 'time'),
        ColumnMapping(
          sourceColumn: 'sample time (min)',
          targetField: 'sampleTime',
        ),
        ColumnMapping(
          sourceColumn: 'sample depth (m)',
          targetField: 'sampleDepth',
        ),
        ColumnMapping(
          sourceColumn: 'sample temperature (C)',
          targetField: 'sampleTemperature',
        ),
        ColumnMapping(
          sourceColumn: 'sample pressure (bar)',
          targetField: 'samplePressure',
        ),
        ColumnMapping(
          sourceColumn: 'sample heartrate (bpm)',
          targetField: 'sampleHeartRate',
        ),
      ],
    ),
  },
  expectedUnits: UnitSystem.metric,
  supportedEntities: {
    ImportEntityType.dives,
    ImportEntityType.sites,
    ImportEntityType.tags,
    ImportEntityType.buddies,
  },
);

// ======================== 2. MacDive ========================

const _macdive = CsvPreset(
  id: 'macdive',
  name: 'MacDive',
  source: PresetSource.builtIn,
  sourceApp: SourceApp.macdive,
  signatureHeaders: [
    'Dive No',
    'Date',
    'Time',
    'Location',
    'Max. Depth',
    'Avg. Depth',
    'Bottom Time',
    'Water Temp',
    'Air Temp',
    'Visibility',
    'Dive Type',
    'Rating',
    'Notes',
    'Buddy',
    'Dive Master',
  ],
  mappings: {
    'primary': FieldMapping(
      name: 'MacDive Default',
      sourceApp: SourceApp.macdive,
      columns: [
        ColumnMapping(sourceColumn: 'Dive No', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Time', targetField: 'time'),
        ColumnMapping(sourceColumn: 'Location', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'Max. Depth', targetField: 'maxDepth'),
        ColumnMapping(sourceColumn: 'Avg. Depth', targetField: 'avgDepth'),
        ColumnMapping(
          sourceColumn: 'Bottom Time',
          targetField: 'duration',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(sourceColumn: 'Water Temp', targetField: 'waterTemp'),
        ColumnMapping(sourceColumn: 'Air Temp', targetField: 'airTemp'),
        ColumnMapping(
          sourceColumn: 'Visibility',
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(
          sourceColumn: 'Dive Type',
          targetField: 'diveType',
          transform: ValueTransform.diveTypeMap,
        ),
        ColumnMapping(
          sourceColumn: 'Rating',
          targetField: 'rating',
          transform: ValueTransform.ratingScale,
        ),
        ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
        ColumnMapping(sourceColumn: 'Buddy', targetField: 'buddy'),
        ColumnMapping(sourceColumn: 'Dive Master', targetField: 'diveMaster'),
      ],
    ),
  },
  supportedEntities: {
    ImportEntityType.dives,
    ImportEntityType.sites,
    ImportEntityType.buddies,
  },
);

// ======================== 3. Diving Log ========================

const _divingLog = CsvPreset(
  id: 'diving_log',
  name: 'Diving Log',
  source: PresetSource.builtIn,
  sourceApp: SourceApp.divingLog,
  signatureHeaders: [
    'DiveDate',
    'DiveTime',
    'DiveSite',
    'MaxDepth',
    'Duration',
    'AirTemp',
    'WaterTemp',
    'Visibility',
    'Notes',
    'Buddy',
    'StartPressure',
    'EndPressure',
  ],
  mappings: {
    'primary': FieldMapping(
      name: 'Diving Log Default',
      sourceApp: SourceApp.divingLog,
      columns: [
        ColumnMapping(sourceColumn: 'DiveDate', targetField: 'date'),
        ColumnMapping(sourceColumn: 'DiveTime', targetField: 'time'),
        ColumnMapping(sourceColumn: 'DiveSite', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'MaxDepth', targetField: 'maxDepth'),
        ColumnMapping(
          sourceColumn: 'Duration',
          targetField: 'duration',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(sourceColumn: 'AirTemp', targetField: 'airTemp'),
        ColumnMapping(sourceColumn: 'WaterTemp', targetField: 'waterTemp'),
        ColumnMapping(
          sourceColumn: 'Visibility',
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
        ColumnMapping(sourceColumn: 'Buddy', targetField: 'buddy'),
        ColumnMapping(
          sourceColumn: 'StartPressure',
          targetField: 'startPressure_1',
        ),
        ColumnMapping(
          sourceColumn: 'EndPressure',
          targetField: 'endPressure_1',
        ),
      ],
    ),
  },
  supportedEntities: {
    ImportEntityType.dives,
    ImportEntityType.sites,
    ImportEntityType.buddies,
  },
);

// ======================== 4. DiveMate ========================

const _diveMate = CsvPreset(
  id: 'divemate',
  name: 'DiveMate',
  source: PresetSource.builtIn,
  sourceApp: SourceApp.diveMate,
  signatureHeaders: [
    'Dive No.',
    'Date/Time',
    'Location',
    'Max Depth',
    'Duration',
    'Water Temperature',
    'Air Temperature',
    'Visibility',
    'Notes',
    'Buddy',
    'Rating',
  ],
  mappings: {
    'primary': FieldMapping(
      name: 'DiveMate Default',
      sourceApp: SourceApp.diveMate,
      columns: [
        ColumnMapping(sourceColumn: 'Dive No.', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'Date/Time', targetField: 'dateTime'),
        ColumnMapping(sourceColumn: 'Location', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
        ColumnMapping(
          sourceColumn: 'Duration',
          targetField: 'duration',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(
          sourceColumn: 'Water Temperature',
          targetField: 'waterTemp',
        ),
        ColumnMapping(sourceColumn: 'Air Temperature', targetField: 'airTemp'),
        ColumnMapping(
          sourceColumn: 'Visibility',
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
        ColumnMapping(sourceColumn: 'Buddy', targetField: 'buddy'),
        ColumnMapping(
          sourceColumn: 'Rating',
          targetField: 'rating',
          transform: ValueTransform.ratingScale,
        ),
      ],
    ),
  },
  supportedEntities: {
    ImportEntityType.dives,
    ImportEntityType.sites,
    ImportEntityType.buddies,
  },
);

// ======================== 5. Garmin Connect ========================

const _garminConnect = CsvPreset(
  id: 'garmin_connect',
  name: 'Garmin Connect',
  source: PresetSource.builtIn,
  sourceApp: SourceApp.garminConnect,
  signatureHeaders: [
    'Date',
    'Activity Type',
    'Max Depth',
    'Avg Depth',
    'Bottom Time',
    'Water Temperature',
  ],
  matchThreshold: 0.7,
  mappings: {
    'primary': FieldMapping(
      name: 'Garmin Connect Default',
      sourceApp: SourceApp.garminConnect,
      columns: [
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(
          sourceColumn: 'Activity Type',
          targetField: 'diveType',
          transform: ValueTransform.diveTypeMap,
        ),
        ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
        ColumnMapping(sourceColumn: 'Avg Depth', targetField: 'avgDepth'),
        ColumnMapping(
          sourceColumn: 'Bottom Time',
          targetField: 'duration',
          transform: ValueTransform.hmsToSeconds,
        ),
        ColumnMapping(
          sourceColumn: 'Water Temperature',
          targetField: 'waterTemp',
        ),
      ],
    ),
  },
  supportedEntities: {ImportEntityType.dives},
);

// ======================== 6. Shearwater Cloud ========================

const _shearwater = CsvPreset(
  id: 'shearwater_cloud',
  name: 'Shearwater Cloud',
  source: PresetSource.builtIn,
  sourceApp: SourceApp.shearwater,
  signatureHeaders: [
    'Dive Number',
    'Date',
    'Max Depth',
    'Avg Depth',
    'Duration',
    'Water Temp',
    'GF Low',
    'GF High',
  ],
  mappings: {
    'primary': FieldMapping(
      name: 'Shearwater Cloud Default',
      sourceApp: SourceApp.shearwater,
      columns: [
        ColumnMapping(sourceColumn: 'Dive Number', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
        ColumnMapping(sourceColumn: 'Avg Depth', targetField: 'avgDepth'),
        ColumnMapping(
          sourceColumn: 'Duration',
          targetField: 'duration',
          transform: ValueTransform.hmsToSeconds,
        ),
        ColumnMapping(sourceColumn: 'Water Temp', targetField: 'waterTemp'),
        ColumnMapping(sourceColumn: 'GF Low', targetField: 'gfLow'),
        ColumnMapping(sourceColumn: 'GF High', targetField: 'gfHigh'),
      ],
    ),
  },
  supportedEntities: {ImportEntityType.dives},
);

// ======================== 7. Submersion (native roundtrip) ========================

/// Submersion's own dives CSV (`CsvExportService.generateDivesCsvContent`).
///
/// Headers come from [DiveCsvColumns], the constants the export writes, so
/// the two cannot drift apart (#1814). [DiveCsvColumns.location] is display
/// text and stays unmapped; the site city, island, region and country
/// columns carry the same data. Custom fields come from the
/// [DiveCsvColumns.customFields] JSON column when a cell is readable; the
/// per-key `custom:<key>` columns need no mapping, since the transformer
/// reads every such column, and serve older exports without it.
const _submersionNative = CsvPreset(
  id: 'submersion_native',
  name: 'Submersion',
  source: PresetSource.builtIn,
  sourceApp: SourceApp.submersion,
  signatureHeaders: DiveCsvColumns.fixed,
  matchThreshold: 0.5,
  mappings: {
    'primary': FieldMapping(
      name: 'Submersion Native',
      sourceApp: SourceApp.submersion,
      columns: [
        ColumnMapping(
          sourceColumn: DiveCsvColumns.diveNumber,
          targetField: 'diveNumber',
        ),
        ColumnMapping(sourceColumn: DiveCsvColumns.name, targetField: 'name'),
        ColumnMapping(sourceColumn: DiveCsvColumns.date, targetField: 'date'),
        ColumnMapping(sourceColumn: DiveCsvColumns.time, targetField: 'time'),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.site,
          targetField: 'siteName',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.maxDepth,
          targetField: 'maxDepth',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.avgDepth,
          targetField: 'avgDepth',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.bottomTime,
          targetField: 'duration',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.runtime,
          targetField: 'runtime',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.waterTemp,
          targetField: 'waterTemp',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.airTemp,
          targetField: 'airTemp',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.visibility,
          targetField: 'visibilityMeters',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.visibilityRating,
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.diveType,
          targetField: 'diveTypeIds',
        ),
        ColumnMapping(sourceColumn: DiveCsvColumns.buddy, targetField: 'buddy'),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.diveMaster,
          targetField: 'diveMaster',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.rating,
          targetField: 'rating',
        ),
        // Single-tank export: the flat fields keep pressures even when the
        // tank has no volume, which the numbered tank groups would drop.
        ColumnMapping(
          sourceColumn: DiveCsvColumns.startPressure,
          targetField: 'startPressure',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.endPressure,
          targetField: 'endPressure',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.tankVolume,
          targetField: 'tankVolume',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.o2Percent,
          targetField: 'o2Percent',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.hePercent,
          targetField: 'hePercent',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.diveComputer,
          targetField: 'diveComputerModel',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.serialNumber,
          targetField: 'diveComputerSerial',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.firmwareVersion,
          targetField: 'diveComputerFirmware',
        ),
        ColumnMapping(sourceColumn: DiveCsvColumns.notes, targetField: 'notes'),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.windSpeed,
          targetField: 'windSpeed',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.windDirection,
          targetField: 'windDirection',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.cloudCover,
          targetField: 'cloudCover',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.precipitation,
          targetField: 'precipitation',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.humidity,
          targetField: 'humidity',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.weatherDescription,
          targetField: 'weatherDescription',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.siteCity,
          targetField: 'siteCity',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.siteRegion,
          targetField: 'siteRegion',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.siteCountry,
          targetField: 'siteCountry',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.siteIsland,
          targetField: 'siteIsland',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.customFields,
          targetField: 'customFields',
        ),
      ],
    ),
  },
  supportedEntities: {
    ImportEntityType.dives,
    ImportEntityType.sites,
    ImportEntityType.buddies,
    ImportEntityType.diveTypes,
  },
);
