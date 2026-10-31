import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

const int kChangeLogPageSize = 50;

final changeLogRepositoryProvider = Provider<ChangeLogRepository>(
  (ref) => ChangeLogRepository(),
);

/// The pages of the feed loaded so far.
class ChangeLogFeedState {
  const ChangeLogFeedState({
    this.operations = const [],
    this.previews = const {},
    this.references = const {},
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<ChangeLogOperation> operations;
  final Map<String, ChangeLogPreview> previews;

  /// The records the previews' values point at, for the formatter.
  final Map<String, List<ConflictReference>> references;
  final bool hasMore;
  final bool isLoadingMore;

  ChangeLogFeedState copyWith({
    List<ChangeLogOperation>? operations,
    Map<String, ChangeLogPreview>? previews,
    Map<String, List<ConflictReference>>? references,
    bool? hasMore,
    bool? isLoadingMore,
  }) => ChangeLogFeedState(
    operations: operations ?? this.operations,
    previews: previews ?? this.previews,
    references: references ?? this.references,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// The feed for one filter and the active diver. Opening it settles what is
/// waiting first, so the newest change is there.
class ChangeLogFeedNotifier extends AsyncNotifier<ChangeLogFeedState> {
  ChangeLogFeedNotifier(this.filter);

  final ChangeLogFilter filter;

  String? _diverId;

  @override
  Future<ChangeLogFeedState> build() async {
    final repository = ref.watch(changeLogRepositoryProvider);
    ref.invalidateSelfWhen(repository.watchChanges());
    final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
    _diverId = diverId;
    if (diverId == null) return const ChangeLogFeedState();
    await repository.settleAll();
    return _nextPage(repository, diverId, const ChangeLogFeedState());
  }

  Future<ChangeLogFeedState> _nextPage(
    ChangeLogRepository repository,
    String diverId,
    ChangeLogFeedState current,
  ) async {
    final page = await repository.getFeed(
      diverId: diverId,
      filter: filter,
      after: current.operations.isEmpty
          ? null
          : ChangeLogPageCursor.after(current.operations.last),
      limit: kChangeLogPageSize,
    );
    final previews = await repository.getPreviewFields([
      for (final operation in page)
        if (!operation.isBulk) operation.id,
    ]);
    final references = await repository.resolveReferences([
      for (final preview in previews.values) ...preview.fields,
    ]);
    return ChangeLogFeedState(
      operations: [...current.operations, ...page],
      previews: {...current.previews, ...previews},
      references: {...current.references, ...references},
      hasMore: page.length == kChangeLogPageSize,
    );
  }

  /// Loads the next page, once, however often the list asks.
  Future<void> loadMore() async {
    final current = state.value;
    final diverId = _diverId;
    if (current == null ||
        diverId == null ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = AsyncData(
      await _nextPage(ref.read(changeLogRepositoryProvider), diverId, current),
    );
  }
}

final changeLogFeedProvider = AsyncNotifierProvider.autoDispose
    .family<ChangeLogFeedNotifier, ChangeLogFeedState, ChangeLogFilter>(
      ChangeLogFeedNotifier.new,
    );

/// One entry, for its detail page.
final changeLogOperationProvider = FutureProvider.autoDispose
    .family<ChangeLogOperation?, String>((ref, id) {
      final repository = ref.watch(changeLogRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getOperation(id);
    });

/// An entry's records and fields.
final changeLogEventsProvider = FutureProvider.autoDispose
    .family<List<ChangeLogEvent>, String>((ref, id) {
      final repository = ref.watch(changeLogRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getEvents(id);
    });
