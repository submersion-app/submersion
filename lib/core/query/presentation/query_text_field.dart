import 'package:flutter/material.dart';

import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_completions.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_error_controller.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';

/// The typed editor of a query tree (#2365, spec Unit 6 "Text").
///
/// Every keystroke is parsed and validated. Only a clean tree reaches
/// [onChanged]; a failure underlines its span, names it under the field and
/// offers the parser's suggestions as chips. Completions for the word at the
/// caret show as chips too. A [value] set from outside (a chip removed, a
/// saved query applied) is printed back into the field.
class QueryTextField extends StatefulWidget {
  const QueryTextField({
    super.key,
    required this.context,
    required this.value,
    required this.onChanged,
    this.hintText = '',
    this.describeError,
    this.fieldKey,
    this.autofocus = false,
  });

  final QueryEditorContext context;
  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;
  final String hintText;
  final String Function(QueryError error)? describeError;
  final Key? fieldKey;
  final bool autofocus;

  @override
  State<QueryTextField> createState() => _QueryTextFieldState();
}

class _QueryTextFieldState extends State<QueryTextField> {
  late final QueryErrorHighlightController _controller;
  final _focus = FocusNode();
  QueryError? _error;
  List<Completion> _completions = const [];

  /// The last tree this field committed, so an outside [widget.value] equal
  /// to it does not rewrite the text under the diver's cursor.
  QueryNode? _committed;

  @override
  void initState() {
    super.initState();
    _committed = widget.value;
    _controller = QueryErrorHighlightController(
      text: widget.context.printer.print(widget.value),
    );
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void didUpdateWidget(QueryTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _committed) {
      _committed = widget.value;
      _controller
        ..text = widget.context.printer.print(widget.value)
        ..setError();
      _error = null;
      _completions = const [];
    } else if (widget.context.prefs != old.context.prefs && _error == null) {
      // The unit setting changed: the same tree reads differently now.
      _controller.text = widget.context.printer.print(_committed);
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final caret = _controller.selection.isValid
        ? _controller.selection.extentOffset
        : text.length;
    final completions = completionsAt(text, caret, widget.context);
    if (text.trim().isEmpty) {
      _commit(null);
      _controller.setError();
      setState(() {
        _error = null;
        _completions = completions;
      });
      return;
    }
    switch (widget.context.parser.parse(text)) {
      case ParseOk(:final node):
        final errors = validateQuery(
          node,
          widget.context.root,
          widget.context.registry,
        );
        if (errors.isEmpty) {
          _commit(normalizeQuery(node));
          _controller.setError();
          setState(() {
            _error = null;
            _completions = completions;
          });
        } else {
          _showError(errors.first, completions);
        }
      case ParseFailure(:final error):
        _showError(error, completions);
    }
  }

  void _commit(QueryNode? node) {
    if (node == _committed) return;
    _committed = node;
    widget.onChanged(node);
  }

  void _showError(QueryError error, List<Completion> completions) {
    _controller.setError(offset: error.offset, length: error.length);
    setState(() {
      _error = error;
      _completions = completions;
    });
  }

  void _replace(int start, int length, String text) {
    final current = _controller.text;
    final end = (start + length).clamp(start, current.length);
    final next = current.replaceRange(start, end, text);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _onTextChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    _controller.errorColor = Theme.of(context).colorScheme.error;
    final describe = widget.describeError ?? (QueryError e) => e.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: widget.fieldKey,
          controller: _controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _replace(0, _controller.text.length, ''),
                  ),
            errorText: error == null ? null : describe(error),
          ),
          onChanged: _onTextChanged,
        ),
        if (error != null && error.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in error.suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.error_outline, size: 16),
                    label: Text(s),
                    onPressed: () =>
                        _replace(error.offset ?? 0, error.length ?? 0, s),
                  ),
              ],
            ),
          )
        else if (_completions.isNotEmpty && (_focus.hasFocus || error == null))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final c in _completions)
                  ActionChip(
                    label: Text(c.text),
                    onPressed: () =>
                        _replace(c.replaceStart, c.replaceLength, c.text),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
