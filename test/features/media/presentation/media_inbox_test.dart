import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_unlinked_inbox_view.dart';
import 'package:submersion/features/media/presentation/providers/media_inbox_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class SeededInboxNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  SeededInboxNotifier(super.state);

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

class _RecordingMediaRepo implements MediaRepository {
  (List<String>, String)? reassigned;
  final List<String> retained = [];

  @override
  Future<void> reassignMediaToDive(
    List<String> mediaIds,
    String newDiveId,
  ) async {
    reassigned = (mediaIds, newDiveId);
  }

  @override
  Future<void> markRetainedInLibrary(List<String> mediaIds) async {
    retained.addAll(mediaIds);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dive diveFixture(
  String id, {
  int? number,
  required DateTime entry,
  required DateTime exit,
}) => Dive(
  id: id,
  diveNumber: number,
  dateTime: entry,
  entryTime: entry,
  exitTime: exit,
);

MediaItem mediaItem(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  filePath: '/tmp/$id',
  localPath: '/tmp/$id',
  originalFilename: '$id.jpg',
  takenAt: DateTime.utc(2026, 6, 12, 10, 30),
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

void main() {
  group('computeInboxSuggestion', () {
    test('a takenAt inside exactly one dive window is confident', () async {
      final dive = diveFixture(
        'd1',
        number: 7,
        entry: DateTime(2026, 6, 12, 10),
        exit: DateTime(2026, 6, 12, 11),
      );
      final s = await computeInboxSuggestion(
        takenAt: DateTime.utc(2026, 6, 12, 10, 30),
        candidateDives: [dive],
      );
      expect(s.match.kind, TimestampMatchKind.confident);
      expect(s.match.diveId, 'd1');
      expect(s.diveNumber, 7);
    });

    test(
      'overlapping extended windows with no core hit are ambiguous',
      () async {
        // Photo in the shared buffer zone between two dives: after dive A's
        // exit (inside its 60min post-buffer) and before dive B's entry
        // (inside its 30min pre-buffer) - no core hit for either.
        final a = diveFixture(
          'a',
          entry: DateTime(2026, 6, 12, 9),
          exit: DateTime(2026, 6, 12, 10),
        );
        final b = diveFixture(
          'b',
          entry: DateTime(2026, 6, 12, 10, 45),
          exit: DateTime(2026, 6, 12, 11, 45),
        );
        final s = await computeInboxSuggestion(
          takenAt: DateTime.utc(2026, 6, 12, 10, 20),
          candidateDives: [a, b],
        );
        expect(s.match.kind, TimestampMatchKind.ambiguous);
        expect(s.match.candidateDiveIds, containsAll(['a', 'b']));
      },
    );

    test('no dive in range is none', () async {
      final s = await computeInboxSuggestion(
        takenAt: DateTime.utc(2026, 6, 12, 10, 30),
        candidateDives: const [],
      );
      expect(s.match.kind, TimestampMatchKind.none);
    });
  });

  group('inbox view', () {
    late _RecordingMediaRepo mediaRepo;

    Widget host({
      required List<MediaLibraryEntry> entries,
      required Map<String, InboxSuggestion> suggestions,
    }) {
      mediaRepo = _RecordingMediaRepo();
      return ProviderScope(
        overrides: [
          unlinkedInboxProvider.overrideWith(
            (ref) => SeededInboxNotifier(MediaLibraryState(entries: entries)),
          ),
          mediaRepositoryProvider.overrideWithValue(mediaRepo),
          for (final MapEntry(:key, :value) in suggestions.entries)
            inboxSuggestionProvider(key).overrideWith((ref) async => value),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.localFile: _UnavailableResolver(),
            }),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MediaUnlinkedInboxView()),
        ),
      );
    }

    testWidgets('confident suggestion renders a one-tap link chip that '
        'reassigns', (tester) async {
      await tester.pumpWidget(
        host(
          entries: [MediaLibraryEntry(item: mediaItem('m1'))],
          suggestions: {
            'm1': const InboxSuggestion(
              match: TimestampMatch(
                kind: TimestampMatchKind.confident,
                diveId: 'd7',
              ),
              diveNumber: 7,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link to #7'));
      await tester.pumpAndSettle();
      expect(mediaRepo.reassigned?.$1, ['m1']);
      expect(mediaRepo.reassigned?.$2, 'd7');
    });

    testWidgets('a confident match on an unnumbered dive falls back to the '
        'generic label instead of "#0"', (tester) async {
      await tester.pumpWidget(
        host(
          entries: [MediaLibraryEntry(item: mediaItem('m1'))],
          suggestions: {
            'm1': const InboxSuggestion(
              match: TimestampMatch(
                kind: TimestampMatchKind.confident,
                diveId: 'd7',
              ),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Link to #0'), findsNothing);
      // The chip carries the generic label; the menu item shares the string,
      // so the chip is identified by its avatar icon.
      final chip = tester.widget<ActionChip>(find.byType(ActionChip));
      expect(((chip.label as Text).data), 'Link to dive');

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();
      expect(mediaRepo.reassigned?.$1, ['m1']);
      expect(mediaRepo.reassigned?.$2, 'd7');
    });

    testWidgets('Keep calls markRetainedInLibrary', (tester) async {
      await tester.pumpWidget(
        host(
          entries: [MediaLibraryEntry(item: mediaItem('m1'))],
          suggestions: {
            'm1': const InboxSuggestion(
              match: TimestampMatch(kind: TimestampMatchKind.none),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(mediaRepo.retained, ['m1']);
    });

    testWidgets('empty inbox shows the localized empty state', (tester) async {
      await tester.pumpWidget(host(entries: const [], suggestions: const {}));
      await tester.pumpAndSettle();
      expect(find.text('No unlinked media'), findsOneWidget);
    });
  });
}
