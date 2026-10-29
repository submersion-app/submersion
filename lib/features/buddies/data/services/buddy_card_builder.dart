import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card_share_choices.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// The fields a diver can switch on or off on their buddy card.
enum BuddyCardField {
  photo,
  phone,
  email,
  certifications,
  cardDetails,
  diveCount,
  divingSince,
  lastDive,
  social,
}

/// Builds the current diver's own buddy card from their profile, their
/// certifications and their logbook (issue #3728).
///
/// Reads only the fields a card can carry. Medical notes, allergies,
/// medications, insurance and emergency contacts are never read here, so
/// no choice can put them on a card.
class BuddyCardBuilder {
  BuddyCardBuilder({
    required DiverRepository divers,
    required CertificationRepository certifications,
    required DiveRepository dives,
    required Future<CertificationCatalog> Function() catalog,
  }) : _divers = divers,
       _certifications = certifications,
       _dives = dives,
       _catalog = catalog;

  final DiverRepository _divers;
  final CertificationRepository _certifications;
  final DiveRepository _dives;
  final Future<CertificationCatalog> Function() _catalog;

  /// Longest side of the card photo, in pixels.
  static const int photoMaxDimension = 160;

  Future<BuddyCard> build(String diverId, BuddyCardShareChoices choices) async {
    final diver = await _divers.getDiverById(diverId);
    if (diver == null) throw StateError('No diver $diverId');
    final certs = choices.certifications
        ? await _cardCerts(diverId, withDetails: choices.cardDetails)
        : const <BuddyCardCert>[];
    final dives = choices.diveCount ? await _diveCount(diver) : null;
    final last = choices.lastDive ? await _lastDive(diverId) : null;
    // Decoding a full-size photo in Dart takes a while: off the UI isolate.
    final photo = choices.photo && diver.photo != null
        ? await compute(thumbnail, diver.photo!)
        : null;
    return BuddyCard(
      id: diver.id,
      name: diver.name,
      phone: choices.phone ? _nonEmpty(diver.phone) : null,
      email: choices.email ? _nonEmpty(diver.email) : null,
      social: choices.social ? _nonEmpty(diver.socialHandle) : null,
      certs: certs,
      dives: dives,
      since: choices.divingSince ? diver.divingSince?.year : null,
      last: last,
      photo: photo,
    );
  }

  /// The fields this diver has something to share for, so the share sheet
  /// can hide the rest.
  Future<Set<BuddyCardField>> availableFields(String diverId) async {
    final diver = await _divers.getDiverById(diverId);
    if (diver == null) return const {};
    final certs = await _certifications.getAllCertifications(diverId: diverId);
    return {
      if (diver.photo != null) BuddyCardField.photo,
      if (_nonEmpty(diver.phone) != null) BuddyCardField.phone,
      if (_nonEmpty(diver.email) != null) BuddyCardField.email,
      if (certs.isNotEmpty) BuddyCardField.certifications,
      if (certs.any((c) => c.cardNumber != null || c.issueDate != null))
        BuddyCardField.cardDetails,
      if (await _diveCount(diver) != null) BuddyCardField.diveCount,
      if (diver.divingSince != null) BuddyCardField.divingSince,
      if (await _lastDive(diverId) != null) BuddyCardField.lastDive,
      if (_nonEmpty(diver.socialHandle) != null) BuddyCardField.social,
    };
  }

  Future<List<BuddyCardCert>> _cardCerts(
    String diverId, {
    required bool withDetails,
  }) async {
    final certs = await _certifications.getAllCertifications(diverId: diverId);
    if (certs.isEmpty) return const [];
    final catalog = await _catalog();
    return [
      for (final c in _highestFirst(certs, catalog))
        BuddyCardCert(
          agency: catalog.agency(c.agency).interchangeName,
          name: certificationTitle(c, catalog: catalog),
          level: c.level == null
              ? null
              : catalog.level(c.level!).interchangeName,
          cardNumber: withDetails ? c.cardNumber : null,
          issueDate: withDetails ? c.issueDate : null,
        ),
    ];
  }

  /// The order `primaryCertification` picks from: rank on the agency
  /// ladder, then latest issue date, then most recently updated.
  static List<Certification> _highestFirst(
    List<Certification> certs,
    CertificationCatalog catalog,
  ) {
    int rank(Certification c) => catalog.rankOf(c.agency, c.level);
    return [...certs]..sort((a, b) {
      final byRank = rank(b).compareTo(rank(a));
      if (byRank != 0) return byRank;
      final ai = a.issueDate;
      final bi = b.issueDate;
      if (ai != null && bi != null && ai != bi) return bi.compareTo(ai);
      if (ai != null && bi == null) return -1;
      if (ai == null && bi != null) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  /// Logged dives plus the diver's dives from before Submersion; null when
  /// both are nothing.
  Future<int?> _diveCount(Diver diver) async {
    final logged = await _divers.getDiveCountForDiver(diver.id);
    final total = logged + (diver.priorDiveCount ?? 0);
    return total == 0 ? null : total;
  }

  /// The calendar date of the newest dive. Dive times are stored as wall
  /// clock in UTC, so the UTC fields are the local date of the dive.
  Future<DateTime?> _lastDive(String diverId) async {
    final newest = await _dives.getNewestDiveDateTime(diverId: diverId);
    if (newest == null) return null;
    return DateTime(newest.year, newest.month, newest.day);
  }

  static String? _nonEmpty(String? value) {
    final t = value?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// [jpeg] scaled so its longest side is at most [photoMaxDimension] and
  /// re-encoded until it fits [BuddyCardCodec.maxPhotoBytes]. Null when it
  /// cannot be read or will not fit.
  static Uint8List? thumbnail(Uint8List jpeg) {
    final decoded = img.decodeImage(jpeg);
    if (decoded == null) return null;
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = longest > photoMaxDimension
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? photoMaxDimension : null,
            height: decoded.height > decoded.width ? photoMaxDimension : null,
          )
        : decoded;
    for (var quality = 80; quality >= 30; quality -= 10) {
      final bytes = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality),
      );
      if (bytes.length <= BuddyCardCodec.maxPhotoBytes) return bytes;
    }
    return null;
  }
}
