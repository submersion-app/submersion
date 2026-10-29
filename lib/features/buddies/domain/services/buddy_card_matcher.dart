import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';

/// Which existing buddy a received card is (issue #3728).
sealed class BuddyCardMatch {
  const BuddyCardMatch();
}

/// A buddy made from an earlier card of the same person.
class CardRecognised extends BuddyCardMatch {
  final Buddy buddy;
  const CardRecognised(this.buddy);
}

/// A buddy with the same name, phone or email, never carded by anyone
/// else: probably the same person, so the diver is asked.
class CardPossibleMatch extends BuddyCardMatch {
  final Buddy buddy;
  const CardPossibleMatch(this.buddy);
}

class CardNew extends BuddyCardMatch {
  const CardNew();
}

/// The fewest digits a phone number needs before it can identify someone.
const _minPhoneDigits = 6;

/// Matches [card] against [buddies], the current diver's own list: a buddy
/// already made from this person's card first, then one with the same
/// name, phone or email that no other card made.
BuddyCardMatch matchBuddyCard(BuddyCard card, List<Buddy> buddies) {
  for (final b in buddies) {
    if (b.cardId == card.id) return CardRecognised(b);
  }
  final name = _name(card.name);
  final phone = _digits(card.phone);
  final email = _email(card.email);
  for (final b in buddies) {
    if (b.cardId != null) continue;
    final samePhone = phone != null && _digits(b.phone) == phone;
    final sameEmail = email != null && _email(b.email) == email;
    if (_name(b.name) == name || samePhone || sameEmail) {
      return CardPossibleMatch(b);
    }
  }
  return const CardNew();
}

String _name(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

String? _digits(String? value) {
  if (value == null) return null;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length < _minPhoneDigits ? null : digits;
}

String? _email(String? value) {
  final t = value?.trim().toLowerCase();
  return t == null || t.isEmpty ? null : t;
}
