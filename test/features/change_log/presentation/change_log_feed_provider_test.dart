import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

ChangeLogOperation _operation(String id, int lastEventId) => ChangeLogOperation(
  id: id,
  source: ChangeLogSource.manual,
  rootTable: 'dives',
  rootId: id,
  startedAt: DateTime(2026),
  endedAt: DateTime(2026),
  lastEventId: lastEventId,
);

/// Serves [firstPage], and holds the page after it until [release] completes.
class _HeldPages extends ChangeLogRepository {
  _HeldPages(this.firstPage);

  List<ChangeLogOperation> firstPage;
  final release = Completer<void>();
  final changes = StreamController<void>.broadcast();

  @override
  Stream<void> watchChanges() => changes.stream;

  @override
  Future<void> settleAll() async {}

  @override
  Future<List<ChangeLogOperation>> getFeed({
    required String diverId,
    required ChangeLogFilter filter,
    ChangeLogPageCursor? after,
    int limit = 50,
  }) async {
    if (after == null) return firstPage;
    await release.future;
    return [_operation('older', 0)];
  }

  @override
  Future<Map<String, ChangeLogPreview>> getPreviewFields(
    List<String> operationIds, {
    int perOperation = 2,
  }) async => const {};

  @override
  Future<Map<String, List<ConflictReference>>> resolveReferences(
    Iterable<ChangeLogFieldChange> fields,
  ) async => const {};

  @override
  Future<Map<String, int>> getRecordCounts(List<String> operationIds) async =>
      const {};
}

void main() {
  test('a page that lands after a rebuild does not undo the rebuild', () async {
    const filter = ChangeLogFilter();
    final repository = _HeldPages([
      for (var i = 0; i < kChangeLogPageSize; i++) _operation('op$i', 100 - i),
    ]);
    addTearDown(repository.changes.close);
    final container = ProviderContainer(
      overrides: [
        changeLogRepositoryProvider.overrideWithValue(repository),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
    );
    addTearDown(container.dispose);
    final provider = changeLogFeedNotifierProvider(filter);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    final loading = container.read(provider.notifier).loadMore();
    await pumpEventQueue();

    repository.firstPage = [_operation('newest', 200), ...repository.firstPage];
    repository.changes.add(null);
    await pumpEventQueue();
    await container.read(provider.future);

    repository.release.complete();
    await loading;
    await pumpEventQueue();

    final state = container.read(provider).value!;
    expect(state.operations.first.id, 'newest');
  });
}
