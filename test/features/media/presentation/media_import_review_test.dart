import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/domain/value_objects/import_preview.dart';
import 'package:submersion/features/media/presentation/providers/media_import_suggestion_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/import_preview_thumbnail.dart';
import 'package:submersion/features/media/presentation/widgets/network_thumbnail.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// `Override` is not exported from flutter_riverpod's public barrel; the
// shared test helper re-types it for widget tests.
import '../../../helpers/mock_providers.dart' show Override;
import 'support/media_widget_harness.dart' show onePixelPng;

final t1 = DateTime.utc(2026, 6, 12, 10);
final t2 = DateTime.utc(2026, 6, 12, 11);
final t3 = DateTime.utc(2026, 6, 13, 10);

ImportSuggestion confident(String diveId, int number) => ImportSuggestion(
  match: TimestampMatch(kind: TimestampMatchKind.confident, diveId: diveId),
  diveNumber: number,
);

const none = ImportSuggestion(
  match: TimestampMatch(kind: TimestampMatchKind.none),
);

const ambiguous = ImportSuggestion(
  match: TimestampMatch(
    kind: TimestampMatchKind.ambiguous,
    candidateDiveIds: ['d1', 'd2'],
  ),
);

void main() {
  Map<String, MediaAttachTarget>? confirmed;

  Widget host(
    List<ImportCandidate> candidates,
    Map<DateTime, ImportSuggestion> suggestions, {
    List<Override> extraOverrides = const [],
  }) {
    confirmed = null;
    return ProviderScope(
      overrides: [
        for (final MapEntry(:key, :value) in suggestions.entries)
          importSuggestionProvider(key).overrideWith((ref) async => value),
        ...extraOverrides,
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaImportReviewPage(
          candidates: candidates,
          onConfirm: (targets) async {
            confirmed = targets;
            return ImportReviewResult(
              linked: targets.length,
              skipped: candidates.length - targets.length,
            );
          },
        ),
      ),
    );
  }

  ImportCandidate candidate(
    String key,
    DateTime? takenAt, {
    String? error,
    ImportPreview? preview,
  }) => ImportCandidate(
    key: key,
    title: '$key.jpg',
    takenAt: takenAt,
    error: error,
    preview: preview,
  );

  testWidgets('confident matches are pre-checked; the rest are not', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t1), candidate('b', t2), candidate('c', t3)],
        {t1: confident('d7', 7), t2: ambiguous, t3: none},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Link to #7'), findsOneWidget);
    expect(find.text('Several dives match'), findsOneWidget);
    expect(find.text('No matching dive'), findsOneWidget);
    expect(find.text('Import 1 items'), findsOneWidget);
  });

  testWidgets('confirm hands only resolved candidates to onConfirm', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t1), candidate('b', t3)],
        {t1: confident('d7', 7), t3: none},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 1 items'));
    // Plain pumps: settling would run the snackbar's auto-dismiss to the
    // end before the assertion ever saw it.
    await tester.pump();
    await tester.pump();

    expect(confirmed, {'a': const DiveAttachTarget('d7')});
    expect(find.text('1 linked, 1 skipped, 0 failed'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('unchecking a confident row skips it', (tester) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t1), candidate('b', t2)],
        {t1: confident('d7', 7), t2: confident('d8', 8)},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('Not imported'), findsOneWidget);
    expect(find.text('Import 1 items'), findsOneWidget);

    await tester.tap(find.text('Import 1 items'));
    await tester.pumpAndSettle();
    expect(confirmed, {'b': const DiveAttachTarget('d8')});
  });

  testWidgets('a failed candidate shows its error and is not imported', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([candidate('a', null, error: 'HTTP 404')], const {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('HTTP 404'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('nothing resolved disables confirm', (tester) async {
    await tester.pumpWidget(host([candidate('a', t3)], {t3: none}));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(confirmed, isNull);
  });

  testWidgets('Choose site from the row menu attaches the site', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t3)],
        {t3: none},
        extraOverrides: [
          sitesProvider.overrideWith(
            (ref) async => const [DiveSite(id: 's1', name: 'Blue Hole')],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hole'));
    await tester.pumpAndSettle();

    expect(find.text('Link to site'), findsOneWidget);
    await tester.tap(find.text('Import 1 items'));
    await tester.pump();
    expect(confirmed, {'a': const SiteAttachTarget('s1')});
    await tester.pumpAndSettle();
  });

  testWidgets('toggling an ambiguous row opens the candidate sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t2)],
        {t2: ambiguous},
        extraOverrides: [
          diveProvider('d1').overrideWith(
            (ref) async =>
                Dive(id: 'd1', diveNumber: 1, dateTime: DateTime(2026, 6, 12)),
          ),
          diveProvider('d2').overrideWith(
            (ref) async =>
                Dive(id: 'd2', diveNumber: 2, dateTime: DateTime(2026, 6, 12)),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // An unchecked ambiguous row opens the candidate chooser on toggle.
    await tester.tap(find.text('a.jpg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#2'));
    await tester.pumpAndSettle();

    expect(find.text('Link to dive'), findsOneWidget);
    await tester.tap(find.text('Import 1 items'));
    await tester.pump();
    expect(confirmed, {'a': const DiveAttachTarget('d2')});
    await tester.pumpAndSettle();
  });

  testWidgets('re-checking an unchecked confident row restores its match', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([candidate('a', t1)], {t1: confident('d7', 7)}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('Not imported'), findsOneWidget);

    await tester.tap(find.text('a.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('Link to #7'), findsOneWidget);
    expect(find.text('Import 1 items'), findsOneWidget);
  });

  testWidgets('Choose dive from the row menu opens the dive picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t3)],
        {t3: none},
        extraOverrides: [
          diveRepositoryProvider.overrideWithValue(
            _FakeDiveRepo([
              Dive(id: 'd5', diveNumber: 5, dateTime: DateTime(2026, 6, 13)),
            ]),
          ),
          currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose dive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#5'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 1 items'));
    await tester.pump();
    expect(confirmed, {'a': const DiveAttachTarget('d5')});
    await tester.pumpAndSettle();
  });

  testWidgets('an asset candidate paints the gallery thumbnail bytes', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t1, preview: const AssetImportPreview('asset-a'))],
        {t1: none},
        extraOverrides: [
          assetThumbnailProvider(
            'asset-a',
          ).overrideWith((ref) async => onePixelPng()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
  });

  testWidgets('a url candidate paints a network thumbnail', (tester) async {
    await tester.pumpWidget(
      host(
        [
          candidate(
            'a',
            t1,
            preview: const UrlImportPreview('https://example.com/a.jpg'),
          ),
        ],
        {t1: none},
        extraOverrides: [
          networkCredentialsServiceProvider.overrideWithValue(_FakeCreds()),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(NetworkThumbnail), findsOneWidget);
  });

  testWidgets('an asset whose bytes are gone shows a centred placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t1, preview: const AssetImportPreview('asset-a'))],
        {t1: none},
        extraOverrides: [
          assetThumbnailProvider('asset-a').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final icon = find.byIcon(Icons.broken_image_outlined);
    expect(icon, findsOneWidget);
    expect(
      tester.getCenter(icon),
      tester.getCenter(find.byType(ImportPreviewThumbnail)),
    );
  });

  testWidgets('a thumbnail that fails to resolve falls back to the icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t1, preview: const AssetImportPreview('asset-a'))],
        {t1: none},
        extraOverrides: [
          assetThumbnailProvider(
            'asset-a',
          ).overrideWith((ref) async => throw StateError('gallery gone')),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('a thumbnail still loading paints neither art nor an icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t1, preview: const AssetImportPreview('asset-a'))],
        {t1: none},
        extraOverrides: [
          assetThumbnailProvider(
            'asset-a',
          ).overrideWith((ref) => Completer<Uint8List?>().future),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(ImportPreviewThumbnail), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });

  testWidgets('a candidate with no preview paints no thumbnail', (
    tester,
  ) async {
    await tester.pumpWidget(host([candidate('a', t1)], {t1: none}));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byType(NetworkThumbnail), findsNothing);
  });
}

/// [NetworkThumbnail] asks for an `Authorization` header before it paints,
/// and the real service reaches for the database.
class _FakeCreds implements NetworkCredentialsService {
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} not stubbed in _FakeCreds',
  );
}

class _FakeDiveRepo implements DiveRepository {
  _FakeDiveRepo(this.dives);
  final List<Dive> dives;

  @override
  Future<List<Dive>> getAllDives({String? diverId}) async => dives;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier() : super('diver-1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
