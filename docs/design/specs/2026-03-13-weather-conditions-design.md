# Weather Conditions for Dive Logs

## Problem

Submersion tracks underwater conditions (current, visibility, water type) and a few surface data points (air temp, surface pressure, swell height), but has no dedicated weather logging. Divers often want to record above-water weather conditions -- wind, cloud cover, precipitation, humidity -- both for personal reference and to correlate with dive quality. Entering this data manually is tedious, especially for historical dives.

## Solution

Add weather fields to the dive record with automatic fetching from the Open-Meteo Historical Weather API. Merge the existing "Conditions" section and the new weather fields into a single "Environment" section on both the edit and detail pages, with "Weather" and "Dive Conditions" sub-headers. Auto-fetch weather when saving new dives that have date/time and GPS coordinates; provide a manual "Fetch Weather" button for editing older dives or re-fetching.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Data architecture | Inline fields on `dives` table | Consistent with existing conditions pattern; no joins needed; weather travels with dive in exports/backups |
| Weather API | Open-Meteo Historical Weather API | Free, no API key, open source, historical data going back decades, no rate limit concerns |
| UI organization | Merged "Environment" card | Reduces card count on an already long edit page; groups related environmental data logically |
| Wind direction enum | Reuse `CurrentDirection` | Same compass directions; avoids duplicate enum |
| Wind speed storage | m/s in database | SI base unit; converted to km/h (metric) or knots (imperial) for display |
| Auto-fetch timing | After save completes | Non-blocking; dive saves even if fetch fails; prevents slow saves on bad connections |
| surfacePressure field | Moves to Weather sub-header in UI | Barometric pressure is weather data; DB column stays unchanged |
| airTemp field | Moves to Weather sub-header in UI | Air temperature is weather data; DB column stays unchanged |

## Architecture

### 1. Data Layer

#### Schema Migration

Add 8 nullable columns to the `Dives` table:

```sql
Dives table:
  ... existing columns ...
  + windSpeed          REAL    nullable  -- m/s
  + windDirection      TEXT    nullable  -- enum: north, northEast, east, southEast, south, southWest, west, northWest, variable, none (reuses CurrentDirection.name)
  + cloudCover         TEXT    nullable  -- enum: clear, partlyCloudy, mostlyCloudy, overcast
  + precipitation      TEXT    nullable  -- enum: none, drizzle, lightRain, rain, heavyRain, snow, sleet, hail
  + humidity           REAL    nullable  -- percentage 0-100
  + weatherDescription TEXT    nullable  -- free text summary
  + weatherSource      TEXT    nullable  -- enum: manual, openMeteo (stored as WeatherSource.name)
  + weatherFetchedAt   INTEGER nullable  -- unix timestamp of when API data was fetched
```

#### New Enums

```dart
enum CloudCover {
  clear('Clear'),
  partlyCloudy('Partly Cloudy'),
  mostlyCloudy('Mostly Cloudy'),
  overcast('Overcast');

  final String displayName;
  const CloudCover(this.displayName);
}

enum Precipitation {
  none('None'),
  drizzle('Drizzle'),
  lightRain('Light Rain'),
  rain('Rain'),
  heavyRain('Heavy Rain'),
  snow('Snow'),
  sleet('Sleet'),
  hail('Hail');

  final String displayName;
  const Precipitation(this.displayName);
}
```

Wind direction reuses the existing `CurrentDirection` enum.

```dart
enum WeatherSource {
  manual('Manual'),
  openMeteo('Open-Meteo');

  final String displayName;
  const WeatherSource(this.displayName);
}
```

#### Domain Entity

Add fields to `Dive` entity:

```dart
// Weather fields
final double? windSpeed;        // m/s
final CurrentDirection? windDirection;
final CloudCover? cloudCover;
final Precipitation? precipitation;
final double? humidity;         // 0-100
final String? weatherDescription;
final WeatherSource? weatherSource;
final DateTime? weatherFetchedAt;
```

Update `copyWith`, constructor, and `Equatable` props accordingly.

#### Weather Value Object

An immutable value object used as the return type from the weather service and as the input to the repository when writing fetched data:

```dart
class WeatherData extends Equatable {
  final double? windSpeed;        // m/s
  final CurrentDirection? windDirection;
  final CloudCover? cloudCover;
  final Precipitation? precipitation;
  final double? humidity;
  final double? airTemp;          // celsius
  final double? surfacePressure;  // bar
  final String? description;

  const WeatherData({ ... });
}
```

### 2. Weather Service

