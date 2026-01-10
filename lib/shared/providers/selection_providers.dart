import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Helper class for reading selected item ID from URL query parameters.
///
/// The master-detail layout uses URL query params (`?selected=id`) as the
/// source of truth for selection state. This enables:
/// - Deep linking (sharable URLs)
/// - Browser back button support
/// - State persistence across refreshes
class SelectionHelper {
  SelectionHelper._();

  /// Get the currently selected item ID from URL query params.
  ///
  /// Returns null if no item is selected.
  static String? getSelectedId(BuildContext context) {
    final state = GoRouterState.of(context);
    return state.uri.queryParameters['selected'];
  }

  /// Select an item by updating URL query params.
  ///
  /// On desktop, updates the URL to include `?selected=id`.
  /// On mobile, this should not be called - use navigation instead.
  static void selectItem(BuildContext context, String? itemId) {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;

    if (itemId != null) {
      router.go('$currentPath?selected=$itemId');
    } else {
      router.go(currentPath);
    }
  }

  /// Clear the current selection.
  static void clearSelection(BuildContext context) {
    selectItem(context, null);
  }
}

/// Provider that exposes the selected item ID for a given context.
///
/// This is primarily for use in widgets that need to react to selection
/// changes but don't have direct access to the MasterDetailScaffold.
///
/// Usage:
/// ```dart
/// final selectedId = ref.watch(selectedItemProvider(context));
/// ```
///
/// Note: This requires passing BuildContext, which is unusual for providers.
/// For most cases, read the selection directly in the widget using
/// `SelectionHelper.getSelectedId(context)`.
final selectedItemProvider = Provider.family<String?, BuildContext>((
  ref,
  context,
) {
  return SelectionHelper.getSelectedId(context);
});
