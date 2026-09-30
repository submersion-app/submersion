import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/explore/data/explore_repository.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>(
  (ref) => ExploreRepository(),
);
