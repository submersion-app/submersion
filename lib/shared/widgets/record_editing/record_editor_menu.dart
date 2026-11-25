import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

/// A whole-record operation in an editor's bar menu (issue #4527, phase 4,
/// decision 3): a transmitter's Remove key, a template's Delete. It acts on
/// the stored record at once, as its own History entry, so it waits until
/// the editor has nothing to save.
class RecordEditorOperation {
  const RecordEditorOperation({
    required this.key,
    required this.icon,
    required this.label,
    required this.run,
    this.destructive = false,
  });

  /// The menu item's key.
  final Key key;
  final IconData icon;
  final String label;

  /// Asks its own confirmation, writes, and answers whether it wrote. The
  /// editor's page leaves when it did.
  final Future<bool> Function() run;

  /// Drawn in the error colour, as a record page's Delete is.
  final bool destructive;
}

/// The bar menu of an editor with whole-record operations: the reason they
/// are unavailable while there are unsaved changes, then each operation,
/// enabled only while it may run. [onSelected] runs the one chosen.
class RecordEditorMenu extends StatelessWidget {
  const RecordEditorMenu({
    super.key,
    required this.controller,
    required this.operations,
    required this.onSelected,
  });

  final RecordEditController<Object?> controller;
  final List<RecordEditorOperation> operations;
  final ValueChanged<RecordEditorOperation> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      key: const ValueKey('recordEditorMenu'),
      icon: const Icon(Icons.more_vert),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (index) => onSelected(operations[index]),
      // Built as the menu opens, so it reads the sitting as it is then.
      itemBuilder: (context) {
        final available = recordOperationsAvailable(controller);
        final error = Theme.of(context).colorScheme.error;
        return [
          ...recordOperationMenuCaption<int>(context, controller),
          for (var i = 0; i < operations.length; i++)
            PopupMenuItem<int>(
              key: operations[i].key,
              value: i,
              enabled: available,
              child: ListTile(
                leading: Icon(
                  operations[i].icon,
                  color: operations[i].destructive && available ? error : null,
                ),
                title: Text(
                  operations[i].label,
                  style: operations[i].destructive && available
                      ? TextStyle(color: error)
                      : null,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ];
      },
    );
  }
}
