import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// One certification as a buddy card carries it (issue #3728): display
/// names, never the sender's custom agency or level ids, which mean nothing
/// on another device.
class BuddyCardCert extends Equatable {
  final String agency;
  final String name;
  final String? level;

  /// Only when the sender shares card details.
  final String? cardNumber;
  final DateTime? issueDate;

  const BuddyCardCert({
    required this.agency,
    required this.name,
    this.level,
    this.cardNumber,
    this.issueDate,
  });

  /// This certification without its card number and issue date.
  BuddyCardCert withoutCardDetails() =>
      BuddyCardCert(agency: agency, name: name, level: level);

  @override
  List<Object?> get props => [agency, name, level, cardNumber, issueDate];
}

/// The details one diver hands another in a buddy card swap (issue #3728).
/// Everything but [id] and [name] is optional: the sender chooses what to
/// share, and a compact card may have dropped fields to fit a QR code or an
/// NFC sticker.
class BuddyCard extends Equatable {
  /// The card format version it was read from or will be written as.
  final int version;

  /// The sender's diver id: how a receiver recognises the same person on a
  /// later swap.
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? social;

  /// Highest first.
  final List<BuddyCardCert> certs;

  /// Total dives: logged plus any the sender logged before Submersion.
  final int? dives;

  /// The year the sender started diving.
  final int? since;

  /// The date of the sender's most recent logged dive.
  final DateTime? last;

  /// A small JPEG thumbnail; never in a compact card.
  final Uint8List? photo;

  const BuddyCard({
    this.version = 1,
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.social,
    this.certs = const [],
    this.dives,
    this.since,
    this.last,
    this.photo,
  });

  BuddyCard copyWith({
    int? version,
    String? id,
    String? name,
    String? phone,
    String? email,
    String? social,
    List<BuddyCardCert>? certs,
    int? dives,
    int? since,
    DateTime? last,
    Uint8List? photo,
    bool clearPhone = false,
    bool clearEmail = false,
    bool clearSocial = false,
    bool clearSince = false,
    bool clearLast = false,
    bool clearPhoto = false,
  }) {
    return BuddyCard(
      version: version ?? this.version,
      id: id ?? this.id,
      name: name ?? this.name,
      phone: clearPhone ? null : phone ?? this.phone,
      email: clearEmail ? null : email ?? this.email,
      social: clearSocial ? null : social ?? this.social,
      certs: certs ?? this.certs,
      dives: dives ?? this.dives,
      since: clearSince ? null : since ?? this.since,
      last: clearLast ? null : last ?? this.last,
      photo: clearPhoto ? null : photo ?? this.photo,
    );
  }

  @override
  List<Object?> get props => [
    version,
    id,
    name,
    phone,
    email,
    social,
    certs,
    dives,
    since,
    last,
    photo,
  ];
}
