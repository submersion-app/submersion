import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_merge.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/core/services/database_service.dart';

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

  /// The buddy and its certifications are saved together or not at all.
  Future<T> _atomically<T>(Future<T> Function() work) =>
      DatabaseService.instance.database.transaction(work);

  Future<Buddy> addNew(BuddyCard card, {required String diverId}) async {
    // Demo mode (issue #3708): nothing comes into the sample logbook.
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.fileImport);
    return _atomically(() => _addNew(card, diverId: diverId));
  }

  Future<Buddy> _addNew(BuddyCard card, {required String diverId}) async {
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
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.fileImport);
    return _atomically(() => _update(existing, card));
  }

  Future<Buddy> _update(Buddy shown, BuddyCard card) async {
    // The buddy as it is now, not as the preview showed it: the diver or a
    // sync may have changed their notes or favourite flag meanwhile, and
    // the whole row is written back.
    final existing = await _buddies.getBuddyById(shown.id);
    if (existing == null) {
      throw StateError('Buddy ${shown.id} no longer exists');
    }
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
    final now = _clock();
    for (final write in _plan(card, existing)) {
      final current = write.current;
      if (current == null) {
        await _certifications.createCertification(
          Certification(
            id: '',
            buddyId: buddyId,
            name: write.name,
            agency: write.agency,
            level: write.level,
            cardNumber: write.cardNumber,
            issueDate: write.issueDate,
            cardId: card.id,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await _certifications.updateCertification(
          current.copyWith(
            level: write.level,
            cardNumber: write.cardNumber,
            issueDate: write.issueDate,
            cardId: card.id,
          ),
        );
      }
    }
  }

  /// The card's certifications that saving it onto a buddy holding
  /// [existing] would add or change, for the import preview.
  static List<BuddyCardCert> certsToWrite(
    BuddyCard card,
    List<Certification> existing,
  ) => [for (final write in _plan(card, existing)) write.cert];

  /// What saving [card]'s certifications onto [existing] writes. The
  /// receiver's own entry for the same certification wins (no twin), a
  /// certification the card names twice is written once, and a detail the
  /// card leaves out (a trimmed card) keeps the stored one.
  static List<_CertWrite> _plan(BuddyCard card, List<Certification> existing) {
    final cardMade = {
      for (final c in existing)
        if (c.cardId != null) _key(c.agency, c.name): c,
    };
    final byHand = {
      for (final c in existing)
        if (c.cardId == null) _key(c.agency, c.name),
    };
    final seen = <String>{};
    final out = <_CertWrite>[];
    for (final cert in card.certs) {
      final mapped = _mapped(cert);
      final key = _key(mapped.agency, mapped.name);
      if (byHand.contains(key) || !seen.add(key)) continue;
      final current = cardMade[key];
      final write = _CertWrite(
        cert: cert,
        current: current,
        agency: mapped.agency,
        name: mapped.name,
        level: mapped.level ?? current?.level,
        cardNumber: cert.cardNumber ?? current?.cardNumber,
        issueDate: cert.issueDate ?? current?.issueDate,
      );
      if (current != null &&
          current.level == write.level &&
          current.cardNumber == write.cardNumber &&
          current.issueDate == write.issueDate) {
        continue;
      }
      out.add(write);
    }
    return out;
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

/// One certification a card save writes: [current] is the card-made row it
/// refreshes, null for a new one.
class _CertWrite {
  const _CertWrite({
    required this.cert,
    required this.current,
    required this.agency,
    required this.name,
    required this.level,
    required this.cardNumber,
    required this.issueDate,
  });

  final BuddyCardCert cert;
  final Certification? current;
  final String agency;
  final String name;
  final String? level;
  final String? cardNumber;
  final DateTime? issueDate;
}
