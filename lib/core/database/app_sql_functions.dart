/// SQL functions the app registers on every connection it opens.
///
/// SQLite's built-in `LOWER()` folds ASCII letters only: `LOWER('Éponge')`
/// is still `'Éponge'`. Every case-insensitive text match therefore missed
/// a name with a non-ASCII capital, and a find-or-create matcher that
/// lowercased its needle in Dart minted a twin instead (#3032). Full Unicode
/// folding needs the ICU extension, which the bundled SQLite and SQLCipher
/// builds do not ship, so the folding is done by Dart through
/// [kUnicodeLowerFunction].
///
/// A function lives on the connection, not in the file, so it must be
/// registered every time one is opened: [applyConnectionBasics] does it for
/// the main database's connections, the local cache's opener passes
/// [registerAppSqlFunctions] as its `setup`, and so does a test's
/// `NativeDatabase.memory`. A query run on a connection
/// without it fails loudly with "no such function".
///
/// Runs on the drift worker isolate. The tank configuration classifier's
/// imports reach `dart:ui`, so this file needs the Flutter engine's libraries;
/// the worker has them because it runs in the app's process.
library;

import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart'
    show AllowedArgumentCount, CommonDatabase, SqliteArguments;
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/text/fuzzy_match.dart' show foldForSearch;
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_name_key.dart';
import 'package:submersion/features/insights/data/tank_configuration_sql.dart';

/// `unicode_lower(text)`: [text] lower-cased by Dart's `toLowerCase`, the
/// same folding the Dart side of a comparison uses. NULL stays NULL and a
/// number renders as text, as with `LOWER()`.
const String kUnicodeLowerFunction = 'unicode_lower';

/// `search_fold(text)`: [text] lower-cased with common accents stripped, by
/// [foldForSearch], so a search for "jeremie" finds "Jérémie" (#4498). For a
/// search's `LIKE` only, with the needle folded by [foldForSearch] too: an
/// exact match (`=`, `IN`, find-or-create) folds case alone, with
/// [kUnicodeLowerFunction], because "José" and "Jose" can be two people.
/// NULL stays NULL and a number renders as text, as with `LOWER()`.
const String kSearchFoldFunction = 'search_fold';

/// `row_digest(value, ...)`: a hash of its arguments, for telling whether a
/// row changed without carrying the row out of the worker isolate (#3815).
///
/// Comparable only within one connection: Dart seeds its hashes per isolate,
/// so a digest is never stored or compared across a reconnect. SQLite caps a
/// function at 127 arguments.
const String kRowDigestFunction = 'row_digest';

/// `dive_ambient_bar(depth, altitude, surface_pressure, water_type)`: the
/// absolute pressure in bar at `depth` meters of a logged dive, by
/// [DiveEnvironment.forConditions], so the statistics and `Dive.sac` read one
/// pressure model (#3958). NULL with no depth. Take the arguments from
/// `diveAmbientBarSql`, which resolves the dive's effective water type.
const String kDiveAmbientBarFunction = 'dive_ambient_bar';

/// `catalogue_name_key(text)`: a site name reduced to what tells one name
/// from another, by [catalogueNameKey]. It lets one statement find the
/// built-in catalogue's records for many of the diver's site names at once,
/// with the folding done on the worker isolate and not row by row on the
/// UI's. NULL stays NULL.
const String kCatalogueNameKeyFunction = 'catalogue_name_key';

/// Registers the app's SQL functions on [db].
void registerAppSqlFunctions(CommonDatabase db) {
  db.createFunction(
    functionName: kUnicodeLowerFunction,
    function: _unicodeLower,
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
  );
  db.createFunction(
    functionName: kSearchFoldFunction,
    function: _searchFold,
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
  );
  db.createFunction(
    functionName: kRowDigestFunction,
    function: Object.hashAll,
    argumentCount: const AllowedArgumentCount.any(),
    deterministic: true,
  );
  registerTankConfigurationFunctions(db);
  db.createFunction(
    functionName: kCatalogueNameKeyFunction,
    function: _catalogueNameKey,
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
  );
  db.createFunction(
    functionName: kDiveAmbientBarFunction,
    function: _diveAmbientBar,
    argumentCount: const AllowedArgumentCount(4),
    deterministic: true,
  );
}

Object? _catalogueNameKey(SqliteArguments arguments) {
  final value = arguments[0];
  return value == null ? null : catalogueNameKey(value.toString());
}

/// Held once: [_diveAmbientBar] runs for every row of a statement.
final Map<String, WaterType> _waterTypesByName = WaterType.values.asNameMap();

/// A number, or null for anything else: SQLite's affinity lets text into a
/// REAL column, and a throw here would fail the whole statement, not the row.
double? _realOrNull(Object? value) => value is num ? value.toDouble() : null;

Object? _diveAmbientBar(SqliteArguments arguments) {
  final depth = _realOrNull(arguments[0]);
  if (depth == null) return null;
  final environment = DiveEnvironment.forConditions(
    altitudeMeters: _realOrNull(arguments[1]),
    surfacePressureBar: _realOrNull(arguments[2]),
    waterType: _waterTypesByName[arguments[3]],
  );
  return environment.pressureAtDepth(depth);
}

Object? _unicodeLower(SqliteArguments arguments) =>
    _foldText(arguments[0], (s) => s.toLowerCase());

/// [value] through [fold] when it is text, the way `LOWER()` treats its
/// argument: NULL stays NULL and a number renders as text, unfolded.
Object? _foldText(Object? value, String Function(String text) fold) {
  return switch (value) {
    null => null,
    final String s => fold(s),
    final num n => n.toString(),
    // A blob is returned unchanged: no text column here holds one, and
    // guessing at its encoding would be worse than leaving it alone.
    _ => value,
  };
}

Object? _searchFold(SqliteArguments arguments) =>
    _foldText(arguments[0], foldForSearch);

extension UnicodeLowerExpression on Expression<String> {
  /// This text lower-cased by [kUnicodeLowerFunction]; the Unicode-aware
  /// replacement for drift's `lower()`, which compiles to `LOWER()`.
  Expression<String> unicodeLower() =>
      FunctionCallExpression<String>(kUnicodeLowerFunction, [this]);

  /// This text folded by [kSearchFoldFunction]: case and accents, for a
  /// search's `LIKE`. Match it against a needle folded by [foldForSearch].
  Expression<String> searchFold() =>
      FunctionCallExpression<String>(kSearchFoldFunction, [this]);
}
