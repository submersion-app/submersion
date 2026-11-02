import 'package:submersion/core/providers/provider.dart';

/// The chart's placement mode (#4109): on when non-null. [movingId] names
/// the annotation whose spot the next placement replaces; null means a new
/// annotation.
class AnnotationPlacement {
  const AnnotationPlacement({this.movingId});

  final String? movingId;

  bool get isMove => movingId != null;
}

class AnnotationPlacementNotifier extends StateNotifier<AnnotationPlacement?> {
  AnnotationPlacementNotifier() : super(null);

  void startNew() => state = const AnnotationPlacement();

  void startMove(String id) => state = AnnotationPlacement(movingId: id);

  void cancel() => state = null;

  /// Pin button behaviour: off when on, on (for a new one) when off.
  void toggleNew() =>
      state = state == null ? const AnnotationPlacement() : null;
}

/// Placement mode per dive, so the detail page and the fullscreen profile
/// share it and it dies with the page.
final annotationPlacementProvider = StateNotifierProvider.autoDispose
    .family<AnnotationPlacementNotifier, AnnotationPlacement?, String>(
      (ref, diveId) => AnnotationPlacementNotifier(),
    );
