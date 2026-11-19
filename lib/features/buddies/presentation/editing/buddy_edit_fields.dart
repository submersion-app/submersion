import 'package:flutter/foundation.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_country_columns.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The buddy page's values a sitting edits, and the rules its form keeps
/// (issue #4527, phase 3). A buddy card's figures (issue #3728) are not
/// among them: only a card writes them.

final String _header = BuddyCardId.header.name;
final String _contact = BuddyCardId.contact.name;
final String _statistics = BuddyCardId.statistics.name;
final String _notes = BuddyCardId.notes.name;

const Object _keep = Object();

T? _or<T>(Object? value, T? kept) =>
    identical(value, _keep) ? kept : value as T?;

/// [b] with the given values, every other one kept. [Buddy.copyWith]
/// cannot clear a value, so the fields build the buddy whole.
Buddy _with(
  Buddy b, {
  String? name,
  Object? email = _keep,
  Object? phone = _keep,
  Object? country = _keep,
  Object? linkedDiverId = _keep,
  Object? photo = _keep,
  Object? photoPath = _keep,
  Object? socialHandle = _keep,
  String? notes,
  bool? isFavorite,
  bool? excludedFromRankings,
}) => Buddy(
  id: b.id,
  diverId: b.diverId,
  linkedDiverId: _or<String>(linkedDiverId, b.linkedDiverId),
  name: name ?? b.name,
  email: _or<String>(email, b.email),
  phone: _or<String>(phone, b.phone),
  country: _or<String>(country, b.country),
  // The save reconciles the code with the country as stored.
  countryCode: b.countryCode,
  certificationLevel: b.certificationLevel,
  certificationAgency: b.certificationAgency,
  certificationTitle: b.certificationTitle,
  photoPath: _or<String>(photoPath, b.photoPath),
  photo: _or<Uint8List>(photo, b.photo),
  notes: notes ?? b.notes,
  isFavorite: isFavorite ?? b.isFavorite,
  excludedFromRankings: excludedFromRankings ?? b.excludedFromRankings,
  createdAt: b.createdAt,
  updatedAt: b.updatedAt,
  cardId: b.cardId,
  socialHandle: _or<String>(socialHandle, b.socialHandle),
  cardDiveCount: b.cardDiveCount,
  cardDivingSince: b.cardDivingSince,
  cardLastDive: b.cardLastDive,
  cardReceivedAt: b.cardReceivedAt,
);

/// A blank optional value is stored as none, as the form stores it.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _sameText(String? a, String? b) => _orNone(a) == _orNone(b);

bool _sameBytes(Uint8List? a, Uint8List? b) =>
    identical(a, b) || (a != null && b != null && listEquals(a, b));

/// The photo: removing it clears its file path too, as [Buddy.clearPhoto]
/// does; a new one keeps the path as stored, as the form saves it.
final buddyPhotoField = EditField<Buddy, Uint8List?>(
  id: 'photo',
  cardId: _header,
  read: (b) => b.photo,
  write: (b, v) =>
      v == null ? _with(b, photo: null, photoPath: null) : _with(b, photo: v),
  equals: _sameBytes,
);

/// Required: a sitting with it blank cannot be saved.
final buddyNameField = EditField<Buddy, String>(
  id: 'name',
  cardId: _header,
  read: (b) => b.name,
  write: (b, v) => _with(b, name: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

final buddyFavoriteField = EditField<Buddy, bool>(
  id: 'isFavorite',
  cardId: _header,
  read: (b) => b.isFavorite,
  write: (b, v) => _with(b, isFavorite: v),
);

final buddyEmailField = EditField<Buddy, String?>(
  id: 'email',
  cardId: _contact,
  read: (b) => b.email,
  write: (b, v) => _with(b, email: _orNone(v)),
  equals: _sameText,
);

final buddyPhoneField = EditField<Buddy, String?>(
  id: 'phone',
  cardId: _contact,
  read: (b) => b.phone,
  write: (b, v) => _with(b, phone: _orNone(v)),
  equals: _sameText,
);

final buddySocialHandleField = EditField<Buddy, String?>(
  id: 'socialHandle',
  cardId: _contact,
  read: (b) => b.socialHandle,
  write: (b, v) => _with(b, socialHandle: _orNone(v)),
  equals: _sameText,
);

final buddyCountryField = EditField<Buddy, String?>(
  id: 'country',
  cardId: _contact,
  read: (b) => b.country,
  write: (b, v) => _with(b, country: BuddyCountryColumns.text(v)),
  equals: _sameText,
);

/// The local profile this buddy is (issue #2002); null is none, as
/// [Buddy.clearLinkedDiver] stores it.
final buddyLinkedDiverField = EditField<Buddy, String?>(
  id: 'linkedDiverId',
  cardId: _contact,
  read: (b) => b.linkedDiverId,
  write: (b, v) => _with(b, linkedDiverId: v),
);

/// Left out of the rankings (issue #3624).
final buddyExcludedFromRankingsField = EditField<Buddy, bool>(
  id: 'excludedFromRankings',
  cardId: _statistics,
  read: (b) => b.excludedFromRankings,
  write: (b, v) => _with(b, excludedFromRankings: v),
);

final buddyNotesField = EditField<Buddy, String>(
  id: 'notes',
  cardId: _notes,
  read: (b) => b.notes,
  write: (b, v) => _with(b, notes: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

final RegExp _email = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

/// Whether [email] can be saved: none, or one of the form's shape.
bool buddyEmailValid(String? email) {
  final text = email?.trim() ?? '';
  return text.isEmpty || _email.hasMatch(text);
}

/// Whether [name] can be saved: not blank.
bool buddyNameValid(String name) => name.trim().isNotEmpty;
