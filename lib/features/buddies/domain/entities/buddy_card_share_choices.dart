import 'dart:convert';

import 'package:equatable/equatable.dart';

/// What a diver puts on their buddy card (issue #3728), remembered between
/// swaps. The name is always sent. Medical, insurance and emergency details
/// have no switch here because they are never offered.
class BuddyCardShareChoices extends Equatable {
  final bool photo;
  final bool phone;
  final bool email;
  final bool certifications;

  /// Certification card numbers and issue dates.
  final bool cardDetails;
  final bool diveCount;
  final bool divingSince;
  final bool lastDive;
  final bool social;

  const BuddyCardShareChoices({
    required this.photo,
    required this.phone,
    required this.email,
    required this.certifications,
    required this.cardDetails,
    required this.diveCount,
    required this.divingSince,
    required this.lastDive,
    required this.social,
  });

  static const defaults = BuddyCardShareChoices(
    photo: true,
    phone: true,
    email: true,
    certifications: true,
    cardDetails: false,
    diveCount: true,
    divingSince: true,
    lastDive: true,
    social: false,
  );

  /// Reads stored choices. Null, unreadable JSON, a missing key or a value
  /// of the wrong type all take the default.
  factory BuddyCardShareChoices.fromJson(String? json) {
    if (json == null) return defaults;
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return defaults;
    }
    if (decoded is! Map<String, Object?>) return defaults;
    bool read(String key, bool fallback) {
      final value = decoded is Map<String, Object?> ? decoded[key] : null;
      return value is bool ? value : fallback;
    }

    const d = defaults;
    return BuddyCardShareChoices(
      photo: read('photo', d.photo),
      phone: read('phone', d.phone),
      email: read('email', d.email),
      certifications: read('certifications', d.certifications),
      cardDetails: read('cardDetails', d.cardDetails),
      diveCount: read('diveCount', d.diveCount),
      divingSince: read('divingSince', d.divingSince),
      lastDive: read('lastDive', d.lastDive),
      social: read('social', d.social),
    );
  }

  String toJson() => jsonEncode({
    'photo': photo,
    'phone': phone,
    'email': email,
    'certifications': certifications,
    'cardDetails': cardDetails,
    'diveCount': diveCount,
    'divingSince': divingSince,
    'lastDive': lastDive,
    'social': social,
  });

  BuddyCardShareChoices copyWith({
    bool? photo,
    bool? phone,
    bool? email,
    bool? certifications,
    bool? cardDetails,
    bool? diveCount,
    bool? divingSince,
    bool? lastDive,
    bool? social,
  }) {
    return BuddyCardShareChoices(
      photo: photo ?? this.photo,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      certifications: certifications ?? this.certifications,
      cardDetails: cardDetails ?? this.cardDetails,
      diveCount: diveCount ?? this.diveCount,
      divingSince: divingSince ?? this.divingSince,
      lastDive: lastDive ?? this.lastDive,
      social: social ?? this.social,
    );
  }

  @override
  List<Object?> get props => [
    photo,
    phone,
    email,
    certifications,
    cardDetails,
    diveCount,
    divingSince,
    lastDive,
    social,
  ];
}
