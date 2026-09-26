import 'package:equatable/equatable.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';

/// Editor modes for the profile editor.
enum EditorMode { select, smooth, outlier, draw, trim }

/// Stable tokens persisted in profile revision history for editor operations.
abstract final class ProfileEditorEditKinds {
  static const String smoothAll = 'smooth_all';
  static const String smoothSelection = 'smooth_selection';
  static const String removeAllOutliers = 'remove_all_outliers';
  static const String removeSelectedOutliers = 'remove_selected_outliers';
  static const String shiftDepth = 'shift_depth';
  static const String shiftTime = 'shift_time';
  static const String deleteSegment = 'delete_segment';
  static const String deleteSegmentInterpolated = 'delete_segment_interpolated';
  static const String generateFromWaypoints = 'generate_from_waypoints';
  static const String trimEndZeros = 'trim_end_zeros';
}

/// State for the profile editor session.
class ProfileEditorState extends Equatable {
  final List<DiveProfilePoint> originalProfile;
  final List<DiveProfilePoint> editedProfile;
  final List<List<DiveProfilePoint>> undoStack;
  final EditorMode mode;
  final List<OutlierResult>? detectedOutliers;
  final List<ProfileWaypoint>? waypoints;
  final ({int start, int end})? selectedRange;
  final bool hasChanges;
  final List<String> editKinds;
  final List<List<String>> undoEditKindsStack;

  const ProfileEditorState({
    required this.originalProfile,
    required this.editedProfile,
    this.undoStack = const [],
    this.mode = EditorMode.select,
    this.detectedOutliers,
    this.waypoints,
    this.selectedRange,
    this.hasChanges = false,
    this.editKinds = const [],
    this.undoEditKindsStack = const [],
  });

  ProfileEditorState copyWith({
    List<DiveProfilePoint>? originalProfile,
    List<DiveProfilePoint>? editedProfile,
    List<List<DiveProfilePoint>>? undoStack,
    EditorMode? mode,
    List<OutlierResult>? detectedOutliers,
    List<ProfileWaypoint>? waypoints,
    ({int start, int end})? selectedRange,
    bool? hasChanges,
    List<String>? editKinds,
    List<List<String>>? undoEditKindsStack,
    bool clearOutliers = false,
    bool clearWaypoints = false,
    bool clearRange = false,
  }) {
    return ProfileEditorState(
      originalProfile: originalProfile ?? this.originalProfile,
      editedProfile: editedProfile ?? this.editedProfile,
      undoStack: undoStack ?? this.undoStack,
      mode: mode ?? this.mode,
      detectedOutliers: clearOutliers
          ? null
          : (detectedOutliers ?? this.detectedOutliers),
      waypoints: clearWaypoints ? null : (waypoints ?? this.waypoints),
      selectedRange: clearRange ? null : (selectedRange ?? this.selectedRange),
      hasChanges: hasChanges ?? this.hasChanges,
      editKinds: editKinds ?? this.editKinds,
      undoEditKindsStack: undoEditKindsStack ?? this.undoEditKindsStack,
    );
  }

  /// Profile-editor operation token persisted into revision_kind.
  ///
  /// Multiple operations are kept in first-seen order and joined with `+`.
  /// Example: `smooth_selection+trim_end_zeros`.
  String get revisionEditKindToken =>
      editKinds.isEmpty ? 'profile_editor' : editKinds.join('+');

  @override
  List<Object?> get props => [
    originalProfile,
    editedProfile,
    undoStack,
    mode,
    detectedOutliers,
    waypoints,
    selectedRange,
    hasChanges,
    editKinds,
    undoEditKindsStack,
  ];
}

/// Manages profile editing session state.
class ProfileEditorNotifier extends StateNotifier<ProfileEditorState> {
  final ProfileEditingService _service;

  ProfileEditorNotifier({
    required List<DiveProfilePoint> originalProfile,
    required ProfileEditingService editingService,
  }) : _service = editingService,
       super(
         ProfileEditorState(
           originalProfile: originalProfile,
           editedProfile: originalProfile,
         ),
       );

  void setMode(EditorMode mode) {
    state = state.copyWith(mode: mode);
  }

  void _pushUndo() {
    state = state.copyWith(
      undoStack: [...state.undoStack, state.editedProfile],
      undoEditKindsStack: [...state.undoEditKindsStack, state.editKinds],
    );
  }

  void _recordEditKind(String editKind) {
    if (state.editKinds.contains(editKind)) return;
    state = state.copyWith(editKinds: [...state.editKinds, editKind]);
  }

  void undo() {
    if (state.undoStack.isEmpty) return;

    final previous = state.undoStack.last;
    final newStack = state.undoStack.sublist(0, state.undoStack.length - 1);
    final previousKinds = state.undoEditKindsStack.last;
    final newKindsStack = state.undoEditKindsStack.sublist(
      0,
      state.undoEditKindsStack.length - 1,
    );

    state = state.copyWith(
      editedProfile: previous,
      undoStack: newStack,
      editKinds: previousKinds,
      undoEditKindsStack: newKindsStack,
      hasChanges: newStack.isNotEmpty,
    );
  }

  void applySmoothing({int windowSize = 5}) {
    _pushUndo();
    final smoothed = _service.smoothProfile(
      state.editedProfile,
      windowSize: windowSize,
    );
    state = state.copyWith(editedProfile: smoothed, hasChanges: true);
    _recordEditKind(ProfileEditorEditKinds.smoothAll);
  }

