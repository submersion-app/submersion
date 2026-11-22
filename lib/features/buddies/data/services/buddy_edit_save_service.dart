import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_profile_link_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// Writes a buddy page's editing sitting (issue #4527, phase 3): the
/// buddy's changed values and every held write, in one transaction and one
/// History entry labelled with the cards it changed.
class BuddyEditSaveService {
  BuddyEditSaveService(this._buddies, this._links);

  final BuddyRepository _buddies;
  final BuddyProfileLinkRepository _links;

  /// Saves [apply] onto buddy [buddyId] as stored now, so a value changed
  /// underneath on a card the diver never touched is kept. A profile link
  /// the sitting set is checked inside the write: one another buddy of the
  /// same list holds now, or the diver themselves, refuses the whole save
  /// with today's message ([RecordSittingRefusal]). [alsoWrite] makes the
  /// held writes (certifications, gear lent and returned) after the row.
  /// Returns the buddy before and after, or null when nothing changed.
  /// Throws [StateError] when the buddy no longer exists.
  Future<({Buddy before, Buddy after})?> save({
    required String buddyId,
    required Buddy Function(Buddy stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) => writeRecordSitting<Buddy>(
    table: 'buddies',
    recordId: buddyId,
    changedCardIds: changedCardIds,
    read: () => _buddies.getBuddyById(buddyId),
    apply: apply,
    write: (stored, merged) async {
      final link = merged.linkedDiverId;
      if (link != null && link != stored.linkedDiverId) {
        await _assertLinkAllowed(merged, link);
      }
      // Re-derives the country code against the stored row.
      await _buddies.updateBuddy(merged);
    },
    alsoWrite: alsoWrite,
    alsoWriteIsAChange: alsoWriteIsAChange,
  );

  /// Creates [buddy], a new buddy's sitting (issue #4527, phase 3, plan
  /// 11), keeping its id: the row, then [alsoWrite], the sitting's held
  /// writes (certifications, documents), in one transaction and one History
  /// entry naming [changedCardIds]. A profile link is checked inside, as on
  /// a save: one refused fails the whole create ([RecordSittingRefusal]),
  /// and if anything throws nothing is left. Throws [StateError] when
  /// [buddy] has no id, or one a stored buddy has.
  Future<Buddy> create({
    required Buddy buddy,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) => createRecordSitting<Buddy>(
    table: 'buddies',
    recordId: buddy.id,
    changedCardIds: changedCardIds,
    isStored: () async => await _buddies.getBuddyById(buddy.id) != null,
    insert: () async {
      final link = buddy.linkedDiverId;
      if (link != null) await _assertLinkAllowed(buddy, link);
      await _buddies.createBuddy(buddy);
    },
    alsoWrite: alsoWrite,
    readBack: () => _buddies.getBuddyById(buddy.id),
    created: buddy,
  );

  Future<void> _assertLinkAllowed(Buddy buddy, String link) async {
    try {
      await _links.assertLinkAllowed(
        ownerDiverId: buddy.diverId,
        linkedDiverId: link,
        buddyId: buddy.id,
      );
    } on BuddyLinkRefused catch (refusal) {
      throw RecordSittingRefusal(
        (l10n) => switch (refusal.reason) {
          BuddyLinkRefusal.self => l10n.buddies_linkedProfile_refusedSelf,
          BuddyLinkRefusal.taken => l10n.buddies_linkedProfile_refusedTaken(
            refusal.existingBuddy?.name ?? '',
          ),
        },
      );
    }
  }
}

final buddyEditSaveServiceProvider = Provider<BuddyEditSaveService>(
  (ref) => BuddyEditSaveService(
    ref.watch(buddyRepositoryProvider),
    ref.watch(buddyProfileLinkRepositoryProvider),
  ),
);
