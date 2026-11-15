import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// A [Form] around fields that carry their own validators, such as the
/// cylinder and weight rows a card editor shares with the dive form.
///
/// Outside a form those validators never run, so nothing would stop a
/// card holding an O2 that cannot be read from closing or being saved.
/// This checks its fields once when first built, after every change, and
/// whenever it is rebuilt from above, shows the errors they give, and
/// reports the result to the page's controller as field [fieldId] of
/// [cardId]: Done and Save then refuse while any field shows an error, as
/// they do for unreadable input. Disposed, it withdraws its report.
class RecordCardForm<T> extends StatefulWidget {
  const RecordCardForm({
    super.key,
    required this.cardId,
    this.fieldId = 'form',
    required this.child,
  });

  final String cardId;
  final String fieldId;
  final Widget child;

  @override
  State<RecordCardForm<T>> createState() => _RecordCardFormState<T>();
}

class _RecordCardFormState<T> extends State<RecordCardForm<T>> {
  final _formKey = GlobalKey<FormState>();

  /// Looked up while mounted: [dispose] cannot reach the scope.
  RecordEditController<T>? _controller;
  bool _reportPending = false;

  @override
  void initState() {
    super.initState();
    _scheduleReport();
  }

  /// Rebuilt from above: another card may have changed what a field checks
  /// against (the header's runtime bounds a gas switch time) with no
  /// keystroke here, so the fields are checked again.
  @override
  void didUpdateWidget(RecordCardForm<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleReport();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = RecordEditScope.maybeOf<T>(context);
  }

  /// Checks after the frame: a field reports its change before it has
  /// rebuilt. Each field is asked whether its value passes without being
  /// rebuilt ([FormFieldState.isValid]); the form validates, which rebuilds
  /// every field, only when an error must appear or go.
  void _scheduleReport() {
    if (_reportPending) return;
    _reportPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportPending = false;
      if (!mounted) return;
      final fields = _fields();
      final valid = fields.every((f) => f.isValid);
      if (fields.any((f) => f.hasError == f.isValid)) {
        _formKey.currentState?.validate();
      }
      _controller?.setFieldInvalid(
        widget.cardId,
        widget.fieldId,
        invalid: !valid,
      );
    });
  }

  /// The form's fields, found under it.
  List<FormFieldState<Object?>> _fields() {
    final found = <FormFieldState<Object?>>[];
    void visit(Element element) {
      if (element is StatefulElement && element.state is FormFieldState) {
        found.add(element.state as FormFieldState<Object?>);
      }
      element.visitChildren(visit);
    }

    _formKey.currentContext?.visitChildElements(visit);
    return found;
  }

  @override
  void dispose() {
    _controller?.setFieldInvalid(widget.cardId, widget.fieldId, invalid: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(key: _formKey, onChanged: _scheduleReport, child: widget.child);
  }
}
