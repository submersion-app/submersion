import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/value_objects/learned_aspect.dart';

/// The learned thumbnail shapes (issues #4738, #4739) held in memory, for
/// every test that lays media out in justified rows or drives the
/// learned-shapes notifier.
///
/// Implements rather than extends the repository, so a method added to it
/// fails to compile here instead of reaching the real local cache.
class FakeMediaAspectCache implements MediaAspectCacheRepository {
  /// Serves [learned], or the shapes [load] completes with when given (a
  /// test holding the first layout back), or fails every read when [fails]
  /// is set, the way an uninitialized local cache does.
  FakeMediaAspectCache({
    this.learned = const {},
    this.fails = false,
    Future<Map<String, LearnedAspect>>? load,
  }) : _load = load;

  final Map<String, LearnedAspect> learned;
  final bool fails;
  final Future<Map<String, LearnedAspect>>? _load;

  /// How many times the shapes were read.
  int loads = 0;

  /// Every batch written, in order.
  final List<Map<String, LearnedAspect>> writes = [];

  @override
  Future<Map<String, LearnedAspect>> loadAll() async {
    loads++;
    if (fails) throw StateError('Local cache database not initialized.');
    return _load ?? learned;
  }

  @override
  Future<void> putAll(Map<String, LearnedAspect> entries) async {
    writes.add(Map.of(entries));
  }
}
