import 'package:flutter/foundation.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_card_ids.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The dive centre page's values a sitting edits, and the rules its form
/// keeps (issue #4527, phase 3).

final String _header = DiveCenterCardId.header.name;
final String _map = DiveCenterCardId.map.name;
final String _contact = DiveCenterCardId.contact.name;
final String _notes = DiveCenterCardId.notes.name;

const Object _keep = Object();

T? _or<T>(Object? value, T? kept) =>
    identical(value, _keep) ? kept : value as T?;

/// [c] with the given values, every other one kept. [DiveCenter.copyWith]
/// cannot clear most values, so the fields build the centre whole.
DiveCenter _with(
  DiveCenter c, {
  String? name,
  Object? street = _keep,
  Object? city = _keep,
  Object? stateProvince = _keep,
  Object? postalCode = _keep,
  Object? latitude = _keep,
  Object? longitude = _keep,
  Object? country = _keep,
  Object? phone = _keep,
  Object? email = _keep,
  Object? website = _keep,
  List<String>? affiliations,
  Object? rating = _keep,
  String? notes,
  Object? fillOpensAt = _keep,
  Object? fillClosesAt = _keep,
  bool? isPermanentlyClosed,
  Object? logo = _keep,
}) => DiveCenter(
  id: c.id,
  diverId: c.diverId,
  name: name ?? c.name,
  street: _or<String>(street, c.street),
  city: _or<String>(city, c.city),
  stateProvince: _or<String>(stateProvince, c.stateProvince),
  postalCode: _or<String>(postalCode, c.postalCode),
  latitude: _or<double>(latitude, c.latitude),
  longitude: _or<double>(longitude, c.longitude),
  country: _or<String>(country, c.country),
  phone: _or<String>(phone, c.phone),
  email: _or<String>(email, c.email),
  website: _or<String>(website, c.website),
  affiliations: affiliations ?? c.affiliations,
  rating: _or<double>(rating, c.rating),
  notes: notes ?? c.notes,
  fillOpensAt: _or<int>(fillOpensAt, c.fillOpensAt),
  fillClosesAt: _or<int>(fillClosesAt, c.fillClosesAt),
  isPermanentlyClosed: isPermanentlyClosed ?? c.isPermanentlyClosed,
  logo: _or<Uint8List>(logo, c.logo),
  createdAt: c.createdAt,
  updatedAt: c.updatedAt,
);

/// A blank optional value is stored as none, as the form stores it.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _sameText(String? a, String? b) => _orNone(a) == _orNone(b);

EditField<DiveCenter, String?> _text(
  String id,
  String cardId,
  String? Function(DiveCenter c) read,
  DiveCenter Function(DiveCenter c, String? v) write,
) => EditField<DiveCenter, String?>(
  id: id,
  cardId: cardId,
  read: read,
  write: (c, v) => write(c, _orNone(v)),
  equals: _sameText,
);

final diveCenterLogoField = EditField<DiveCenter, Uint8List?>(
  id: 'logo',
  cardId: _header,
  read: (c) => c.logo,
  write: (c, v) => _with(c, logo: v),
  equals: (a, b) =>
      identical(a, b) || (a != null && b != null && listEquals(a, b)),
);

