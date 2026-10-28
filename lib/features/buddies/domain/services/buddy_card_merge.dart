import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';

/// A field a received card sets on a buddy.
enum BuddyCardChangeField {
  name,
  phone,
  email,
  social,
  dives,
  divingSince,
  lastDive,
  certifications,
}

/// One line of the import preview: what a field was and what the card sets
/// it to. [from] is null for a new buddy or an empty field. Dates are left
/// to the page to format; [to] and [from] carry them as `yyyy-MM-dd`.
class BuddyCardChange {
  final BuddyCardChangeField field;
  final String? from;
  final String to;

  const BuddyCardChange(this.field, this.from, this.to);
}

/// What saving [card] onto [existing] (null for a new buddy) would change.
/// Only fields the card carries and that differ are listed; a field the
/// card leaves out never changes (issue #3728).
List<BuddyCardChange> buddyCardChanges(Buddy? existing, BuddyCard card) {
  final out = <BuddyCardChange>[];
  void add(BuddyCardChangeField field, String? from, String? to) {
    if (to == null || to == from) return;
    out.add(BuddyCardChange(field, from, to));
  }

  add(BuddyCardChangeField.name, existing?.name, card.name);
  add(BuddyCardChangeField.phone, existing?.phone, card.phone);
  add(BuddyCardChangeField.email, existing?.email, card.email);
  add(BuddyCardChangeField.social, existing?.socialHandle, card.social);
  add(
    BuddyCardChangeField.dives,
    existing?.cardDiveCount?.toString(),
    card.dives?.toString(),
  );
  add(
    BuddyCardChangeField.divingSince,
    existing?.cardDivingSince?.year.toString(),
    card.since?.toString(),
  );
  add(
    BuddyCardChangeField.lastDive,
    _date(existing?.cardLastDive),
    _date(card.last),
  );
  if (card.certs.isNotEmpty) {
    add(
      BuddyCardChangeField.certifications,
      null,
      card.certs.map(certLabel).join(', '),
    );
  }
  return out;
}

/// A certification as one line: agency then name, without repeating an
/// agency the name already starts with.
String certLabel(BuddyCardCert cert) {
  final name = cert.name.trim();
  final agency = cert.agency.trim();
  return name.toLowerCase().startsWith(agency.toLowerCase())
      ? name
      : '$agency $name';
}

String? _date(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
