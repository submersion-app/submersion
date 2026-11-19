import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/instructor_card_editor.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The certification page's fields keep the edit form's rules (issue
/// #4527, phase 3).
void main() {
  final catalog = CertificationCatalog.builtInOnly;
  const padiOw = CertificationCredential(agency: 'padi', level: 'openWater');
  const cmas = CertificationCredential(agency: 'cmas', level: 'cmas1Star');

  Certification cert() => Certification(
    id: 'c1',
    name: '',
    agency: 'padi',
    level: 'openWater',
    additionalCredentials: const [cmas],
    cardNumber: '123',
    instructorName: 'Jo',
    instructorNumber: '42',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  test('changing an agency drops a level not the agency\'s', () {
    final rows = setCredentialAgency(
      [padiOw],
      0,
      'custom-agency',
      catalog: catalog,
    );
    expect(rows.single.agency, 'custom-agency');
    expect(rows.single.level, isNull);
  });

  test('changing to an agency that has the level keeps it', () {
    final level = catalog.levelsFor('ssi').first.id;
    final rows = setCredentialAgency(
      [CertificationCredential(agency: 'padi', level: level)],
      0,
      'ssi',
      catalog: catalog,
    );
    expect(rows.single.level, level);
  });

  test('removing the first credential promotes the next', () {
    final rows = removeCredential([padiOw, cmas], 0);
    expect(rows, [cmas]);
  });

  test('the last credential is not removed', () {
    expect(removeCredential([padiOw], 0), [padiOw]);
  });

  test('the credentials field writes row 0 as the agency and level', () {
    final session = EditSession(cert())
      ..set(certificationCredentialsField, [cmas]);
    final working = session.working;
    expect(working.agency, 'cmas');
    expect(working.level, 'cmas1Star');
    expect(working.additionalCredentials, isEmpty);
    expect(session.changedCardIds, {'details'});
  });

  test('a title or a level is required', () {
    final noLevel = EditSession(cert())
      ..set(certificationCredentialsField, [
        const CertificationCredential(agency: 'padi'),
      ]);
    expect(certificationHasTitleOrLevel(noLevel.working), isFalse);
    noLevel.set(certificationTitleField, 'My card');
    expect(certificationHasTitleOrLevel(noLevel.working), isTrue);
    expect(certificationHasTitleOrLevel(cert()), isTrue);
  });

  test('picking an instructor fills the name and number', () {
    final buddy = Buddy(
      id: 'b1',
      name: 'Alex',
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
    final picked = instructorPicked(buddy, null, (
      id: null,
      name: 'Jo',
      number: '42',
    ));
    expect(picked, (id: 'b1', name: 'Alex', number: null));
  });

  test('clearing the instructor keeps the text', () {
    final cleared = instructorPicked(null, null, (
      id: 'b1',
      name: 'Alex',
      number: '9',
    ));
    expect(cleared, (id: null, name: 'Alex', number: '9'));
  });

  test('one instructor pick is one change of Instructor', () {
    final session = EditSession(cert())
      ..set(certificationInstructorField, (id: 'b1', name: 'Alex', number: ''));
    final working = session.working;
    expect(working.instructorId, 'b1');
    expect(working.instructorName, 'Alex');
    expect(working.instructorNumber, isNull);
    expect(session.changedCardIds, {'instructor'});
  });

  test('blank text stores none', () {
    final session = EditSession(cert())..set(certificationCardNumberField, ' ');
    expect(session.working.cardNumber, isNull);
  });
}
