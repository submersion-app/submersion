import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_fields.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_fill_hours_section.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The dive centre page's fields keep the edit form's rules (issue #4527,
/// phase 3).
void main() {
  final l = AppLocalizationsEn();

  DiveCenter centre() => DiveCenter(
    id: 'dc1',
    name: 'Reef Divers',
    affiliations: const ['PADI', 'SSI'],
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  test('latitude 91 is out of range', () {
    expect(
      diveCenterCoordinateError(l, 91, 0),
      l.diveCenters_validation_invalidLatitude,
    );
    expect(
      diveCenterCoordinateError(l, 0, 181),
      l.diveCenters_validation_invalidLongitude,
    );
    expect(diveCenterCoordinateError(l, 45, 90), isNull);
    expect(diveCenterCoordinatesValid((latitude: 91, longitude: 0)), isFalse);
    expect(diveCenterCoordinatesValid(null), isTrue);
  });

  test('fill hours with only an opening are a problem', () {
    expect(fillHoursProblem(480, null), FillHoursProblem.missingOne);
  });

  test('fill hours with only a closing are a problem', () {
    expect(fillHoursProblem(null, 1020), FillHoursProblem.missingOne);
  });

  test('both fill hours in order are fine', () {
    expect(fillHoursProblem(480, 1020), isNull);
  });

  test('closing at the opening time is a problem', () {
    expect(fillHoursProblem(480, 480), FillHoursProblem.closesBeforeOpens);
  });

  test('closing before opening is a problem', () {
    expect(fillHoursProblem(600, 480), FillHoursProblem.closesBeforeOpens);
  });

  test('affiliations in another order are no change', () {
    final session = EditSession(centre())
      ..set(diveCenterAffiliationsField, ['SSI', 'PADI']);
    expect(session.isDirty, isFalse);
  });

  test('coordinates are one change of Map', () {
    final session = EditSession(centre())
      ..set(diveCenterCoordinatesField, (latitude: 1.0, longitude: 2.0));
    expect(session.changedCardIds, {'map'});
    expect(session.working.latitude, 1.0);
    expect(session.working.longitude, 2.0);
  });

  test('a bad email is invalid', () {
    expect(diveCenterEmailValid('nope'), isFalse);
    expect(diveCenterEmailValid('a@b.co'), isTrue);
    expect(diveCenterEmailValid(null), isTrue);
  });

  test('the address line leaves out its blank parts', () {
    final c = DiveCenter(
      id: 'x',
      name: 'X',
      street: ' 1 Sea St ',
      city: '',
      country: 'Egypt',
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
    expect(diveCenterAddressLine(c), '1 Sea St, Egypt');
  });
}
