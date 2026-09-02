import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/domain/value_objects/import_preview.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/features/media/presentation/providers/media_import_suggestion_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

AssetInfo asset(String id) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2026, 6, 12, 10),
  width: 100,
  height: 100,
  filename: '$id.jpg',
);

void main() {
  Widget host({
    Future<List<AssetInfo>> Function(BuildContext)? launchOverride,
  }) {
    return ProviderScope(
      overrides: [
        importSuggestionProvider(DateTime.utc(2026, 6, 12, 10)).overrideWith(
          (ref) async => const ImportSuggestion(
            match: TimestampMatch(kind: TimestampMatchKind.none),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaImportView(launchOverride: launchOverride)),
      ),
    );
  }

  testWidgets('renders intro and launch button', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Photos are linked to a dive or a dive site as you import them.',
      ),
      findsOneWidget,
    );
    expect(find.text('Import media...'), findsOneWidget);
  });

  testWidgets(
    'a non-empty pick opens the review with one candidate per asset',
    (tester) async {
      await tester.pumpWidget(
        host(launchOverride: (context) async => [asset('a1'), asset('a2')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import media...'));
      await tester.pumpAndSettle();

      final page = tester.widget<MediaImportReviewPage>(
        find.byType(MediaImportReviewPage),
      );
      expect(page.candidates.map((c) => c.key), ['a1', 'a2']);
      expect(page.candidates.first.title, 'a1.jpg');
      expect(page.candidates.first.takenAt, DateTime.utc(2026, 6, 12, 10));
      expect(page.candidates.map((c) => c.preview), [
        const AssetImportPreview('a1'),
        const AssetImportPreview('a2'),
      ]);
    },
  );

  test('the library import window has no effective lower bound', () {
    // A dive-less import must offer the whole gallery. The mobile picker
    // turns this bound into a hard photo_manager createTimeCond, so any
    // "recent enough" sentinel silently hides older assets -- scanned film
    // and slide libraries, which is exactly the media divers back-fill.
    expect(
      MediaImportView.libraryWindowStart.millisecondsSinceEpoch,
      lessThanOrEqualTo(0),
    );
  });

  testWidgets('an empty pick stays on the view', (tester) async {
    await tester.pumpWidget(host(launchOverride: (context) async => []));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import media...'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaImportReviewPage), findsNothing);
  });

  testWidgets('confirming the review imports through the service', (
    tester,
  ) async {
    final service = _RecordingImportService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          importSuggestionProvider(DateTime.utc(2026, 6, 12, 10)).overrideWith(
            (ref) async => const ImportSuggestion(
              match: TimestampMatch(
                kind: TimestampMatchKind.confident,
                diveId: 'd1',
              ),
              diveNumber: 1,
            ),
          ),
          mediaImportServiceProvider.overrideWithValue(service),
          diveRepositoryProvider.overrideWithValue(_OneDiveRepo()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaImportView(
              launchOverride: (context) async => [asset('a1')],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import media...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import 1 items'));
    await tester.pump();
    await tester.pump();

    expect(service.diveCalls.single.$1, 'd1');
    expect(service.diveCalls.single.$2, ['a1']);
    expect(find.text('1 linked, 0 skipped, 0 failed'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}

/// Records dive imports and reports every asset as imported.
class _RecordingImportService implements MediaImportService {
  final List<(String diveId, List<String> assetIds)> diveCalls = [];

  @override
  Future<ImportResult> importPhotosForDive({
    required List<AssetInfo> selectedAssets,
    required Dive dive,
  }) async {
    diveCalls.add((dive.id, [for (final a in selectedAssets) a.id]));
    return ImportResult(
      imported: [
        for (final a in selectedAssets)
          MediaItem(
            id: 'row-${a.id}',
            mediaType: MediaType.photo,
            takenAt: DateTime(2026, 6, 12, 10),
            createdAt: DateTime(2026, 6, 12),
            updatedAt: DateTime(2026, 6, 12),
          ),
      ],
      failures: const {},
      skippedDuplicates: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OneDiveRepo implements DiveRepository {
  @override
  Future<Dive?> getDiveById(String id) async =>
      Dive(id: id, dateTime: DateTime(2026, 6, 12));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
