import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/reveal_answering.dart';

/// For the State of a row that edits one field of a sitting as text.
///
/// Text that is not a value never reaches the sitting, so the page has to
/// be told about it some other way: the row marks its card on the page's
/// [RecordEditController], which then keeps the card open and refuses to
/// save until the text is fixed. When the controller has had to refuse, it
/// asks the field to show itself, and the row scrolls into view
/// ([RevealAnswering], which a State mixes in before this).
///
/// The mark is withdrawn when the row goes away, so a card cannot be held
/// open by a field that is no longer on the page.
mixin RecordFieldMarks<T, W extends StatefulWidget> on RevealAnswering<W> {
  /// The card that owns the field this row edits.
  String get markCardId;

  /// The field this row edits, as the page's controller knows it.
  String get markFieldId;

  /// The page's controller, kept so the mark can be withdrawn in [dispose],
  /// where the tree can no longer be asked for it.
  RecordEditController<T>? _marksController;

  /// Whether this row has a mark standing with the controller.
  bool _marked = false;

  /// Tells the controller whether this row's text cannot be read.
  @protected
  void reportUnreadable(bool unreadable) {
    _marked = unreadable;
    _marksController?.setFieldInvalid(
      markCardId,
      markFieldId,
      invalid: unreadable,
    );
  }

  /// Withdraws a mark this row made. Called on [dispose]; call it with the
  /// old ids when the row is given another field.
  @protected
  void withdrawMark({String? cardId, String? fieldId}) {
    if (!_marked) return;
    _marked = false;
    _marksController?.setFieldInvalid(
      cardId ?? markCardId,
      fieldId ?? markFieldId,
      invalid: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = RecordEditScope.maybeOf<T>(context);
    _marksController = controller;
    // Asked for by name when a Done or a Save was refused because this
    // row's text cannot be read.
    answerReveal<T>(
      controller,
      isMine: (request) =>
          request.cardId == markCardId && request.fieldId == markFieldId,
      alignment: 0.3,
    );
  }

  @override
  void dispose() {
    withdrawMark();
    super.dispose();
  }
}
