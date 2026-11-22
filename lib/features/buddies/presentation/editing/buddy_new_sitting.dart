import 'package:flutter/foundation.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_card_ids.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_fields.dart';
import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

/// A new buddy's sitting (issue #4527, phase 3, plan 11): what its opener
/// brings, its seed, the cards laid out open, and the prefill.

/// What a new buddy's opener brings, each a change of the card that shows
/// it: a name, email, phone and photo from the phone's contacts.
@immutable
class NewBuddySeed {
  const NewBuddySeed({this.name, this.email, this.phone, this.photo});

  /// The seed in `/buddies/new`'s `extra`, the map Import from contacts
  /// hands it; none for anything else.
  static NewBuddySeed? fromRouteExtra(Object? extra) {
    if (extra is! Map) return null;
    String? text(String key) {
      final value = extra[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    final photo = extra['photo'];
    final seed = NewBuddySeed(
      name: text('name'),
      email: text('email'),
      phone: text('phone'),
      photo: photo is Uint8List && photo.isNotEmpty ? photo : null,
    );
    return seed.isEmpty ? null : seed;
  }

  final String? name;
  final String? email;
  final String? phone;
  final Uint8List? photo;

  bool get isEmpty =>
      name == null && email == null && phone == null && photo == null;
}

/// A new buddy's starting record under [id]: the active diver's, with no
/// name, ranked and not a favourite, as the form starts one. A diver that
/// cannot be read leaves none, for Save to take the one active then.
Future<Buddy> newBuddySeed(RecordSeedRead read, {required String id}) async {
  final diverId = await newRecordDiverId(read, record: 'buddy');
  final now = DateTime.now();
  return Buddy(
    id: id,
    diverId: diverId,
    name: '',
    createdAt: now,
    updatedAt: now,
  );
}

/// The cards a new buddy opens with: the header block, Contact and Notes.
final List<String> newBuddyLaidOut = List.unmodifiable([
  BuddyCardId.header.name,
  BuddyCardId.contact.name,
  BuddyCardId.notes.name,
]);

/// Puts what [seed] brings on [session], each through its card's field, so
/// each is a change: the photo alone too, which the form did not count.
void applyNewBuddyPrefill(EditSession<Buddy> session, NewBuddySeed? seed) {
  if (seed == null || session.isDisposed || session.isFrozen) return;
  if (seed.name case final name?) session.set(buddyNameField, name);
  if (seed.email case final email?) session.set(buddyEmailField, email);
  if (seed.phone case final phone?) session.set(buddyPhoneField, phone);
  if (seed.photo case final photo?) session.set(buddyPhotoField, photo);
}
