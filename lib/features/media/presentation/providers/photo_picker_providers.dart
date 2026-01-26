import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service_desktop.dart';
import 'package:submersion/features/media/data/services/photo_picker_service_mobile.dart';

/// Provider for the platform-appropriate PhotoPickerService.
///
/// Returns PhotoPickerServiceMobile on iOS, Android, and macOS.
/// Returns PhotoPickerServiceDesktop on Windows and Linux.
final photoPickerServiceProvider = Provider<PhotoPickerService>((ref) {
  if (Platform.isWindows || Platform.isLinux) {
    return PhotoPickerServiceDesktop();
  }
  return PhotoPickerServiceMobile();
});

/// Parameters for photo picker date range query.
class PhotoPickerParams {
  final DateTime startTime;
  final DateTime endTime;

  const PhotoPickerParams({required this.startTime, required this.endTime});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoPickerParams &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => Object.hash(startTime, endTime);
}

/// Provider for fetching assets in a date range.
///
/// Pass [PhotoPickerParams] with the dive's time window (with buffer).
final assetsInDateRangeProvider =
    FutureProvider.family<List<AssetInfo>, PhotoPickerParams>((
      ref,
      params,
    ) async {
      final service = ref.watch(photoPickerServiceProvider);
      return service.getAssetsInDateRange(params.startTime, params.endTime);
    });

/// Provider for photo library permission status.
final photoPermissionProvider = FutureProvider<PhotoPermissionStatus>((
  ref,
) async {
  final service = ref.watch(photoPickerServiceProvider);
  return service.checkPermission();
});

/// Provider for getting a thumbnail for a specific asset.
final assetThumbnailProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  assetId,
) async {
  final service = ref.watch(photoPickerServiceProvider);
  return service.getThumbnail(assetId);
});

/// Provider for getting full-resolution image bytes for a specific asset.
///
/// Use this for displaying photos in the full-screen viewer.
/// Results are cached by Riverpod to avoid repeated fetches during swipe navigation.
final assetFullResolutionProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  assetId,
) async {
  final service = ref.watch(photoPickerServiceProvider);
  return service.getFileBytes(assetId);
});

/// State for the photo picker selection.
class PhotoPickerState {
  /// Currently selected asset IDs.
  final Set<String> selectedIds;

  /// Whether permission has been requested.
  final bool permissionRequested;

  /// Current permission status.
  final PhotoPermissionStatus? permissionStatus;

  /// Whether assets are currently loading.
  final bool isLoading;

  /// Error message if loading failed.
  final String? error;

  const PhotoPickerState({
    this.selectedIds = const {},
    this.permissionRequested = false,
    this.permissionStatus,
    this.isLoading = false,
    this.error,
  });

  PhotoPickerState copyWith({
    Set<String>? selectedIds,
    bool? permissionRequested,
    PhotoPermissionStatus? permissionStatus,
    bool? isLoading,
    String? error,
  }) {
    return PhotoPickerState(
      selectedIds: selectedIds ?? this.selectedIds,
      permissionRequested: permissionRequested ?? this.permissionRequested,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Whether permission is granted (authorized or limited).
  bool get hasPermission =>
      permissionStatus == PhotoPermissionStatus.authorized ||
      permissionStatus == PhotoPermissionStatus.limited;

  /// Number of selected assets.
  int get selectionCount => selectedIds.length;
}

/// Notifier for managing photo picker selection state.
class PhotoPickerNotifier extends StateNotifier<PhotoPickerState> {
  final PhotoPickerService _service;

  PhotoPickerNotifier(this._service) : super(const PhotoPickerState());

  /// Request photo library permission.
  Future<void> requestPermission() async {
    state = state.copyWith(isLoading: true);

    try {
      final status = await _service.requestPermission();
      state = state.copyWith(
        permissionRequested: true,
        permissionStatus: status,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to request permission: $e',
      );
    }
  }

  /// Check current permission status without prompting.
  Future<void> checkPermission() async {
    try {
      final status = await _service.checkPermission();
      state = state.copyWith(permissionStatus: status);
    } catch (e) {
      state = state.copyWith(error: 'Failed to check permission: $e');
    }
  }

  /// Toggle selection of an asset.
  void toggleSelection(String assetId) {
    final newSelection = Set<String>.from(state.selectedIds);
    if (newSelection.contains(assetId)) {
      newSelection.remove(assetId);
    } else {
      newSelection.add(assetId);
    }
    state = state.copyWith(selectedIds: newSelection);
  }

  /// Select all provided assets.
  void selectAll(List<String> assetIds) {
    state = state.copyWith(selectedIds: assetIds.toSet());
  }

  /// Clear all selections.
  void clearSelection() {
    state = state.copyWith(selectedIds: {});
  }

  /// Check if an asset is selected.
  bool isSelected(String assetId) => state.selectedIds.contains(assetId);

  /// Clear any error state.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// StateNotifierProvider for photo picker state management.
final photoPickerNotifierProvider =
    StateNotifierProvider<PhotoPickerNotifier, PhotoPickerState>((ref) {
      final service = ref.watch(photoPickerServiceProvider);
      return PhotoPickerNotifier(service);
    });

/// Provider for the enrichment service (singleton).
final enrichmentServiceProvider = Provider<EnrichmentService>((ref) {
  return const EnrichmentService();
});

/// Provider for the media import service.
final mediaImportServiceProvider = Provider<MediaImportService>((ref) {
  return MediaImportService(
    mediaRepository: MediaRepository(),
    enrichmentService: ref.watch(enrichmentServiceProvider),
  );
});
