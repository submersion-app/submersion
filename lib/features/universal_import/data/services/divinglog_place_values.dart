import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Reads the detail columns of Diving Log's `Place` table into the typed
/// values a site carries.
///
/// None of them are stored the way the column names suggest, which is why
/// the site lost them all (#2271): `Water` is an integer code, `Altitude` is
/// free text, `Rating` is a star count where 0 means unrated, and
/// `Difficulty` is a label that only partly matches our levels. Everything
/// here returns null for a value it cannot read, so the importer omits the
/// field rather than storing a guess.
abstract final class DivingLogPlaceValues {
  /// The `Water` code: 1 salt, 2 fresh, 3 brackish.
  ///
  /// Settled against the reporter's logbook, where every sea site is 1 and
  /// the one dive in Barracuda Lake, a brackish lake in Coron, is 3. Fresh
  /// is the remaining code. 0 is the format's unset value.
  static WaterType? waterType(int? code) => switch (code) {
    1 => WaterType.salt,
    2 => WaterType.fresh,
    3 => WaterType.brackish,
    _ => null,
  };

  /// The `Difficulty` label, read case-insensitively.
  ///
  /// The real file holds Beginner, Intermediate and Advanced, which match
  /// our levels, plus Easy and Novice, which have no level of their own and
  /// read as beginner. Anything else is left for the caller to keep as text.
  static SiteDifficulty? difficulty(String? label) =>
      switch (label?.trim().toLowerCase()) {
        'beginner' || 'easy' || 'novice' => SiteDifficulty.beginner,
        'intermediate' => SiteDifficulty.intermediate,
        'advanced' => SiteDifficulty.advanced,
        'technical' => SiteDifficulty.technical,
        _ => null,
      };

  /// The `Rating` star count on the 1 to 5 scale a site uses.
  ///
  /// 0 is how the format records "not rated", not a zero-star review, so it
  /// is dropped along with null.
  static double? rating(int? stars) =>
      stars == null || stars <= 0 ? null : stars.clamp(1, 5).toDouble();

  static final _altitude = RegExp(
    r'^(-?\d+(?:\.\d+)?)\s*(m|meters?|metres?|ft|feet|foot)?$',
  );

  /// The `Altitude` text in metres.
  ///
  /// The column is TEXT: the real file writes `Sea Level`, which is an
  /// explicit 0 m. A number with a metre or foot unit is converted, and a
  /// bare number is metres, the unit this format stores depths in. A numeric
  /// 0 reads as unset, following the format's zero-for-empty habit; only the
  /// `Sea Level` text says the site is at zero.
  static double? altitudeMeters(String? raw) {
    final text = raw?.trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text == 'sea level') return 0;
    final match = _altitude.firstMatch(text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null || value == 0) return null;
    final unit = match.group(2);
    return unit != null && unit.startsWith('f')
        ? DepthUnit.feet.convert(value, DepthUnit.meters)
        : value;
  }
}
