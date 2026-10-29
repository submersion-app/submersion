import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/data/repositories/side_trip_repository.dart';
import 'package:submersion/features/trips/presentation/helpers/side_trip_delete_lines.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// What a delete confirmation says about side trips and their dives (issue
/// #3658): every profile's side trips count, a hidden larger trip is not
/// named, and a trip deleted along with its larger trip says nothing.
void main() {
  late AppDatabase db;
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> trip(String id, {String? parent, String? owner}) =>
      db.customStatement(
        'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
        'parent_trip_id, created_at, updated_at) '
        'VALUES (?, ?, ?, 0, 0, ?, 0, 0)',
        [id, owner, id, parent],
      );

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 0, 0), ('other', 'Other', 0, 0)",
    );
    await trip('P', owner: 'me');
    await trip('S', parent: 'P', owner: 'me');
    await trip('Hidden', parent: 'P', owner: 'other');
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> lines(List<String> ids) =>
      sideTripDeleteLines(l10n, SideTripRepository(), ids, diverId: 'me');

  test("one larger trip counts every profile's side trips", () async {
    expect(await lines(['P']), ['Its 2 side trips become trips of their own.']);
  });

  test('one side trip names its larger trip', () async {
    expect(await lines(['S']), ['Its dives go back to P.']);
  });

  test('a side trip deleted with its larger trip says nothing more', () async {
    expect(await lines(['P', 'S']), ['1 side trip becomes a trip of its own.']);
  });

  test('several side trips use the general line', () async {
    await trip('S2', parent: 'P', owner: 'me');
    expect(await lines(['S', 'S2']), [
      'Dives on deleted side trips go back to their larger trips.',
    ]);
  });

  test('a larger trip the profile cannot see is not named', () async {
    await trip('Theirs', owner: 'other');
    await trip('Mine', parent: 'Theirs', owner: 'me');
    expect(await lines(['Mine']), [
      'Dives on deleted side trips go back to their larger trips.',
    ]);
  });
}