#### File Structure

```text
lib/features/weather/
  data/
    services/
      weather_service.dart        -- Open-Meteo HTTP client
      weather_mapper.dart         -- Maps API JSON to WeatherData
    repositories/
      weather_repository.dart     -- Orchestrates fetch + persist
  domain/
    entities/
      weather_data.dart           -- Immutable value object
  presentation/
    providers/
      weather_providers.dart      -- Riverpod providers for fetch state
```

#### Open-Meteo API Details

**Endpoint**: `https://archive-api.open-meteo.com/v1/archive`

**Request parameters**:

- `latitude`, `longitude` -- from dive site
- `start_date`, `end_date` -- dive date (same day for both)
- `hourly` -- `temperature_2m,relative_humidity_2m,precipitation,cloud_cover,wind_speed_10m,wind_direction_10m,surface_pressure,weathercode`

**Response handling**:

- Parse hourly arrays from response
- Select the hour closest to the dive's entry time
- Map API values to domain enums and units

#### Weather Mapper Logic

Mapping Open-Meteo numeric values to domain enums:

**Cloud cover** (API returns 0-100%):

- 0-20% -> `CloudCover.clear`
- 21-50% -> `CloudCover.partlyCloudy`
- 51-80% -> `CloudCover.mostlyCloudy`
- 81-100% -> `CloudCover.overcast`

**Precipitation** (uses both `precipitation` mm/hour and `weathercode`):

First check `weathercode` for precipitation type (WMO Weather interpretation codes):

- Codes 71-77 (snow fall, snow grains) -> `Precipitation.snow`
- Codes 66-67 (freezing rain) -> `Precipitation.sleet`
- Codes 85-86 (snow showers) -> `Precipitation.snow`
- Codes 96-99 (thunderstorm with hail) -> `Precipitation.hail`

If weathercode indicates rain or drizzle (or is not a snow/sleet/hail code), use precipitation amount:

- 0 mm -> `Precipitation.none`
- 0.01-0.5 mm -> `Precipitation.drizzle`
- 0.5-2.5 mm -> `Precipitation.lightRain`
- 2.5-7.5 mm -> `Precipitation.rain`
- 7.5+ mm -> `Precipitation.heavyRain`

**Wind direction** (API returns degrees 0-360):

- 0-22.5, 337.5-360 -> N
- 22.5-67.5 -> NE
- 67.5-112.5 -> E
- etc.

**Surface pressure** (API returns hPa, which equals mbar):

- Convert to bar for storage: `hPa / 1000`

**Wind speed** (API returns km/h by default):

- Convert to m/s for storage: `kmh / 3.6`

#### Weather Description

Generate a human-readable summary from the fetched data. Example: "Partly cloudy, 28C, light breeze from NE". This is constructed by the mapper, not sourced from the API.

### 3. Fetch Flow

#### Auto-Fetch (New Dives Only)

Auto-fetch runs **only** when creating a new dive via `DiveRepository.createDive()`. It does **not** run when editing/updating an existing dive -- the manual "Fetch Weather" button is the mechanism for that case.

1. Diver saves a new dive via `DiveRepository.createDive()`
2. After successful save, the notifier checks: does the dive have a date AND a site with lat/lon AND no weather data already set?
3. If yes, call `WeatherRepository.fetchAndSaveWeather(diveId, lat, lon, dateTime)` in a fire-and-forget manner
4. `WeatherRepository` calls `WeatherService.fetchWeather(lat, lon, date)`
5. `WeatherService` makes HTTP GET to Open-Meteo, returns `WeatherData`
6. `WeatherRepository` updates the dive record with weather fields + `weatherSource: WeatherSource.openMeteo` + `weatherFetchedAt: now`. Respects the airTemp/surfacePressure overwrite policy (only populate if null).
7. If any step fails (no network, API error, missing coordinates), silently skip -- the dive is already saved

#### Manual Fetch (Edit Page)

1. Diver taps "Fetch Weather" button in the Environment section
2. If any weather field is already populated, show a confirmation dialog: "Replace existing weather data with fetched data?" with Cancel/Replace actions. If all weather fields are empty, skip confirmation.
3. Provider state transitions to loading (button shows spinner)
4. `WeatherService.fetchWeather(lat, lon, date)` is called
5. On success: form fields are populated with fetched values (overwrites all weather fields), provider state becomes success
6. On failure: snackbar with error message ("No internet connection" or "Weather data unavailable for this date"), provider state becomes error
7. Diver can edit any populated field before saving
8. On save, `weatherSource` is set to `WeatherSource.openMeteo` if fetched (even if diver edited values afterward), `WeatherSource.manual` if all fields were hand-entered without ever fetching

