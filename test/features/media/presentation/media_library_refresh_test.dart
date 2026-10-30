import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_library_sort.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';

final _when = DateTime(2026, 6, 1);

MediaLibraryEntry _entry(String id, {String? caption}) => MediaLibraryEntry(
  item: MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: id,
    caption: caption,
    takenAt: _when,
    createdAt: _when,
    updatedAt: _when,
  ),
);

List<MediaLibraryEntry> _rows(String prefix, int count) => [
  for (var i = 0; i < count; i++) _entry('$prefix$i'),
];

MediaLibraryCursor _cursor(String id) => MediaLibraryCursor(sortKey: 1, id: id);

/// A `getPage` call that stays open until the test answers it, so a test
/// decides the order in which reads finish.
class _Read {
  _Read(this.after, this.limit);

  final MediaLibraryCursor? after;
  final int limit;
  final _reply = Completer<MediaLibraryPageResult>();

  void answer(List<MediaLibraryEntry> entries, {MediaLibraryCursor? next}) =>
      _reply.complete(
        MediaLibraryPageResult(entries: entries, nextCursor: next),
      );

  void fail(Object error) => _reply.completeError(error);
}

class _GatedLibraryRepo implements MediaLibraryRepository {
  final reads = <_Read>[];
  final changes = StreamController<void>.broadcast();

