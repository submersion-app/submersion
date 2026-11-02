import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';

/// Repository provider for annotations (#4109).
final annotationRepositoryProvider = Provider<AnnotationRepository>(
  (ref) => AnnotationRepository(),
);
