import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// What a record type supplies for one card of its page that can be edited
/// in place.
///
/// Which values the card owns is carried by the fields themselves
/// (`EditField.cardId`), so a card and its fields cannot disagree.
@immutable
class EditCard<T> {
  const EditCard({
    required this.id,
    required this.title,
    required this.isEmpty,
    required this.editorBuilder,
    this.leading,
    this.isValid,
    this.isEmptyInSitting,
    this.offeredWhenEmpty,
  });

  /// Stable id, shared with the `cardId` of the fields it owns.
  final String id;

  /// The card's title, localised.
  final String Function(BuildContext context) title;

  /// What the card draws before its title, such as its icon, so the open
  /// card's header matches the one the card shows while reading.
  final Widget Function(BuildContext context)? leading;

  /// Whether the page leaves this card out for [record] because it has
  /// nothing to show. Such a card is reached from the Add strip instead.
  final bool Function(T record) isEmpty;

  /// Whether the sitting's values for this card can be saved. Asked of
  /// every card at Save, open or closed, so it reads the sitting, never the
  /// card's widgets. Null means always.
  final bool Function(EditSession<T> session)? isValid;

  /// For a card whose content is rows of its own rather than values of the
  /// record (a dive's buddies, its sightings, its photos): whether it has
  /// nothing to show in [session]. Asked in place of [isEmpty] while
  /// unlocked. Locked, such a card's read widget decides for itself, and
  /// its [isEmpty] says false.
  final bool Function(EditSession<T> session)? isEmptyInSitting;

  /// Whether the Add strip offers this card while it is off the page, as
  /// distinct from hidden by the diver. Null is always. A card that has
  /// nothing to edit until something else exists says no.
  final bool Function(EditSession<T> session)? offeredWhenEmpty;

  /// Whether the card has nothing to show for [record], or, during
  /// [session], for the sitting when it holds rows of its own
  /// ([isEmptyInSitting]).
  bool isEmptyDuring(T record, EditSession<T>? session) {
    final inSitting = isEmptyInSitting;
    if (session != null && inSitting != null) return inSitting(session);
    return isEmpty(record);
  }

  /// Whether the Add strip offers this card in [session] while it is off
  /// the page ([offeredWhenEmpty]).
  bool isOfferedWhenEmpty(EditSession<T> session) =>
      offeredWhenEmpty?.call(session) ?? true;

  /// Builds the card's editor over [session].
  final Widget Function(BuildContext context, EditSession<T> session)
  editorBuilder;
}
