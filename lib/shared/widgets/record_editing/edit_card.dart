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
  });

  /// Stable id, shared with the `cardId` of the fields it owns.
  final String id;

  /// The card's title, localised.
  final String Function(BuildContext context) title;

  /// Whether the page leaves this card out for [record] because it has
  /// nothing to show. Such a card is reached from the Add strip instead.
  final bool Function(T record) isEmpty;

  /// Builds the card's editor over [session].
  final Widget Function(BuildContext context, EditSession<T> session)
  editorBuilder;
}
