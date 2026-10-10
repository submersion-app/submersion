import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';

/// Records the diver each getMissingRows call was scoped to. Any other
/// repository call fails the test: the repair loaders must not go back to
/// the gallery's getPage, which leaves documents out (#3052).
class _MissingRowsRepo implements MediaLibraryRepository {
  final diverIds = <String?>[];

  @override
  Future<List<MediaItem>> getMissingRows({required String? diverId}) async {
    diverIds.add(diverId);
    return [
      MediaItem(
        id: 'doc-missing',
        mediaType: MediaType.document,
        sourceType: MediaSourceType.localFile,
        originalFilename: 'invoice.pdf',
        takenAt: DateTime(2026, 6, 12),
        isOrphaned: true,
        createdAt: DateTime(2026, 6, 12),
        updatedAt: DateTime(2026, 6, 12),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier() : super('d1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _watcherLoad = FutureProvider<List<MediaItem>>(loadAllMissingRows);

void main() {
  late _MissingRowsRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _MissingRowsRepo();
    container = ProviderContainer(
      overrides: [
        mediaLibraryRepositoryProvider.overrideWithValue(repo),
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('the repair wizard loads missing rows, documents included', () async {
    final sub = container.listen(repairWizardProvider.notifier, (_, _) {});
    addTearDown(sub.close);

    final rows = await sub.read().loadMissingRows();

    expect(rows.map((r) => r.id), ['doc-missing']);
    expect(repo.diverIds, ['d1']);
  });

  test('the folder watcher loads missing rows, documents included', () async {
    final rows = await container.read(_watcherLoad.future);

    expect(rows.map((r) => r.id), ['doc-missing']);
    expect(repo.diverIds, ['d1']);
  });
}