/// Required: a sitting with it blank cannot be saved.
final diveCenterNameField = EditField<DiveCenter, String>(
  id: 'name',
  cardId: _header,
  read: (c) => c.name,
  write: (c, v) => _with(c, name: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

final diveCenterRatingField = EditField<DiveCenter, double?>(
  id: 'rating',
  cardId: _header,
  read: (c) => c.rating,
  write: (c, v) => _with(c, rating: v),
);

final diveCenterStreetField = _text(
  'street',
  _header,
  (c) => c.street,
  (c, v) => _with(c, street: v),
);

final diveCenterCityField = _text(
  'city',
  _header,
  (c) => c.city,
  (c, v) => _with(c, city: v),
);

final diveCenterStateProvinceField = _text(
  'stateProvince',
  _header,
  (c) => c.stateProvince,
  (c, v) => _with(c, stateProvince: v),
);

final diveCenterPostalCodeField = _text(
  'postalCode',
  _header,
  (c) => c.postalCode,
  (c, v) => _with(c, postalCode: v),
);

final diveCenterCountryField = _text(
  'country',
  _header,
  (c) => c.country,
  (c, v) => _with(c, country: v),
);

/// The agencies the centre teaches with; their order carries no meaning.
final diveCenterAffiliationsField = EditField<DiveCenter, List<String>>(
  id: 'affiliations',
  cardId: _header,
  read: (c) => c.affiliations,
  write: (c, v) => _with(c, affiliations: List.unmodifiable(v)),
  equals: (a, b) => setEquals(a.toSet(), b.toSet()),
);

final diveCenterClosedField = EditField<DiveCenter, bool>(
  id: 'isPermanentlyClosed',
  cardId: _header,
  read: (c) => c.isPermanentlyClosed,
  write: (c, v) => _with(c, isPermanentlyClosed: v),
);

/// Where the centre is: both coordinates, or none. One value, so a pick
/// from the map or a lookup is one change.
typedef DiveCenterCoordinates = ({double latitude, double longitude});

final diveCenterCoordinatesField =
    EditField<DiveCenter, DiveCenterCoordinates?>(
      id: 'coordinates',
      cardId: _map,
      read: (c) => c.latitude == null || c.longitude == null
          ? null
          : (latitude: c.latitude!, longitude: c.longitude!),
      write: (c, v) => _with(c, latitude: v?.latitude, longitude: v?.longitude),
    );

final diveCenterPhoneField = _text(
  'phone',
  _contact,
  (c) => c.phone,
  (c, v) => _with(c, phone: v),
);

final diveCenterEmailField = _text(
  'email',
  _contact,
  (c) => c.email,
  (c, v) => _with(c, email: v),
);

final diveCenterWebsiteField = _text(
  'website',
  _contact,
  (c) => c.website,
  (c, v) => _with(c, website: v),
);

/// The fill station's daily window, in minutes after midnight: both times,
/// or neither ([fillHoursProblem]).
typedef DiveCenterFillHours = ({int? opensAt, int? closesAt});

final diveCenterFillHoursField = EditField<DiveCenter, DiveCenterFillHours>(
  id: 'fillHours',
  cardId: _contact,
  read: (c) => (opensAt: c.fillOpensAt, closesAt: c.fillClosesAt),
  write: (c, v) => _with(c, fillOpensAt: v.opensAt, fillClosesAt: v.closesAt),
);

final diveCenterNotesField = EditField<DiveCenter, String>(
  id: 'notes',
  cardId: _notes,
  read: (c) => c.notes,
  write: (c, v) => _with(c, notes: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

/// What is wrong with [latitude] and [longitude] as the form checks them,
/// or null when they can be saved.
String? diveCenterCoordinateError(
  AppLocalizations l10n,
  double? latitude,
  double? longitude,
) {
  if (latitude != null && (latitude < -90 || latitude > 90)) {
    return l10n.diveCenters_validation_invalidLatitude;
  }
  if (longitude != null && (longitude < -180 || longitude > 180)) {
    return l10n.diveCenters_validation_invalidLongitude;
  }
  return null;
}

/// Whether [coordinates] can be saved.
bool diveCenterCoordinatesValid(DiveCenterCoordinates? coordinates) =>
    coordinates == null ||
    (coordinates.latitude >= -90 &&
        coordinates.latitude <= 90 &&
        coordinates.longitude >= -180 &&
        coordinates.longitude <= 180);

final RegExp _email = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

/// Whether [email] can be saved: none, or one of the form's shape.
bool diveCenterEmailValid(String? email) {
  final text = email?.trim() ?? '';
  return text.isEmpty || _email.hasMatch(text);
}

/// The address as one line for a lookup, its blank parts left out, as the
/// form builds it.
String diveCenterAddressLine(DiveCenter c) => [
  c.street,
  c.city,
  c.stateProvince,
  c.postalCode,
  c.country,
].map((p) => p?.trim() ?? '').where((p) => p.isNotEmpty).join(', ');
