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
/// No Flutter imports; usable from the drift worker isolate.
library;

import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart'
    show AllowedArgumentCount, CommonDatabase, SqliteArguments;

/// `unicode_lower(text)`: [text] lower-cased by Dart's `toLowerCase`, the
/// same folding the Dart side of a comparison uses. NULL stays NULL and a
/// number renders as text, as with `LOWER()`.
const String kUnicodeLowerFunction = 'unicode_lower';

/// Registers the app's SQL functions on [db].
void registerAppSqlFunctions(CommonDatabase db) {
  db.createFunction(
    functionName: kUnicodeLowerFunction,
    function: _unicodeLower,
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
  );
}

Object? _unicodeLower(SqliteArguments arguments) {
  final value = arguments[0];
  return switch (value) {
    null => null,
    final String s => s.toLowerCase(),
    final num n => n.toString(),
    // A blob is returned unchanged: no text column here holds one, and
    // guessing at its encoding would be worse than leaving it alone.
    _ => value,
  };
}

extension UnicodeLowerExpression on Expression<String> {
  /// This text lower-cased by [kUnicodeLowerFunction]; the Unicode-aware
  /// replacement for drift's `lower()`, which compiles to `LOWER()`.
  Expression<String> unicodeLower() =>
      FunctionCallExpression<String>(kUnicodeLowerFunction, [this]);
}
