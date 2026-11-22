import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/outing_cover_repository.dart';

/// The reads behind Home's Recent outings covers.
final outingCoverRepositoryProvider = Provider<OutingCoverRepository>(
  (ref) => OutingCoverRepository(),
);
