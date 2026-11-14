import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// For the State of a row that edits one field of a sitting as text.
///
/// Text that is not a value never reaches the sitting, so the page has to
/// be told about it some other way: the row marks its card on the page's
/// [RecordEditController], which then keeps the card open and refuses to
/// save until the text is fixed. When the controller has had to refuse, it
/// asks the field to show itself, and the row scrolls into view.
///
/// The mark is withdrawn when the row goes away, so a card cannot be held
/// open by a field that is no longer on the page.
mixin RecordFieldMarks<T, W extends StatefulWidget> on State<W> {
  /// The card that owns the field this row edits.
  String get markCardId;

  /// The field this row edits, as the page's controller knows it.
  String get markFieldId;

  /// The page's controller, kept so the mark can be withdrawn in [dispose],
  /// where the tree can no longer be asked for it.
  RecordEditController<T>? _marksController;

  /// The last request to show itself this row answered.
  int _answeredSerial = 0;

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
    _answerReveal(controller);
  }

  /// Scrolls this row into view when the controller asks for its field: a
  /// Done or a Save was refused because its text cannot be read.
  void _answerReveal(RecordEditController<T>? controller) {
    final request = controller?.revealRequest;
    if (controller == null || request == null) return;
    if (request.cardId != markCardId ||
        request.fieldId != markFieldId ||
        request.serial == _answeredSerial) {
      return;
    }
    _answeredSerial = request.serial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.revealHandled(request.serial);
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  @override
  void dispose() {
    withdrawMark();
    super.dispose();
  }
}
