import 'dart:convert';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import 'package:submersion/core/services/geocoding/sea_area_index.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Loads the bundled ocean and sea table.
///
/// The asset is about 1.3 MB, so it is parsed on first use and kept for the
/// process: a backfill run over a whole logbook pays for it once, and a
/// diver who never touches a coordinate never pays at all.
abstract final class SeaAreaService {
  static const String assetPath = 'assets/data/sea_areas.json';

  static final _log = LoggerService.forClass(SeaAreaService);

  static SeaAreaIndex? _index;

  /// Whether a load has finished, successfully or not.
  ///
  /// A failed read sets this too. The asset is bundled and immutable for
  /// the life of the process, so a read that failed once fails every time,
  /// and remembering that is what stops a backfill over a whole logbook
  /// from retrying a 1.3 MB read, and logging the same warning, once per
  /// site.
  static bool _loaded = false;

  /// The read in progress, so concurrent callers share one parse rather
  /// than each decoding the asset. Cleared once it settles; [_loaded] is
  /// what makes the result stick.
  static Future<SeaAreaIndex?>? _inFlight;

  /// The shipped index, or null when the asset is missing or unreadable.
  ///
  /// A missing table is not worth failing a geocode over: the caller simply
  /// gets no body of water, exactly as before this table existed.
  static Future<SeaAreaIndex?> load() {
    // Built here rather than held as a completed future, so it belongs to
    // the caller's zone. A future created in one zone and awaited inside a
    // fakeAsync zone never resolves there.
    if (_loaded) return Future<SeaAreaIndex?>.value(_index);
    return _inFlight ??= _read();
  }

  static Future<SeaAreaIndex?> _read() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final index = SeaAreaIndex.fromJson(json);
      _index = index;
      _log.info('Loaded ${index.areas.length} sea areas');
    } catch (e, stackTrace) {
      _index = null;
      _log.warning(
        'Sea area table unavailable, body of water will be left empty: $e',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _loaded = true;
      _inFlight = null;
    }
    return _index;
  }

  /// Adds the table's attribution to the app's license page.
  ///
  /// IHO Sea Areas is CC-BY 4.0, so redistributing it inside the app means
  /// carrying the credit with it. Called once from `main()`.
  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(
        <String>['IHO Sea Areas'],
        '''
Ocean and sea boundaries (assets/data/sea_areas.json) are derived from
IHO Sea Areas version 3, published by the Flanders Marine Institute and
licensed under Creative Commons Attribution 4.0 (CC-BY 4.0).

The underlying limits are from "Limits of Oceans & Seas, Special
Publication No. 23", International Hydrographic Organization, 1953.

Flanders Marine Institute (2018). IHO Sea Areas, version 3.
Available online at https://www.marineregions.org/
https://doi.org/10.14284/323

The bundled copy is simplified for size; see
scripts/sea_area_harvester.py for exactly how it was derived.''',
      );
    });
  }

  /// Stands in for a completed load. Passing null models an unreadable
  /// asset, which callers must treat as "no body of water", not an error.
  @visibleForTesting
  static void setIndexForTesting(SeaAreaIndex? index) {
    _index = index;
    _loaded = true;
    _inFlight = null;
  }

  @visibleForTesting
  static void resetCacheForTesting() {
    _index = null;
    _loaded = false;
    _inFlight = null;
  }
}
