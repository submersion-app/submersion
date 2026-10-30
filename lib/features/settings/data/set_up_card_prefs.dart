import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

/// The "Set up this device" card's own state (issue #3482): whether the
/// diver hid it and whether they skipped the photo step. Both are per
/// device. Everything else the card shows is derived from the features.
class SetUpCardPrefs {
  SetUpCardPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String hiddenKey = 'setup_card_hidden';
  static const String photosSkippedKey = 'setup_photos_skipped';

  /// Set once the upgrade seed has run (or found nothing to do), so a fresh
  /// install is never seeded later, when its wizard creates the first diver.
  static const String seedDoneKey = 'setup_card_seed_done';

  bool get hidden => _prefs.getBool(hiddenKey) ?? false;
  bool get photosSkipped => _prefs.getBool(photosSkippedKey) ?? false;

  Future<void> setHidden(bool value) => _prefs.setBool(hiddenKey, value);

  Future<void> setPhotosSkipped(bool value) =>
      _prefs.setBool(photosSkippedKey, value);

  /// Devices that predate the card start with it hidden and the photo step
  /// settled (the user's decision). Runs once: when neither preference has
  /// been written and the database already holds a diver. A fresh install
  /// (no diver yet) only records that the seed is done. [diverCount] is read
  /// only while the seed is still due.
  Future<void> seedOnce({required Future<int> Function() diverCount}) async {
    if (_prefs.getBool(seedDoneKey) ?? false) return;
    final choiceMade =
        _prefs.containsKey(hiddenKey) || _prefs.containsKey(photosSkippedKey);
    if (!choiceMade && await diverCount() > 0) {
      await setHidden(true);
      await setPhotosSkipped(true);
    }
    await _prefs.setBool(seedDoneKey, true);
  }
}

final _log = LoggerService.forClass(SetUpCardPrefs);

/// The upgrade seed as a startup step: run once the database is open and
/// before the app mounts, so the card's first build reads the seeded values.
/// A failure never blocks startup; the seed is not marked done, so the next
/// launch retries.
Future<void> runSetUpCardSeed(
  SharedPreferences prefs, {
  Future<int> Function()? diverCount,
}) async {
  try {
    await SetUpCardPrefs(
      prefs,
    ).seedOnce(diverCount: diverCount ?? DiverRepository().getDiverCount);
  } catch (e, stackTrace) {
    _log.error(
      'Set up card seed failed; will retry next launch',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
