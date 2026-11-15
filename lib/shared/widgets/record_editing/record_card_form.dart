import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// A [Form] around fields that carry their own validators, such as the
/// cylinder and weight rows a card editor shares with the dive form.
///
/// Outside a form those validators never run, so nothing would stop a
/// card holding an O2 that cannot be read from closing or being saved.
/// This validates once when first built and after every change, and
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = RecordEditScope.maybeOf<T>(context);
  }

  /// Validates after the frame: a field reports its change before it has
  /// rebuilt, and validating marks every field to rebuild.
  void _scheduleReport() {
    if (_reportPending) return;
    _reportPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportPending = false;
      if (!mounted) return;
      final valid = _formKey.currentState?.validate() ?? true;
      _controller?.setFieldInvalid(
        widget.cardId,
        widget.fieldId,
        invalid: !valid,
      );
    });
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
