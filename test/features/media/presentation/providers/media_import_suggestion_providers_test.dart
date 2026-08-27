import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/presentation/providers/media_import_suggestion_providers.dart';

class _FakeDiveRepo implements DiveRepository {
  _FakeDiveRepo(this.dives);
  final List<Dive> dives;
  (DateTime, DateTime)? lastRange;

  @override
  Future<List<Dive>> getDivesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
  }) async {
    lastRange = (start, end);
    return dives;
  }

  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier() : super('diver-1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dive _dive(String id, DateTime start, {int? number}) => Dive(
  id: id,
  diveNumber: number,
  dateTime: start,
  entryTime: start,
  exitTime: start.add(const Duration(minutes: 50)),
);

void main() {
  final takenAt = DateTime.utc(2026, 6, 12, 9, 20);

  ProviderContainer build(List<Dive> dives, _FakeDiveRepo repo) {
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repo),
        // The provider reads the active diver, whose real notifier reaches
        // into SharedPreferences.
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'a timestamp inside one dive window is confident with its number',
    () async {
      final repo = _FakeDiveRepo([
        _dive('d1', DateTime.utc(2026, 6, 12, 9), number: 7),
      ]);
      final container = build(repo.dives, repo);

      final suggestion = await container.read(
        importSuggestionProvider(takenAt).future,
      );

      expect(suggestion.match.kind, TimestampMatchKind.confident);
      expect(suggestion.match.diveId, 'd1');
      expect(suggestion.diveNumber, 7);
    },
  );

  test('no dive in the window is none, with no number', () async {
    final repo = _FakeDiveRepo(const []);
    final container = build(const [], repo);

    final suggestion = await container.read(
      importSuggestionProvider(takenAt).future,
    );

    expect(suggestion.match.kind, TimestampMatchKind.none);
    expect(suggestion.diveNumber, isNull);
  });

  test('candidates load from a two-day window around the timestamp', () async {
    final repo = _FakeDiveRepo(const []);
    final container = build(const [], repo);

    await container.read(importSuggestionProvider(takenAt).future);

    expect(repo.lastRange, isNotNull);
    expect(repo.lastRange!.$1, takenAt.subtract(const Duration(days: 2)));
    expect(repo.lastRange!.$2, takenAt.add(const Duration(days: 2)));
  });
}
