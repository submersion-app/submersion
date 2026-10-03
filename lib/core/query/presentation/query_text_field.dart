import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_completions.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_error_controller.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';

/// Whether [error]'s suggestions can replace a span of [text]: they need
/// a place in the text to go. A validator error names a path, not a
/// position, and a chip for it would insert at the start of the field.
bool suggestionsReplaceSpan(QueryError error, String text) {
  final offset = error.offset;
  final length = error.length;
  return error.suggestions.isNotEmpty &&
      offset != null &&
      length != null &&
      offset >= 0 &&
      length >= 0 &&
      offset + length <= text.length;
}

/// A request to show [text] in a [QueryTextField] without committing it
/// (Ask's Undo puts the sentence back this way). Compared by identity, so
/// each new instance is applied once, after any new value in the same
/// update.
class QueryTextOverride {
  QueryTextOverride(this.text);
  final String text;
}

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
    this.focusNode,
    this.onEscape,
    this.onValidityChanged,
    this.onTextChanged,
    this.textOverride,
    this.shortcuts = const {},
  });

  final QueryEditorContext context;
  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;
  final String hintText;
  final String Function(QueryError error)? describeError;
  final Key? fieldKey;
  final bool autofocus;

  /// Focus for the text field; the field makes and disposes its own when
  /// null. An outside node stays the caller's to dispose.
  final FocusNode? focusNode;

  /// Called on Escape while the field has focus.
  final VoidCallback? onEscape;

  /// Called with false when the text stops parsing (the last valid value
  /// stays committed, so [onChanged] says nothing) and with true once it
  /// parses again or is emptied.
  final ValueChanged<bool>? onValidityChanged;

  /// Called with the raw text on every edit by the diver, whether or not
  /// it parses.
  final ValueChanged<String>? onTextChanged;

  /// Text to show without committing it; see [QueryTextOverride].
  final QueryTextOverride? textOverride;

  /// Extra key bindings active while the field has focus.
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  @override
  State<QueryTextField> createState() => _QueryTextFieldState();
}

class _QueryTextFieldState extends State<QueryTextField> {
  late final QueryErrorHighlightController _controller;
  final _ownFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownFocus;
  QueryError? _error;
  List<Completion> _completions = const [];
  bool _valid = true;

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
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus).removeListener(_onFocusChange);
      _focus.addListener(_onFocusChange);
    }
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
    } else if (widget.context.names != old.context.names && _error != null) {
      // The name index arrived or changed: text that named something it
      // did not know may resolve now. After the frame, since committing
      // calls the parent back and this runs inside its build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onTextChanged(_controller.text);
      });
    }
    final override = widget.textOverride;
    if (override != null && !identical(override, old.textOverride)) {
      // After a new value in the same update, so the override wins. The
      // committed tree stays as it is: the text is shown, not applied.
      _controller
        ..text = override.text
        ..selection = TextSelection.collapsed(offset: override.text.length)
        ..setError();
      _error = null;
      _completions = const [];
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _ownFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// An edit by the diver (typing, or a completion or suggestion they
  /// picked): reported, then parsed.
  void _onEdited(String text) {
    widget.onTextChanged?.call(text);
    _onTextChanged(text);
  }

  /// Parses [text] and commits it when valid. Also re-run without an edit
  /// (the name index changed), which [QueryTextField.onTextChanged] does
  /// not hear about.
  void _onTextChanged(String text) {
    final caret = _controller.selection.isValid
        ? _controller.selection.extentOffset
        : text.length;
    final completions = completionsAt(text, caret, widget.context);
    if (text.trim().isEmpty) {
      _commit(null);
      _setValid(true);
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
          _setValid(true);
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

  void _setValid(bool valid) {
    if (valid == _valid) return;
    _valid = valid;
    widget.onValidityChanged?.call(valid);
  }

  void _commit(QueryNode? node) {
    if (node == _committed) return;
    _committed = node;
    widget.onChanged(node);
  }

  void _showError(QueryError error, List<Completion> completions) {
    _setValid(false);
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
    _onEdited(next);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    _controller.errorColor = Theme.of(context).colorScheme.error;
    final describe = widget.describeError ?? (QueryError e) => e.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CallbackShortcuts(
          bindings: {
            ...widget.shortcuts,
            if (widget.onEscape != null)
              const SingleActivator(LogicalKeyboardKey.escape):
                  widget.onEscape!,
          },
          child: TextField(
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
              // The hint is prose: in the field's monospace it is too wide
              // for a phone's search row.
              hintStyle: TextStyle(
                fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _replace(0, _controller.text.length, ''),
                    ),
              errorText: error == null ? null : describe(error),
            ),
            onChanged: _onEdited,
          ),
        ),
        if (error != null && suggestionsReplaceSpan(error, _controller.text))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in error.suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.error_outline, size: 16),
                    label: Text(s),
                    onPressed: () => _replace(error.offset!, error.length!, s),
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
