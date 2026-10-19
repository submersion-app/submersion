import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Brings the people a diver logged on a Suunto workout onto the imported
/// dive as buddies (issue #3266).
///
/// Each name is matched to the diver's own person of that name (ignoring
/// case) or a new one is created for the diver, the same way the UDDF
/// import handles a buddy known only by name. Only names not already on
/// the dive are added, so a role set in Submersion (a guide, an instructor)
/// survives a re-import and nobody is linked twice.
class SuuntoBuddyWriter {
  SuuntoBuddyWriter({BuddyRepository? repository})
    : _repository = repository ?? BuddyRepository();

  static final _log = LoggerService.forClass(SuuntoBuddyWriter);

  final BuddyRepository _repository;

  /// Links [parsed]'s buddies to [diveId] for [diverId].
  ///
  /// The dive itself is already saved by now, so a failure here is logged
  /// rather than thrown: losing the buddies must not fail the import or stop
  /// the dives after this one.
  Future<void> attach(
    String diveId,
    SuuntoParsedDive parsed,
    String diverId,
  ) async {
    if (parsed.journal.buddies.isEmpty) return;
    final Set<String> onDive;
    final Set<String> namesOnDive;
    try {
      // The lean batch read: only ids and names are needed, not
      // certifications.
      final linked =
          (await _repository.getBuddiesForDives([diveId]))[diveId] ?? const [];
      onDive = {for (final b in linked) b.buddy.id};
      namesOnDive = {for (final b in linked) b.buddy.name.trim().toLowerCase()};
    } catch (e, st) {
      _log.error(
        'Could not read the buddies already on dive $diveId',
        error: e,
        stackTrace: st,
      );
      return;
    }
    // One person failing to save must not cost the dive the others.
    for (final name in parsed.journal.buddies) {
      // Someone of that name is already on the dive, possibly a person
      // findOrCreateByName would not pick (another profile's namesake, or
      // one of two people sharing the name): adding ours would list the
      // name twice.
      if (!namesOnDive.add(name.toLowerCase())) continue;
      try {
        final buddy = await _repository.findOrCreateByName(
          name,
          diverId: diverId,
        );
        if (buddy.diverId == null) {
          await _repository.updateBuddy(buddy.copyWith(diverId: diverId));
        }
        if (!onDive.add(buddy.id)) continue;
        await _repository.addBuddyToDive(diveId, buddy.id, DiveRole.buddyId);
      } catch (e, st) {
        _log.error(
          'Could not bring Suunto buddy onto dive $diveId',
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}
