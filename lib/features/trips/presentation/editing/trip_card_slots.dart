import 'package:flutter/widgets.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// What a trip page that edits in place (issue #4527, phase 3) hands the
/// widgets of its tabs, several layers down: the trip as the cards show
/// it, and the frame each card sits in.
///
/// Absent ([TripCardSlotsScope.maybeOf] is null) the page only reads, as
/// it always has.
@immutable
class TripCardSlots {
  const TripCardSlots({
    required this.shown,
    required this.layout,
    required this.session,
    required this.frame,
    required this.dayPlanFrame,
    required this.showsWhileEmpty,
    required this.openCard,
    required this.unlockAt,
    required this.isOpen,
  });

  /// The trip the cards show: the sitting's while unlocked.
  final Trip shown;

  /// The trip the Overview lays itself out from: the stored one while a
  /// sitting is open, so the prepare page does not turn into the story
  /// under the diver when the start date moves past today. It changes at
  /// Save.
  final Trip layout;

  /// The open sitting; null while locked.
  final EditSession<Trip>? session;

  /// [child] framed as the card [id]: its pencil, its changed dot, and its
  /// editor in place of it while open.
  final Widget Function(TripCardId id, Widget child) frame;

  /// [child], a day's Day plan on the story, framed as the Notes card there:
  /// its editor holds that day's passage of the notes.
  final Widget Function(TripNoteDay day, Widget child) dayPlanFrame;

  /// Whether the empty card [id] shows in the sitting: open, or brought in
  /// from the strip.
  final bool Function(TripCardId id) showsWhileEmpty;

  /// Opens the card [id], unlocking the page first when it is locked: the
  /// Plan row and a day's note button do what their edit addresses do.
  final void Function(TripCardId id) openCard;

  /// Unlocks the page when it is locked and brings [id]'s tab forward;
  /// answers the open sitting, or null when the page could not unlock. For
  /// the cards a tab edits in place, with no frame: a locked tab's Scan
  /// unlocks, then scans into the sitting.
  final EditSession<Trip>? Function(TripCardId id) unlockAt;

  /// Whether the card [id]'s editor is open. None is while locked.
  final bool Function(TripCardId id) isOpen;

  bool get isUnlocked => session != null;
}

/// Puts [slots] where the trip page's tabs can find them.
class TripCardSlotsScope extends InheritedWidget {
  const TripCardSlotsScope({
    super.key,
    required this.slots,
    required super.child,
  });

  final TripCardSlots slots;

  /// The trip page's slots, or null where the page only reads.
  static TripCardSlots? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripCardSlotsScope>()?.slots;

  @override
  bool updateShouldNotify(TripCardSlotsScope oldWidget) =>
      !identical(slots, oldWidget.slots);
}
