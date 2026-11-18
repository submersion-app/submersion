import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Where the profile's annotation actions write (issue #4527, plan 6): into
/// a sitting on the dive, held until Save.
abstract interface class AnnotationEdits {
  Future<void> add({
    required int seconds,
    double? depth,
    required String words,
  });

  Future<void> move(String id, {required int seconds, double? depth});

  Future<void> remove(String id);

  /// The latest second an annotation may fall on, or [fallback] when these
  /// edits have no better answer than the chart's.
  int maxSeconds(int fallback);
}

/// Into a sitting on the dive, held until Save.
class SittingAnnotationEdits implements AnnotationEdits {
  const SittingAnnotationEdits(this.session);

  final EditSession<Dive> session;

  @override
  Future<void> add({
    required int seconds,
    double? depth,
    required String words,
  }) async {
    placeAnnotation(session, seconds: seconds, depth: depth, words: words);
  }

  @override
  Future<void> move(String id, {required int seconds, double? depth}) async {
    moveSittingAnnotation(session, id, seconds: seconds, depth: depth);
  }

  @override
  Future<void> remove(String id) async {
    removeSittingAnnotation(session, id);
  }

  /// The sitting's own limit: its runtime, bottom time or exit, which a
  /// card other than the Profile card may have changed.
  @override
  int maxSeconds(int fallback) => annotationTimeLimits(session).max;
}
