import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/presentation/editing/instructor_card_editor.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The certification page's values a sitting edits, and the rules its form
/// keeps (issue #4527, phase 3).

final String _details = CertificationCardId.details.name;
final String _dates = CertificationCardId.dates.name;
final String _instructor = CertificationCardId.instructor.name;
final String _cardPhotos = CertificationCardId.cardPhotos.name;
final String _notes = CertificationCardId.notes.name;

const Object _keep = Object();

T? _or<T>(Object? value, T? kept) =>
    identical(value, _keep) ? kept : value as T?;

/// [c] with the given values, every other one kept. [Certification.copyWith]
/// cannot clear a value, so the fields build the certification whole, as
/// the old edit form's save did.
Certification _with(
  Certification c, {
  String? name,
  String? agency,
  Object? level = _keep,
  List<CertificationCredential>? additionalCredentials,
  Object? cardNumber = _keep,
  Object? issueDate = _keep,
  Object? expiryDate = _keep,
  Object? instructorName = _keep,
  Object? instructorNumber = _keep,
  Object? instructorId = _keep,
  Object? photoFront = _keep,
  Object? photoBack = _keep,
  String? notes,
}) => Certification(
  id: c.id,
  diverId: c.diverId,
  buddyId: c.buddyId,
  name: name ?? c.name,
  agency: agency ?? c.agency,
  level: _or<String>(level, c.level),
  additionalCredentials: additionalCredentials ?? c.additionalCredentials,
  cardNumber: _or<String>(cardNumber, c.cardNumber),
  issueDate: _or<DateTime>(issueDate, c.issueDate),
  expiryDate: _or<DateTime>(expiryDate, c.expiryDate),
  instructorName: _or<String>(instructorName, c.instructorName),
  instructorNumber: _or<String>(instructorNumber, c.instructorNumber),
  instructorId: _or<String>(instructorId, c.instructorId),
  courseId: c.courseId,
  cardId: c.cardId,
  photoFront: _or<Uint8List>(photoFront, c.photoFront),
  photoBack: _or<Uint8List>(photoBack, c.photoBack),
  cardImagesLoaded: c.cardImagesLoaded,
  notes: notes ?? c.notes,
  createdAt: c.createdAt,
  updatedAt: c.updatedAt,
);

/// A blank optional value is stored as none, as the form stores it.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _sameText(String? a, String? b) => _orNone(a) == _orNone(b);

/// Every (agency, level) the card grants, the first being the row's own
/// agency and level, as the form's rows show them. Never empty.
final certificationCredentialsField =
    EditField<Certification, List<CertificationCredential>>(
      id: 'credentials',
      cardId: _details,
      read: (c) => c.credentials,
      write: (c, rows) => _with(
        c,
        agency: rows.first.agency,
        level: rows.first.level,
        additionalCredentials: List.unmodifiable(rows.skip(1)),
      ),
      equals: listEquals,
    );

/// The title: blank derives one from the level, as the form stores it.
final certificationTitleField = EditField<Certification, String>(
  id: 'name',
  cardId: _details,
  read: (c) => c.name,
  write: (c, v) => _with(c, name: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

final certificationCardNumberField = EditField<Certification, String?>(
  id: 'cardNumber',
  cardId: _details,
  read: (c) => c.cardNumber,
  write: (c, v) => _with(c, cardNumber: _orNone(v)),
  equals: _sameText,
);

final certificationIssueDateField = EditField<Certification, DateTime?>(
  id: 'issueDate',
  cardId: _dates,
  read: (c) => c.issueDate,
  write: (c, v) => _with(c, issueDate: v),
);

final certificationExpiryDateField = EditField<Certification, DateTime?>(
  id: 'expiryDate',
  cardId: _dates,
  read: (c) => c.expiryDate,
  write: (c, v) => _with(c, expiryDate: v),
);

/// The instructor: the buddy picked, and the name and number written on the
/// card. One value, so a pick that fills all three is one change.
typedef CertificationInstructor = InstructorValue;

final certificationInstructorField =
    EditField<Certification, CertificationInstructor>(
      id: 'instructor',
      cardId: _instructor,
      read: (c) => (
        id: c.instructorId,
        name: c.instructorName,
        number: c.instructorNumber,
      ),
      write: (c, v) => _with(
        c,
        instructorId: v.id,
        instructorName: _orNone(v.name),
        instructorNumber: _orNone(v.number),
      ),
      equals: (a, b) =>
          a.id == b.id &&
          _sameText(a.name, b.name) &&
          _sameText(a.number, b.number),
    );

bool _sameBytes(Uint8List? a, Uint8List? b) =>
    identical(a, b) || (a != null && b != null && listEquals(a, b));

final certificationPhotoFrontField = EditField<Certification, Uint8List?>(
  id: 'photoFront',
  cardId: _cardPhotos,
  read: (c) => c.photoFront,
  write: (c, v) => _with(c, photoFront: v),
  equals: _sameBytes,
);

final certificationPhotoBackField = EditField<Certification, Uint8List?>(
  id: 'photoBack',
  cardId: _cardPhotos,
  read: (c) => c.photoBack,
  write: (c, v) => _with(c, photoBack: v),
  equals: _sameBytes,
);

final certificationNotesField = EditField<Certification, String>(
  id: 'notes',
  cardId: _notes,
  read: (c) => c.notes,
  write: (c, v) => _with(c, notes: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

/// [rows] with the agency of row [index] set to [agency]. A level that is
/// not one of [agency]'s is dropped, a visible consequence of the diver's
/// own switch, as the form does. A custom agency has no built-in levels,
/// checked by id as well as by [catalog], since one just created is not in
/// the catalog until it reloads (issue #690).
List<CertificationCredential> setCredentialAgency(
  List<CertificationCredential> rows,
  int index,
  String agency, {
  required CertificationCatalog catalog,
}) {
  final level = rows[index].level;
  final customAgency = CertificationAgency.fromId(agency) == null;
  final resetLevel =
      level != null &&
      ((customAgency && CertificationLevel.fromId(level) != null) ||
          !catalog.levelsFor(agency).any((e) => e.id == level));
  return [
    for (var i = 0; i < rows.length; i++)
      i == index
          ? CertificationCredential(
              agency: agency,
              level: resetLevel ? null : level,
            )
          : rows[i],
  ];
}

/// [rows] with row [index] set to [level].
List<CertificationCredential> setCredentialLevel(
  List<CertificationCredential> rows,
  int index,
  String? level,
) => [
  for (var i = 0; i < rows.length; i++)
    i == index
        ? CertificationCredential(agency: rows[i].agency, level: level)
        : rows[i],
];

/// [rows] without row [index]; the card always keeps one, so the last row
/// is not removed. Removing the first promotes the next, as the form does.
List<CertificationCredential> removeCredential(
  List<CertificationCredential> rows,
  int index,
) => rows.length <= 1 ? rows : [...rows.take(index), ...rows.skip(index + 1)];

/// Whether [c] has a title or a level: the form's rule, without which it
/// cannot be saved.
bool certificationHasTitleOrLevel(Certification c) =>
    c.name.trim().isNotEmpty || c.level != null;
