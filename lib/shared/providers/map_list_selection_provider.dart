import 'package:submersion/core/providers/provider.dart';

/// State for map-list split pane selection and collapse state.
class MapListSelectionState {
  final String? selectedId;
  final bool isCollapsed;

  const MapListSelectionState({this.selectedId, this.isCollapsed = false});

  MapListSelectionState copyWith({
    String? selectedId,
    bool? isCollapsed,
    bool clearSelectedId = false,
  }) {
    return MapListSelectionState(
      selectedId: clearSelectedId ? null : (selectedId ?? this.selectedId),
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }
}

/// Notifier for managing map-list selection state.
class MapListSelectionNotifier extends StateNotifier<MapListSelectionState> {
  MapListSelectionNotifier() : super(const MapListSelectionState());

  void select(String id) {
    state = state.copyWith(selectedId: id);
  }

  void deselect() {
    state = state.copyWith(clearSelectedId: true);
  }

  void toggleCollapse() {
    state = state.copyWith(isCollapsed: !state.isCollapsed);
  }

  void setCollapsed(bool collapsed) {
    state = state.copyWith(isCollapsed: collapsed);
  }
}

/// Provider for map-list selection state, keyed by section
/// (e.g., 'sites', 'dive-centers').
final mapListSelectionProvider =
    StateNotifierProvider.family<
      MapListSelectionNotifier,
      MapListSelectionState,
      String
    >((ref, sectionKey) => MapListSelectionNotifier());
