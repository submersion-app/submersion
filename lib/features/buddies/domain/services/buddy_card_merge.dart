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

  /// The card's photo replaces the buddy's; [BuddyCardChange.to] is empty.
  photo,
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
/// card leaves out never changes (issue #3728). [certs] are the card's
/// certifications the save would add or change, when the buddy's stored
/// ones are known; otherwise every one the card carries is listed.
List<BuddyCardChange> buddyCardChanges(
  Buddy? existing,
  BuddyCard card, {
  List<BuddyCardCert>? certs,
}) {
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
  final photo = card.photo;
  if (photo != null &&
      (existing?.photo == null || !_sameBytes(existing!.photo!, photo))) {
    out.add(const BuddyCardChange(BuddyCardChangeField.photo, null, ''));
  }
  final written = certs ?? card.certs;
  if (written.isNotEmpty) {
    add(
      BuddyCardChangeField.certifications,
      null,
      written.map(certLabel).join(', '),
    );
  }
  return out;
}

/// Of [buddies] being merged into one, the one whose buddy card figures and
/// card id the merged buddy keeps: the latest card received, so a later
/// swap with that person still recognises them. Null when no card made any.
Buddy? mergedBuddyCardSource(List<Buddy> buddies) {
  Buddy? source;
  for (final b in buddies) {
    if (b.cardId == null) continue;
    final at = b.cardReceivedAt;
    final best = source?.cardReceivedAt;
    if (source == null || (at != null && (best == null || at.isAfter(best)))) {
      source = b;
    }
  }
  return source;
}

/// The social handle a merge starts with: the first of [buddies] that has
/// one, in merge order.
String? mergedSocialHandle(List<Buddy> buddies) {
  for (final b in buddies) {
    final handle = b.socialHandle;
    if (handle != null && handle.trim().isNotEmpty) return handle;
  }
  return null;
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

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