  void applySmoothingToRange({int windowSize = 5}) {
    final range = state.selectedRange;
    if (range == null) return;

    _pushUndo();
    final rangePoints = state.editedProfile
        .where((p) => p.timestamp >= range.start && p.timestamp <= range.end)
        .toList();
    final smoothed = _service.smoothProfile(
      rangePoints,
      windowSize: windowSize,
    );

    final smoothedMap = {for (final p in smoothed) p.timestamp: p};
    final result = state.editedProfile.map((p) {
      return smoothedMap[p.timestamp] ?? p;
    }).toList();

    state = state.copyWith(editedProfile: result, hasChanges: true);
    _recordEditKind(ProfileEditorEditKinds.smoothSelection);
  }

  void detectOutliers() {
    final outliers = _service.detectOutliers(state.editedProfile);
    state = state.copyWith(detectedOutliers: outliers);
  }

  void removeAllOutliers() {
    final outliers = state.detectedOutliers;
    if (outliers == null || outliers.isEmpty) return;

    _pushUndo();
    final cleaned = _service.removeOutliers(state.editedProfile, outliers);
    state = state.copyWith(
      editedProfile: cleaned,
      hasChanges: true,
      clearOutliers: true,
    );
    _recordEditKind(ProfileEditorEditKinds.removeAllOutliers);
  }

  void removeSelectedOutliers(List<OutlierResult> selected) {
    if (selected.isEmpty) return;

    _pushUndo();
    final cleaned = _service.removeOutliers(state.editedProfile, selected);
    final remaining = _service.detectOutliers(cleaned);
    state = state.copyWith(
      editedProfile: cleaned,
      detectedOutliers: remaining,
      hasChanges: true,
    );
    _recordEditKind(ProfileEditorEditKinds.removeSelectedOutliers);
  }

  void shiftSegmentDepth(double depthDelta) {
    final range = state.selectedRange;
    if (range == null) return;

    _pushUndo();
    final shifted = _service.shiftSegmentDepth(
      state.editedProfile,
      startTimestamp: range.start,
      endTimestamp: range.end,
      depthDelta: depthDelta,
    );
    state = state.copyWith(editedProfile: shifted, hasChanges: true);
    _recordEditKind(ProfileEditorEditKinds.shiftDepth);
  }

  void shiftSegmentTime(int timeDelta) {
    final range = state.selectedRange;
    if (range == null) return;

    final shifted = _service.shiftSegmentTime(
      state.editedProfile,
      startTimestamp: range.start,
      endTimestamp: range.end,
      timeDelta: timeDelta,
    );
    if (shifted == null) return; // Overlap detected

    _pushUndo();
    state = state.copyWith(editedProfile: shifted, hasChanges: true);
    _recordEditKind(ProfileEditorEditKinds.shiftTime);
  }

  void deleteSegment({bool interpolateGap = false}) {
    final range = state.selectedRange;
    if (range == null) return;

    _pushUndo();
    final result = _service.deleteSegment(
      state.editedProfile,
      startTimestamp: range.start,
      endTimestamp: range.end,
      interpolateGap: interpolateGap,
    );
    state = state.copyWith(
      editedProfile: result,
      hasChanges: true,
      clearRange: true,
    );
    _recordEditKind(
      interpolateGap
          ? ProfileEditorEditKinds.deleteSegmentInterpolated
          : ProfileEditorEditKinds.deleteSegment,
    );
  }

  void setSelectedRange({required int start, required int end}) {
    state = state.copyWith(selectedRange: (start: start, end: end));
  }

  void clearSelectedRange() {
    state = state.copyWith(clearRange: true);
  }

  // --- Draw mode ---

  void addWaypoint(ProfileWaypoint waypoint) {
    final current = state.waypoints ?? [];
    final updated = [...current, waypoint]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = state.copyWith(waypoints: updated);
  }

  void removeWaypoint(int index) {
    final current = state.waypoints;
    if (current == null || index < 0 || index >= current.length) return;

    final updated = [
      ...current.sublist(0, index),
      ...current.sublist(index + 1),
    ];
    state = state.copyWith(waypoints: updated);
  }

  void updateWaypoint(int index, ProfileWaypoint waypoint) {
    final current = state.waypoints;
    if (current == null || index < 0 || index >= current.length) return;

    final updated = [
      for (int i = 0; i < current.length; i++)
        if (i == index) waypoint else current[i],
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = state.copyWith(waypoints: updated);
  }

  void clearWaypoints() {
    state = state.copyWith(clearWaypoints: true);
  }

  void generateProfileFromWaypoints({int intervalSeconds = 4}) {
    final waypoints = state.waypoints;
    if (waypoints == null || waypoints.isEmpty) return;

    _pushUndo();
    final generated = _service.interpolateWaypoints(
      waypoints,
      intervalSeconds: intervalSeconds,
    );
    state = state.copyWith(editedProfile: generated, hasChanges: true);
    _recordEditKind(ProfileEditorEditKinds.generateFromWaypoints);
  }

  /// Trim trailing zero-depth points from the profile, keeping the last one.
  void trimEndZeros() {
    final profile = state.editedProfile;
    if (profile.length < 2) return;

    final trimmed = _service.trimEndZeros(profile);
    if (trimmed.length == profile.length) return;

    _pushUndo();
    state = state.copyWith(editedProfile: trimmed, hasChanges: true);
    _recordEditKind(ProfileEditorEditKinds.trimEndZeros);
  }
}
