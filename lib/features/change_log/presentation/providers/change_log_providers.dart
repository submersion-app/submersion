import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_preferences.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_maintenance.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const int kChangeLogPageSize = 50;

final changeLogRepositoryProvider = Provider<ChangeLogRepository>(
  (ref) => ChangeLogRepository(),
);

final changeLogRevertServiceProvider = Provider<ChangeLogRevertService>(
  (ref) => ChangeLogRevertService(),
);

final changeLogMaintenanceProvider = Provider<ChangeLogMaintenance>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ChangeLogMaintenance(
    preferences: ChangeLogPreferences(prefs),
    prefs: prefs,
  );
});

/// What the log takes up, for the Storage usage page.
final changeLogStorageBytesProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(changeLogRepositoryProvider).storageBytes(),
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

/// The most records an entry's page lists.
const int kChangeLogDetailLimit = 500;

/// Everything an entry's page shows.
class ChangeLogEntryDetail {
  const ChangeLogEntryDetail({
    required this.operation,
    required this.events,
    required this.references,
    required this.rootNames,
    required this.rootExists,
    this.plan,
  });

  final ChangeLogOperation operation;

  /// Oldest first, up to [kChangeLogDetailLimit].
  final List<ChangeLogEvent> events;
  final Map<String, List<ConflictReference>> references;
  final Map<ChangeLogRoot, ConflictReference> rootNames;

  /// Whether the entry's one record still exists. False for a bulk entry.
  final bool rootExists;

  /// What a revert would do. Worked out for one record's entry, where each
  /// field shows its own state, and left for a bulk action until it is asked
  /// for, since it can touch thousands of records.
  final ChangeLogRevertPlan? plan;
}

final changeLogEntryDetailProvider = FutureProvider.autoDispose
    .family<ChangeLogEntryDetail?, String>((ref, id) async {
      final repository = ref.watch(changeLogRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final operation = await repository.getOperation(id);
      if (operation == null) return null;
      final events = await repository.getEvents(
        id,
        limit: kChangeLogDetailLimit,
      );
      final rootTable = operation.rootTable;
      final rootId = operation.rootId;
      final plan = operation.isBulk || operation.isSummary
          ? null
          : await ref.watch(changeLogRevertServiceProvider).planOperation(id);
      return ChangeLogEntryDetail(
        operation: operation,
        events: events,
        references: await repository.resolveReferences([
          for (final event in events)
            if (event.action == ChangeLogAction.update) ...event.fields,
        ]),
        rootNames: operation.isBulk
            ? await repository.describeRoots({
                for (final event in events) event.root,
              })
            : const {},
        rootExists:
            rootTable != null &&
            rootId != null &&
            await repository.recordExists(rootTable, rootId),
        plan: plan,
      );
    });

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
