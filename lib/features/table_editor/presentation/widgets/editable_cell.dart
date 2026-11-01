import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/features/table_editor/domain/cell_navigation.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';

/// The open cell of the sheet (#3422): a text field for text and numbers, a
/// pulldown for a list, a checkbox list for several values, and a toggle
/// that flips at once. Enter commits and moves down, Tab commits and moves
/// on, Shift+Tab back, Escape cancels.
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
  late final Set<String> _selected = {...widget.initialSelection};
  bool _opened = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final back = HardwareKeyboard.instance.isShiftPressed;
      widget.onCommitText(
        _controller.text,
        back ? CellMove.previous : CellMove.next,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.kind) {
      case CellEditorKind.text:
      case CellEditorKind.number:
      case CellEditorKind.integer:
        return Focus(
          onKeyEvent: _onKey,
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: Theme.of(context).textTheme.bodySmall,
            keyboardType: widget.kind == CellEditorKind.text
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (text) => widget.onCommitText(text, CellMove.down),
          ),
        );
      case CellEditorKind.toggle:
        // Opening a toggle is the edit: flip it and move on.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_opened && mounted) {
            _opened = true;
            widget.onCommitValue(!widget.initialToggle, CellMove.none);
          }
        });
        return Center(
          child: Checkbox(value: !widget.initialToggle, onChanged: null),
        );
      case CellEditorKind.choice:
      case CellEditorKind.reference:
        return Focus(
          onKeyEvent: _onKey,
          child: DropdownMenu<String?>(
            expandedInsets: EdgeInsets.zero,
            requestFocusOnTap: true,
            enableFilter: widget.kind == CellEditorKind.reference,
            initialSelection: widget.initialChoice,
            textStyle: Theme.of(context).textTheme.bodySmall,
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
            onSelected: (v) => widget.onCommitValue(v, CellMove.none),
          ),
        );
      case CellEditorKind.multiChoice:
        return Focus(
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
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              MenuAnchor(
                menuChildren: [
                  for (final o in widget.choices)
                    CheckboxMenuButton(
                      value: _selected.contains(o.value),
                      closeOnActivate: false,
                      onChanged: (on) => setState(() {
                        if (on ?? false) {
                          _selected.add(o.value);
                        } else {
                          _selected.remove(o.value);
                        }
                      }),
                      child: Text(o.label),
                    ),
                  MenuItemButton(
                    onPressed: () => widget.onCommitValue([
                      for (final o in widget.choices)
                        if (_selected.contains(o.value)) o.value,
                    ], CellMove.none),
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
