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
class SeaAreaService {
  SeaAreaService._();

  static const String assetPath = 'assets/data/sea_areas.json';

  static final _log = LoggerService.forClass(SeaAreaService);

  static SeaAreaIndex? _cache;
  static Future<SeaAreaIndex?>? _pending;

  /// The shipped index, or null when the asset is missing or unreadable.
  ///
  /// A missing table is not worth failing a geocode over: the caller simply
  /// gets no body of water, exactly as before this table existed.
  static Future<SeaAreaIndex?> load() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    // Concurrent callers share one parse rather than each decoding 1.3 MB.
    return _pending ??= _load();
  }

  static Future<SeaAreaIndex?> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final index = SeaAreaIndex.fromJson(json);
      _cache = index;
      _log.info('Loaded ${index.areas.length} sea areas');
      return index;
    } catch (e, stackTrace) {
      _log.warning(
        'Sea area table unavailable, body of water will be left empty: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      _pending = null;
    }
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

  @visibleForTesting
  static void setIndexForTesting(SeaAreaIndex? index) {
    _cache = index;
    _pending = null;
  }

  @visibleForTesting
  static void resetCacheForTesting() {
    _cache = null;
    _pending = null;
  }
}
