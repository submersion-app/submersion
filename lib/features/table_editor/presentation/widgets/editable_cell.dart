import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/features/table_editor/domain/cell_navigation.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';

/// The open cell of the sheet (#3422): a text field for text and numbers, a
/// pulldown for a list, a checkbox list for several values, and a checkbox
/// for a toggle reached by keyboard. Enter commits and moves down, Tab
/// commits and moves on, Shift+Tab back, Escape cancels. Leaving the cell
/// any other way (a click elsewhere, the sheet rebuilding) commits what was
/// typed, as a spreadsheet does; nothing typed is ever silently dropped.
class EditableCell extends StatefulWidget {
  final CellEditorKind kind;
  final String initialText;
  final List<ChoiceOption> choices;
  final bool initialToggle;
  final String? initialChoice;
  final List<String> initialSelection;
  final String doneLabel;
  final void Function(String text, CellMove move) onCommitText;
  final void Function(Object? value, CellMove move) onCommitValue;
  final VoidCallback onCancel;

  const EditableCell({
    super.key,
    required this.kind,
    required this.initialText,
    required this.choices,
    required this.onCommitText,
    required this.onCommitValue,
    required this.onCancel,
    this.initialToggle = false,
    this.initialChoice,
    this.initialSelection = const [],
    this.doneLabel = '',
  });

  @override
  State<EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<EditableCell> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialText.length,
        );
  final _focus = FocusNode();
  late Set<String> _selected = {...widget.initialSelection};
  late String? _choice = widget.initialChoice;
  late bool _toggle = widget.initialToggle;

  /// Set once the cell has committed or cancelled, so a focus loss or the
  /// disposal that follows never commits a second time.
  bool _done = false;

  bool get _isText =>
      widget.kind == CellEditorKind.text ||
      widget.kind == CellEditorKind.number ||
      widget.kind == CellEditorKind.integer;

  @override
  void initState() {
    super.initState();
    if (!_isText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (!_done) {
      // The sheet moved on (another cell was tapped, a paste landed): keep
      // what was typed. Deferred, since the sheet is mid-rebuild.
      _done = true;
      final text = _controller.text;
      final value = _currentValue;
      final isText = _isText;
      final commitText = widget.onCommitText;
      final commitValue = widget.onCommitValue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isText) {
          commitText(text, CellMove.none);
        } else {
          commitValue(value, CellMove.none);
        }
      });
    }
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Object? get _currentValue => switch (widget.kind) {
    CellEditorKind.toggle => _toggle,
    CellEditorKind.choice || CellEditorKind.reference => _choice,
    CellEditorKind.multiChoice => [
      for (final o in widget.choices)
        if (_selected.contains(o.value)) o.value,
    ],
    _ => null,
  };

  void _finish(void Function() commit) {
    if (_done) return;
    _done = true;
    commit();
  }

  void _commitMove(CellMove move) => _finish(() {
    if (_isText) {
      widget.onCommitText(_controller.text, move);
    } else {
      widget.onCommitValue(_currentValue, move);
    }
  });

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _finish(widget.onCancel);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _commitMove(
        HardwareKeyboard.instance.isShiftPressed
            ? CellMove.previous
            : CellMove.next,
      );
      return KeyEventResult.handled;
    }
    if (!_isText && event.logicalKey == LogicalKeyboardKey.enter) {
      _commitMove(CellMove.down);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChange(bool hasFocus) {
    // A click on a button or another focusable control takes the focus:
    // keep the text, stay where the click went.
    if (!hasFocus && _isText) _commitMove(CellMove.none);
  }

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    switch (widget.kind) {
      case CellEditorKind.text:
      case CellEditorKind.number:
      case CellEditorKind.integer:
        return Focus(
          onKeyEvent: _onKey,
          onFocusChange: _onFocusChange,
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: small,
            keyboardType: widget.kind == CellEditorKind.text
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _commitMove(CellMove.down),
          ),
        );
      case CellEditorKind.toggle:
        return Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          child: Center(
            child: Checkbox(
              value: _toggle,
              onChanged: (v) {
                _toggle = v ?? false;
                _commitMove(CellMove.none);
              },
            ),
          ),
        );
      case CellEditorKind.choice:
      case CellEditorKind.reference:
        return Focus(
          onKeyEvent: _onKey,
          child: DropdownMenu<String?>(
            focusNode: _focus,
            expandedInsets: EdgeInsets.zero,
            requestFocusOnTap: true,
            enableFilter: widget.kind == CellEditorKind.reference,
            initialSelection: widget.initialChoice,
            textStyle: small,
            inputDecorationTheme: const InputDecorationTheme(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(),
            ),
            dropdownMenuEntries: [
              const DropdownMenuEntry<String?>(value: null, label: ''),
              for (final o in widget.choices)
                DropdownMenuEntry<String?>(value: o.value, label: o.label),
            ],
            onSelected: (v) {
              _choice = v;
              _commitMove(CellMove.none);
            },
          ),
        );
      case CellEditorKind.multiChoice:
        return Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  [
                    for (final o in widget.choices)
                      if (_selected.contains(o.value)) o.label,
                  ].join(', '),
                  overflow: TextOverflow.ellipsis,
                  style: small,
                ),
              ),
              MenuAnchor(
                menuChildren: [
                  for (final o in widget.choices)
                    CheckboxMenuButton(
                      value: _selected.contains(o.value),
                      closeOnActivate: false,
                      onChanged: (on) => setState(() {
                        _selected = {..._selected};
                        if (on ?? false) {
                          _selected.add(o.value);
                        } else {
                          _selected.remove(o.value);
                        }
                      }),
                      child: Text(o.label),
                    ),
                  MenuItemButton(
                    onPressed: () => _commitMove(CellMove.none),
                    child: Text(widget.doneLabel),
                  ),
                ],
                builder: (context, controller, _) => IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
            ],
          ),
        );
    }
  }
}
