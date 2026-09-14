import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_participant_names.dart';

/// The legacy scalar fallback is normalized like the junction names: trimmed,
/// and blank treated as nobody. The dive detail page reads the scalar the same
/// way (#1831), so a whitespace-only buddy is not exported as meaningful text.
void main() {
  Dive legacy({String? buddy, String? diveMaster}) => Dive(
    id: 'd',
    dateTime: DateTime(2020, 5, 1),
    buddy: buddy,
    diveMaster: diveMaster,
  );

  test('the scalar fallback is trimmed', () {
    final dive = legacy(buddy: '  Oldbuddy ', diveMaster: '\tOlddm  ');

    expect(dive.resolvedBuddyNames, 'Oldbuddy');
    expect(dive.resolvedDiveMasterNames, 'Olddm');
  });

  test('a blank scalar fallback is nobody', () {
    final dive = legacy(buddy: '   ', diveMaster: '');

    expect(dive.resolvedBuddyNames, isNull);
    expect(dive.resolvedDiveMasterNames, isNull);
  });
}
