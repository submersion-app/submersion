import 'package:flutter/foundation.dart' show compute;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_parser.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';

const _log = LoggerService('EquipmentCatalogueRefresher');

/// When the last good download happened, in Unix milliseconds. Per device.
const String kEquipmentCatalogueFetchedAtKey = 'equipment_catalogue_fetched_at';

/// How far ahead of this device's clock a catalogue's `generatedAt` may be
/// (time zones and clock drift); a copy dated further ahead is refused.
const Duration kEquipmentCatalogueClockSlack = Duration(days: 2);

/// How long a good download stays fresh.
const Duration kEquipmentCatalogueRefreshInterval = Duration(hours: 24);

/// The catalogue copy to use: the newer of the bundled and downloaded ones
/// by `generatedAt`, the bundled one on a tie, either when the other is
/// missing.
EquipmentCatalogueFile? chooseEquipmentCatalogue(
  EquipmentCatalogueFile? bundled,
  EquipmentCatalogueFile? cached,
) {
  if (bundled == null) return cached;
  if (cached == null) return bundled;
  return cached.generatedAt.isAfter(bundled.generatedAt) ? cached : bundled;
}

/// Downloads a newer equipment catalogue at most once a day (issue #5118).
///
/// Nothing happens in a browser or with the diver's setting off. Only a body
/// that parses as a supported format is kept; anything else (offline, a 404,
/// a malformed or unknown-format file) leaves the copy the app has and is
/// logged, never shown.
class EquipmentCatalogueRefresher {
  EquipmentCatalogueRefresher({
    required Future<String?> Function() fetch,
    required Future<void> Function(String json) writeCache,
    required SharedPreferences prefs,
    required bool Function() enabled,
    required bool isBrowser,
    DateTime Function()? now,
  }) : _fetch = fetch,
       _writeCache = writeCache,
       _prefs = prefs,
       _enabled = enabled,
       _isBrowser = isBrowser,
       _now = now ?? DateTime.now;

  final Future<String?> Function() _fetch;
  final Future<void> Function(String json) _writeCache;
  final SharedPreferences _prefs;
  final bool Function() _enabled;
  final bool _isBrowser;
  final DateTime Function() _now;

  Future<bool>? _running;

  /// Whether a new copy was kept. A call made while one runs (a launch,
  /// then a quick resume) joins it rather than downloading again.
  Future<bool> refreshIfDue() =>
      _running ??= _refreshIfDue().whenComplete(() => _running = null);

  Future<bool> _refreshIfDue() async {
    if (_isBrowser || !_enabled()) return false;
    final last = _prefs.getInt(kEquipmentCatalogueFetchedAtKey);
    final now = _now();
    if (last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last, isUtc: true)) <
            kEquipmentCatalogueRefreshInterval) {
      return false;
    }
    try {
      final body = await _fetch();
      if (body == null) {
        _log.info('No equipment catalogue release is published');
        return false;
      }
      // Parsed off the UI thread: a later catalogue holds thousands of
      // records, and this runs at launch and on resume.
      final parsed = await compute(parseEquipmentCatalogue, body);
      if (parsed == null) {
        _log.warning('Ignored a downloaded equipment catalogue it cannot read');
        return false;
      }
      // A broken release must not replace a working copy: an empty one
      // would hide every suggestion, and one dated ahead would beat every
      // later bundled copy.
      if (parsed.records.isEmpty ||
          parsed.generatedAt.isAfter(now.add(kEquipmentCatalogueClockSlack))) {
        _log.warning('Ignored an empty or future-dated equipment catalogue');
        return false;
      }
      await _writeCache(body);
      await _prefs.setInt(
        kEquipmentCatalogueFetchedAtKey,
        now.millisecondsSinceEpoch,
      );
      return true;
    } on Exception catch (e) {
      _log.warning('Equipment catalogue download failed: $e');
      return false;
    }
  }
}