  @override
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    SortState<MediaSortField> sort = kDefaultMediaSort,
    MediaLibraryCursor? after,
    int limit = MediaLibraryRepository.pageSize,
  }) {
    final read = _Read(after, limit);
    reads.add(read);
    return read._reply.future;
  }

  @override
  Stream<void> watchLibraryChanges() => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier() : super('d1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const pageSize = MediaLibraryRepository.pageSize;

  late _GatedLibraryRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _GatedLibraryRepo();
    container = ProviderContainer(
      overrides: [
        mediaLibraryRepositoryProvider.overrideWithValue(repo),
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
      ],
    );
    addTearDown(repo.changes.close);
    addTearDown(container.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  MediaLibraryState state() => container.read(mediaLibraryNotifierProvider);

  List<String> ids() => [for (final e in state().entries) e.item.id];

  MediaLibraryNotifier notifier() =>
      container.read(mediaLibraryNotifierProvider.notifier);

  /// Answers the constructor's read with a full page, more to come.
  Future<void> loadPageOne() async {
    notifier();
    await settle();
    repo.reads.single.answer(_rows('a', pageSize), next: _cursor('a59'));
    await settle();
  }

  /// [loadPageOne], then a second full page, more to come.
  Future<void> loadTwoPages() async {
    await loadPageOne();
    notifier().loadMore();
    await settle();
    repo.reads.last.answer(_rows('b', pageSize), next: _cursor('b59'));
    await settle();
  }

  /// A write landed: the debounced change stream ticks.
  Future<void> tick() async {
    repo.changes.add(null);
    await settle();
  }

  test('a first load shows as loading from the first build', () {
    // The view's first build reads this synchronously, and its spinner is
    // gated on isLoading. Without it the empty-library text flashes up.
    expect(state().isLoading, isTrue);
  });

  group('a background change', () {
    test('keeps every loaded page', () async {
      await loadTwoPages();

      await tick();

      final read = repo.reads.last;
      expect(read.after, isNull, reason: 'the window is read from the top');
      expect(read.limit, pageSize * 2, reason: 'all of it, not page one');

      final rows = [..._rows('a', pageSize), ..._rows('b', pageSize)];
      read.answer(rows, next: _cursor('b59'));
      await settle();

      expect(state().entries, hasLength(pageSize * 2));
      expect(state().nextCursor?.id, 'b59');
    });

    test('reads a page past a fully loaded library', () async {
      notifier();
      await settle();
      repo.reads.single.answer(_rows('a', 3));
      await settle();

      await tick();

      // A read of exactly 3 would lose the last row to any new one.
      expect(repo.reads.last.limit, 3 + pageSize);
    });

    test('drops a row that was deleted or stopped matching', () async {
      await loadTwoPages();

      await tick();
      final rows = _rows('a', pageSize).where((e) => e.item.id != 'a7');
      repo.reads.last.answer([
        ...rows,
        ..._rows('b', pageSize),
        _entry('c0'),
      ], next: _cursor('c0'));
      await settle();

      expect(ids(), isNot(contains('a7')));
      expect(ids().last, 'c0');
      expect(state().nextCursor?.id, 'c0');
    });

    test('picks up an edited row', () async {
      await loadPageOne();

      await tick();
      repo.reads.last.answer([
        _entry('a0', caption: 'Manta'),
        ..._rows('a', pageSize).skip(1),
      ], next: _cursor('a59'));
      await settle();

      expect(state().entries.first.item.caption, 'Manta');
    });

    test('leaves the state alone when nothing on screen changed', () async {
      await loadTwoPages();
      final before = state();

      await tick();
      repo.reads.last.answer([
        ..._rows('a', pageSize),
        ..._rows('b', pageSize),
      ], next: _cursor('b59'));
      await settle();

      // A write to the state rebuilds the view and regroups every loaded row.
      expect(identical(state(), before), isTrue);
    });

    test('notices the end of the library arriving', () async {
      await loadPageOne();

      await tick();
      repo.reads.last.answer(_rows('a', pageSize));
      await settle();

      expect(state().hasMore, isFalse);
    });

    test('a failed read keeps the loaded rows and their cursor', () async {
      await loadTwoPages();

      await tick();
      repo.reads.last.fail(StateError('database is busy'));
      await settle();

      expect(state().entries, hasLength(pageSize * 2));
      expect(state().nextCursor?.id, 'b59');
      expect(state().error, isA<StateError>());
    });

    test('a later read clears the error of a failed one', () async {
      await loadPageOne();

      await tick();
      repo.reads.last.fail(StateError('database is busy'));
      await settle();

      await tick();
      repo.reads.last.answer(_rows('a', pageSize), next: _cursor('a59'));
      await settle();

      expect(state().error, isNull);
    });
  });

  group('a first load', () {
    test('that fails stops the spinner and records why', () async {
      notifier();
      await settle();

      repo.reads.single.fail(StateError('database is busy'));
      await settle();

      expect(state().isLoading, isFalse);
      expect(state().error, isA<StateError>());
    });

    test('is retried by the next change after failing', () async {
      notifier();
      await settle();
      repo.reads.single.fail(StateError('database is busy'));
      await settle();

      await tick();
      repo.reads.last.answer(_rows('a', 2));
      await settle();

      expect(state().entries, hasLength(2));
      expect(state().error, isNull);
    });
  });

  group('overlapping refreshes', () {
    test('a burst during a read runs one more read, not one each', () async {
      await loadPageOne();
      repo.reads.clear();

      await tick();
      await tick();
      await tick();
      expect(repo.reads, hasLength(1), reason: 'never two at once');

      repo.reads.first.answer(_rows('a', pageSize), next: _cursor('a59'));
      await settle();
      expect(repo.reads, hasLength(2));

      repo.reads.last.answer(_rows('a', pageSize), next: _cursor('a59'));
      await settle();
      expect(repo.reads, hasLength(2), reason: 'the burst is spent');
    });

    test('a change during the trailing read queues another', () async {
      await loadPageOne();
      repo.reads.clear();

      await tick();
      await tick();
      repo.reads.first.answer(_rows('a', pageSize), next: _cursor('a59'));
      await settle();

      // The trailing read started before this write, so it may have missed it.
      await tick();
      repo.reads.last.answer(_rows('a', pageSize), next: _cursor('a59'));
      await settle();

      expect(repo.reads, hasLength(3));
    });

    test('the read that started last wins', () async {
      await loadPageOne();
      repo.reads.clear();

      await tick();
      await tick();

      // Completing the older read cannot overwrite a newer one: the newer one
      // has not started yet, so it reads everything the older one missed.
      repo.reads.first.answer([_entry('old')]);
      await settle();
      repo.reads.last.answer([_entry('new')]);
      await settle();

      expect(ids(), ['new']);
    });

    test('a read the notifier outlived writes nothing', () async {
      await loadPageOne();

      await tick();
      await tick();
      final inFlight = repo.reads.last;
      container.dispose();

      inFlight.answer([_entry('late')]);
      await settle();

      // The queued read saw the notifier gone and never ran.
      expect(repo.reads.last, same(inFlight));
    });
  });

  group('a refresh racing loadMore', () {
    test('a change during loadMore waits, then covers the new page', () async {
      await loadPageOne();

      notifier().loadMore();
      await settle();
      final pageTwo = repo.reads.last;

      await tick();
      expect(repo.reads.last, same(pageTwo), reason: 'no overlap');

      pageTwo.answer(_rows('b', pageSize), next: _cursor('b59'));
      await settle();

      expect(state().entries, hasLength(pageSize * 2));
      expect(repo.reads.last, isNot(same(pageTwo)));
      expect(repo.reads.last.limit, pageSize * 2);
    });

    test('loadMore during a refresh pages on from its cursor', () async {
      await loadPageOne();

      await tick();
      final refresh = repo.reads.last;

      notifier().loadMore();
      await settle();
      expect(repo.reads.last, same(refresh), reason: 'no overlap');
      expect(state().isLoadingMore, isTrue);

      // A photo landed at the top, so the cursor moved under the queued load.
      refresh.answer([
        _entry('new'),
        ..._rows('a', pageSize - 1),
      ], next: _cursor('a58'));
      await settle();

      expect(state().isLoadingMore, isTrue, reason: 'still on its way');
      expect(repo.reads.last.after?.id, 'a58');

      repo.reads.last.answer(_rows('b', pageSize));
      await settle();

      expect(ids().first, 'new');
      expect(state().entries, hasLength(pageSize * 2));
      expect(state().isLoadingMore, isFalse);
    });

    test('loadMore stands down when a refresh reached the end', () async {
      await loadPageOne();

      await tick();
      final refresh = repo.reads.last;

      notifier().loadMore();
      await settle();

      refresh.answer(_rows('a', 3));
      await settle();

      expect(repo.reads.last, same(refresh), reason: 'nothing left to read');
      expect(state().isLoadingMore, isFalse);
    });

    test('a burst of scroll notifications loads one page', () async {
      await loadPageOne();
      repo.reads.clear();

      notifier().loadMore();
      notifier().loadMore();
      notifier().loadMore();
      await settle();

      expect(repo.reads, hasLength(1));
    });

    test('a row a re-sort moved past the cursor is not shown twice', () async {
      await loadPageOne();

      // Hashing a row writes its size, which moves it under the size sort.
      notifier().loadMore();
      await settle();
      repo.reads.last.answer([_entry('a3'), _entry('b0')]);
      await settle();

      expect(ids().where((id) => id == 'a3'), hasLength(1));
      expect(ids().last, 'b0');
    });

    test('a failed page keeps the rows and its cursor', () async {
      await loadPageOne();

      notifier().loadMore();
      await settle();
      repo.reads.last.fail(StateError('database is busy'));
      await settle();

      expect(state().entries, hasLength(pageSize));
      expect(state().nextCursor?.id, 'a59');
      expect(state().isLoadingMore, isFalse);
      expect(state().error, isA<StateError>());
    });

    test('a failed read does not wedge the queue', () async {
      await loadPageOne();

      await tick();
      repo.reads.last.fail(StateError('database is busy'));
      await settle();

      notifier().loadMore();
      await settle();
      repo.reads.last.answer(_rows('b', 2));
      await settle();

      expect(state().entries, hasLength(pageSize + 2));
    });
  });
}
