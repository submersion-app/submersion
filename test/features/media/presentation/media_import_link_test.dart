import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/presentation/pages/media_import_link_page.dart';
import 'package:submersion/features/media/presentation/providers/media_inbox_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _RecordingMediaRepo implements MediaRepository {
  final List<(List<String>, String)> reassigns = [];

  @override
  Future<void> reassignMediaToDive(
    List<String> mediaIds,
    String newDiveId,
  ) async {
    reassigns.add((mediaIds, newDiveId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaItem item(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  originalFilename: '$id.jpg',
  retainInLibrary: true,
  takenAt: DateTime(2026, 6, 12, 10),
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

InboxSuggestion confident(String diveId, int number) => InboxSuggestion(
  match: TimestampMatch(kind: TimestampMatchKind.confident, diveId: diveId),
  diveNumber: number,
);

const none = InboxSuggestion(
  match: TimestampMatch(kind: TimestampMatchKind.none),
);

void main() {
  late _RecordingMediaRepo mediaRepo;

  Widget host(List<String> mediaIds, Map<String, InboxSuggestion> suggestions) {
    mediaRepo = _RecordingMediaRepo();
    return ProviderScope(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(mediaRepo),
        for (final id in mediaIds)
          mediaByIdProvider(id).overrideWith((ref) async => item(id)),
        for (final MapEntry(:key, :value) in suggestions.entries)
          inboxSuggestionProvider(key).overrideWith((ref) async => value),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaImportLinkPage(mediaIds: mediaIds),
      ),
    );
  }

  testWidgets('confident suggestions are pre-checked and link on confirm '
      'grouped by dive', (tester) async {
    await tester.pumpWidget(
      host(
        ['m1', 'm2', 'm3'],
        {'m1': confident('d7', 7), 'm2': confident('d7', 7), 'm3': none},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stays in Unlinked'), findsOneWidget);
    expect(find.text('Link 2 items'), findsOneWidget);

    await tester.tap(find.text('Link 2 items'));
    await tester.pumpAndSettle();

    expect(mediaRepo.reassigns, hasLength(1));
    expect(mediaRepo.reassigns.single.$1.toSet(), {'m1', 'm2'});
    expect(mediaRepo.reassigns.single.$2, 'd7');
  });

  testWidgets('unchecking a row excludes it from the confirm', (tester) async {
    await tester.pumpWidget(
      host(['m1', 'm2'], {'m1': confident('d7', 7), 'm2': confident('d8', 8)}),
    );
    await tester.pumpAndSettle();

    // Uncheck m1 by tapping its row.
    await tester.tap(find.text('m1.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('Link 1 items'), findsOneWidget);

    await tester.tap(find.text('Link 1 items'));
    await tester.pumpAndSettle();
    expect(mediaRepo.reassigns.single.$1, ['m2']);
    expect(mediaRepo.reassigns.single.$2, 'd8');
  });
}
