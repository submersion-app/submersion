import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/shared/selection/select_items_menu_entries.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

/// The bulk selection a list page owns for its table mode.
///
/// In table mode the header, and the overflow menu holding "Select items",
/// belong to the page ([TableModeLayout]), while the rows live in the list.
/// The page owns this controller and hands it to the list's
/// `selectionController`, so both reach the same state (issue #2775).
mixin TableSelectionOwner<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Passed to the table content as its `selectionController`.
  final SelectionController tableSelection = SelectionController();

  /// Ends the selection when [viewMode] leaves table mode. Call from `build`.
  ///
  /// Selection does not survive leaving the surface. The reset happens as the
  /// mode changes rather than as the table leaves the tree, because the tree
  /// is locked then and nothing listening to the controller could be told.
  void resetTableSelectionOffTable(ProviderListenable<ListViewMode> viewMode) {
    ref.listen<ListViewMode>(viewMode, (_, next) {
      if (next != ListViewMode.table) tableSelection.exit();
    });
  }

  /// "Select items" and its divider, for the top of the table header's
  /// overflow menu.
  ///
  /// Read as the menu opens, and empty while selecting, where the entry would
  /// do nothing.
  List<PopupMenuEntry<String>> tableSelectItemsEntries(BuildContext context) =>
      tableSelection.value.isActive
      ? const []
      : selectItemsMenuEntries(context, onSelect: tableSelection.enterExplicit);

  @override
  void dispose() {
    tableSelection.dispose();
    super.dispose();
  }
}
