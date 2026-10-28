import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_merge.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// Saves a received buddy card (issue #3728), after the diver confirmed the
/// preview.
///
/// Only what the card carries is written. The receiver's notes, favourite
/// flag, linked profile, shared dives and hand-entered certifications are
/// never touched, and a field the sender left out stays as it was.
class BuddyCardImporter {
  BuddyCardImporter({
    required BuddyRepository buddies,
    required CertificationRepository certifications,
    DateTime Function()? clock,
  }) : _buddies = buddies,
       _certifications = certifications,
       _clock = clock ?? DateTime.now;

  final BuddyRepository _buddies;
  final CertificationRepository _certifications;
  final DateTime Function() _clock;

  Future<Buddy> addNew(BuddyCard card, {required String diverId}) async {
    final now = _clock();
    final buddy = await _buddies.createBuddy(
      Buddy(
        id: '',
        diverId: diverId,
        name: card.name,
        phone: card.phone,
        email: card.email,
        socialHandle: card.social,
        photo: card.photo,
        cardId: card.id,
        cardDiveCount: card.dives,
        cardDivingSince: card.since == null ? null : DateTime(card.since!),
        cardLastDive: card.last,
        cardReceivedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _writeCerts(buddy.id, card);
    return buddy;
  }

  Future<Buddy> update(Buddy existing, BuddyCard card) async {
    final updated = existing.copyWith(
      name: card.name,
      phone: card.phone,
      email: card.email,
      socialHandle: card.social,
      photo: card.photo,
      cardId: card.id,
      cardDiveCount: card.dives,
      cardDivingSince: card.since == null ? null : DateTime(card.since!),
      cardLastDive: card.last,
      cardReceivedAt: _clock(),
    );
    await _buddies.updateBuddy(updated);
    await _writeCerts(existing.id, card);
    return updated;
  }

  /// Adds the card's certifications to [buddyId], refreshing ones an
  /// earlier card made (same agency and name) and keeping card-made ones
  /// this card leaves out: the sender may have switched them off, or a QR
  /// card dropped them to fit.
  Future<void> _writeCerts(String buddyId, BuddyCard card) async {
    if (card.certs.isEmpty) return;
    final existing = await _certifications.getCertificationsByBuddy(buddyId);
    final cardMade = {
      for (final c in existing)
        if (c.cardId != null) _key(c.agency, c.name): c,
    };
    final now = _clock();
    for (final cert in card.certs) {
      final mapped = _mapped(cert);
      final current = cardMade[_key(mapped.agency, mapped.name)];
      if (current == null) {
        await _certifications.createCertification(
          Certification(
            id: '',
            buddyId: buddyId,
            name: mapped.name,
            agency: mapped.agency,
            level: mapped.level,
            cardNumber: cert.cardNumber,
            issueDate: cert.issueDate,
            cardId: card.id,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await _certifications.updateCertification(
          current.copyWith(
            level: mapped.level,
            cardNumber: cert.cardNumber,
            issueDate: cert.issueDate,
            cardId: card.id,
          ),
        );
      }
    }
  }

  static String _key(String agency, String name) =>
      '$agency|${name.trim().toLowerCase()}';

  /// A card's display names as this device stores them: a built-in agency
  /// and level by name; anything else as agency Other with the sender's full
  /// title, so no custom agency or level appears in the receiver's pickers.
  static ({String agency, String name, String? level}) _mapped(
    BuddyCardCert cert,
  ) {
    final agency = _builtInAgency(cert.agency);
    if (agency == null || agency == CertificationAgency.other) {
      return (
        agency: CertificationAgency.other.name,
        name: certLabel(cert),
        level: null,
      );
    }
    return (
      agency: agency.name,
      name: cert.name.trim(),
      level: _builtInLevel(cert.level)?.name,
    );
  }

  static CertificationAgency? _builtInAgency(String name) {
    final wanted = name.trim().toLowerCase();
    for (final a in CertificationAgency.values) {
      if (a.displayName.toLowerCase() == wanted) return a;
    }
    return null;
  }

  static CertificationLevel? _builtInLevel(String? name) {
    if (name == null) return null;
    final wanted = name.trim().toLowerCase();
    for (final l in CertificationLevel.values) {
      if (l.displayName.toLowerCase() == wanted) return l;
    }
    return null;
  }
}