#### airTemp and surfacePressure Overwrite Policy

When auto-fetch or manual fetch populates weather data:

- `airTemp`: only populate if the field is currently null. A dive computer or manual entry is likely more accurate than a weather station reading.
- `surfacePressure`: only populate if the field is currently null. Same rationale -- dive computer barometric readings are more precise.

### 4. UI Changes

#### Edit Page -- Environment Section

Rename `_buildConditionsSection` to `_buildEnvironmentSection`. Structure:

```text
Card: "Environment"
  Header row: title + "Fetch Weather" button (right-aligned)

  Sub-header: "Weather"
    Row: [Air Temp] [Humidity]
    Row: [Wind Speed] [Wind Direction dropdown]
    Row: [Barometric Pressure] [Cloud Cover dropdown]
    Row: [Precipitation dropdown]
    Full-width: [Weather Description text field]

  Divider

  Sub-header: "Dive Conditions"
    Row: [Water Temp] [Visibility dropdown]   (water temp moves here from above)
    Row: [Water Type dropdown]
    Row: [Current Direction] [Current Strength]
    Row: [Swell Height] [Altitude]
    Row: [Entry Method] [Exit Method]
```

The "Fetch Weather" button:

- Enabled when dive has a date and site with coordinates
- Shows a cloud-download icon with "Fetch Weather" text
- Shows a CircularProgressIndicator while fetching
- Disabled with tooltip "Add a date and dive site first" when prerequisites are missing

#### Detail Page -- Environment Section

Rename `_buildConditionsSection` to `_buildEnvironmentSection`. Same merged structure with sub-headers.

- Weather sub-header shows all populated weather fields
- "via Open-Meteo" attribution text when `weatherSource == WeatherSource.openMeteo`
- Dive Conditions sub-header shows existing condition fields (unchanged logic)

#### Unit Formatting

Add to `UnitFormatter`:

```dart
String formatWindSpeed(double? metersPerSecond)
// Metric: converts m/s to km/h, displays as "XX km/h"
// Imperial: converts m/s to knots, displays as "XX kts"

String get windSpeedSymbol
// Returns "km/h" or "kts"
```

### 5. Export/Import/Sync Impact

#### CSV Export

Add weather columns to CSV export. New columns: `windSpeed`, `windDirection`, `cloudCover`, `precipitation`, `humidity`, `weatherDescription`.

#### CSV Import

Map weather columns during import. Unknown values gracefully ignored.

#### Excel Export

Add weather columns to Excel export (`excel_export_service.dart`). Same columns as CSV.

#### UDDF Export

Map weather fields to UDDF `<surfaceweather>` element if the format supports it. If not, include as custom metadata.

#### Universal Import

Update the field mapping engine (`lib/features/universal_import/`) to recognize weather columns. Add weather fields to the mappable field list so the import wizard can map them from arbitrary CSV/source columns.

#### Sync Serializer

Include all 8 new weather columns in the sync data serializer (`lib/core/services/sync/`) so weather data round-trips correctly through device sync. Omitting these fields would silently drop weather data during sync.

### 6. Localization

New string keys needed:
- Section/sub-header labels: `environment_section_weather`, `environment_section_diveConditions`
- Field labels: `windSpeed`, `windDirection`, `cloudCover`, `precipitation`, `humidity`, `weatherDescription`
- Enum display names for `CloudCover` and `Precipitation` values
- Fetch button: `fetchWeather`, `fetchingWeather`, `weatherFetched`, `fetchWeatherNoConnection`, `fetchWeatherUnavailable`, `fetchWeatherHint`
- Attribution: `weatherSourceOpenMeteo`

### 7. Error Handling

| Scenario | Behavior |
|----------|----------|
| No internet (auto-fetch) | Silent skip, dive saves normally |
| No internet (manual fetch) | Snackbar: "No internet connection" |
| API error (auto-fetch) | Silent skip, log warning |
| API error (manual fetch) | Snackbar: "Weather data unavailable" |
| No coordinates available | Fetch button disabled with tooltip |
| No date set | Fetch button disabled with tooltip |
| Date too recent for historical API | Snackbar: "Weather data not yet available for this date". Historical API typically has data up to 5 days ago. No forecast API fallback in v1 -- diver can manually enter or re-fetch later. |
| API response missing fields | Populate what's available, leave rest null |
