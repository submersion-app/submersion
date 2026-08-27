import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_pane.dart';
import 'package:submersion/features/media/presentation/widgets/files_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

ExtractedFile _ef(String path) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
);

/// Wraps the widget under test in a localized [MaterialApp].
///
/// The review pane now renders [CaptureTimeOffsetBar], which reads
/// `context.l10n`, so a bare MaterialApp without delegates throws. The locale
/// is pinned to English because these tests assert on English labels.
Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

/// Hand-rolled fakes for tests that don't exercise the commit path.
/// Any unexpected call throws — these tests render the widget tree but
/// never click "Link N items", so no method on these fakes should be hit.
class _UnusedMediaRepository implements MediaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

class _UnusedBookmarkStorage implements LocalBookmarkStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

class _UnusedMediaPlatform implements LocalMediaPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// Test-only notifier that seeds an arbitrary initial [FilesTabState] so the
/// widget can be rendered in any branch without driving it through the
/// picker flow. Mirrors the seeding approach used in
/// `files_tab_providers_test.dart` (which uses a [ProviderContainer] and
/// public mutators), but expressed as a notifier override so widget tests
/// can pump the seeded state directly.
class _SeededFilesTabNotifier extends FilesTabNotifier {
  _SeededFilesTabNotifier(FilesTabState seed)
    : super(
        mediaRepository: _UnusedMediaRepository(),
        bookmarkStorage: _UnusedBookmarkStorage(),
        platform: _UnusedMediaPlatform(),
      ) {
    state = seed;
  }
}

void main() {
  testWidgets('renders Pick files action', (tester) async {
    await tester.pumpWidget(ProviderScope(child: _host(const FilesTab())));
    expect(find.textContaining('Pick files'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows empty-state hint when no files picked', (tester) async {
    await tester.pumpWidget(ProviderScope(child: _host(const FilesTab())));
    expect(find.textContaining('Pick files or'), findsOneWidget);
  });

  testWidgets('renders LinearProgressIndicator while extracting', (
    tester,
  ) async {
    final seeded = FilesTabState.initial().copyWith(
      isExtracting: true,
      extractedCount: 2,
      totalToExtract: 5,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesTabNotifierProvider.overrideWith(
            (ref) => _SeededFilesTabNotifier(seeded),
          ),
        ],
        child: _host(const FilesTab()),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('renders FileReviewPane when files non-empty', (tester) async {
    final files = [_ef('/a.jpg'), _ef('/b.jpg'), _ef('/c.jpg')];
    final seeded = FilesTabState.initial().copyWith(
      files: files,
      match: MatchedSelection.empty(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesTabNotifierProvider.overrideWith(
            (ref) => _SeededFilesTabNotifier(seeded),
          ),
        ],
        child: _host(const FilesTab()),
      ),
    );
    expect(find.byType(FileReviewPane), findsOneWidget);
    // The empty-state hint should not be visible when files are staged.
    expect(find.textContaining('Pick files or'), findsNothing);
  });

  testWidgets('renders both Pick files and Pick a folder buttons', (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(child: _host(const FilesTab())));
    expect(find.text('Pick files…'), findsOneWidget);
    expect(find.text('Pick a folder…'), findsOneWidget);
  });

  testWidgets('renders auto-match Checkbox checked when autoMatchByDate=true', (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(child: _host(const FilesTab())));
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets(
    'renders auto-match Checkbox unchecked when autoMatchByDate=false',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filesTabNotifierProvider.overrideWith(
              (ref) => _SeededFilesTabNotifier(
                FilesTabState.initial().copyWith(autoMatchByDate: false),
              ),
            ),
          ],
          child: _host(const FilesTab()),
        ),
      );
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    },
  );

  testWidgets(
    'tapping the auto-match Checkbox toggles state via the notifier',
    (tester) async {
      final notifier = _SeededFilesTabNotifier(FilesTabState.initial());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [filesTabNotifierProvider.overrideWith((ref) => notifier)],
          child: _host(const FilesTab()),
        ),
      );

      expect(notifier.state.autoMatchByDate, isTrue);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(notifier.state.autoMatchByDate, isFalse);
    },
  );

  testWidgets('shows Link N items button when match.matched is non-empty', (
    tester,
  ) async {
    final files = [_ef('/a.jpg'), _ef('/b.jpg')];
    final seeded = FilesTabState.initial().copyWith(
      files: files,
      match: MatchedSelection(matched: {'d1': files}, unmatched: const []),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesTabNotifierProvider.overrideWith(
            (ref) => _SeededFilesTabNotifier(seeded),
          ),
        ],
        child: _host(const FilesTab()),
      ),
    );

    expect(find.text('Link 2 items'), findsOneWidget);
  });

  // Issue #1098: the button used to disappear entirely when nothing was
  // assignable, which read as "there is no way to save these". It now stays
  // put and disables, matching the URL tab, so the affordance is always
  // discoverable and its disabled state is the honest signal.
  testWidgets('shows a disabled Link button when match.matched is empty', (
    tester,
  ) async {
    final seeded = FilesTabState.initial().copyWith(
      files: [_ef('/a.jpg')],
      match: MatchedSelection(matched: const {}, unmatched: [_ef('/a.jpg')]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesTabNotifierProvider.overrideWith(
            (ref) => _SeededFilesTabNotifier(seeded),
          ),
        ],
        child: _host(const FilesTab()),
      ),
    );
    expect(find.text('Link 0 items'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(button.onPressed, isNull);
  });

  testWidgets('shows no commit button before any file is staged', (
    tester,
  ) async {
    // A permanently-greyed button over an empty canvas is noise; the button
    // earns its place only once there is something staged to act on.
    await tester.pumpWidget(ProviderScope(child: _host(const FilesTab())));
    expect(find.textContaining('Link '), findsNothing);
  });

  testWidgets(
    'progress indicator value reflects extractedCount / totalToExtract',
    (tester) async {
      final seeded = FilesTabState.initial().copyWith(
        isExtracting: true,
        extractedCount: 3,
        totalToExtract: 10,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filesTabNotifierProvider.overrideWith(
              (ref) => _SeededFilesTabNotifier(seeded),
            ),
          ],
          child: _host(const FilesTab()),
        ),
      );
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 0.3);
    },
  );

  testWidgets('progress indicator is indeterminate when totalToExtract is 0', (
    tester,
  ) async {
    final seeded = FilesTabState.initial().copyWith(
      isExtracting: true,
      extractedCount: 0,
      totalToExtract: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesTabNotifierProvider.overrideWith(
            (ref) => _SeededFilesTabNotifier(seeded),
          ),
        ],
        child: _host(const FilesTab()),
      ),
    );
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, isNull); // indeterminate
  });

  // commit() only persists files in match.matched, and the Link button is
  // gated on matched being non-empty, so a photo the date matcher rejected
  // could never be linked. When the picker was opened from a dive, that dive
  // is an obvious manual target.
  group('manual assignment to the picker\'s dive', () {
    Widget wrap(FilesTabState seed, {String? diveId}) => ProviderScope(
      overrides: [
        filesTabNotifierProvider.overrideWith(
          (ref) => _SeededFilesTabNotifier(seed),
        ),
      ],
      child: _host(
        FilesTab(target: diveId == null ? null : DiveAttachTarget(diveId)),
      ),
    );

    FilesTabState withUnmatched(List<ExtractedFile> files) =>
        FilesTabState.initial().copyWith(
          files: files,
          match: MatchedSelection(matched: const {}, unmatched: files),
        );

    testWidgets('offers a bulk add action when opened from a dive', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(withUnmatched([_ef('/a.jpg'), _ef('/b.jpg')]), diveId: 'd1'),
      );

      expect(find.text('Add all 2 to this dive'), findsOneWidget);
    });

    testWidgets('offers no bulk add action when opened without a dive', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(withUnmatched([_ef('/a.jpg')])));

      expect(find.textContaining('Add all'), findsNothing);
    });

    testWidgets('bulk add routes every unmatched file to the dive', (
      tester,
    ) async {
      final files = [_ef('/a.jpg'), _ef('/b.jpg')];
      final notifier = _SeededFilesTabNotifier(withUnmatched(files));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [filesTabNotifierProvider.overrideWith((ref) => notifier)],
          child: _host(const FilesTab(target: DiveAttachTarget('d1'))),
        ),
      );

      await tester.tap(find.text('Add all 2 to this dive'));
      await tester.pump();

      expect(notifier.state.match.matched['d1'], files);
      expect(notifier.state.match.unmatched, isEmpty);
      // The Link button was previously unreachable in this state.
      expect(find.text('Link 2 items'), findsOneWidget);
    });

    testWidgets('turning auto-match off still leaves files linkable', (
      tester,
    ) async {
      final files = [_ef('/a.jpg')];
      final seed = FilesTabState.initial().copyWith(
        autoMatchByDate: false,
        files: files,
        match: MatchedSelection(matched: const {}, unmatched: files),
      );
      await tester.pumpWidget(wrap(seed, diveId: 'd1'));

      // Without an assign affordance the unchecked checkbox made the whole
      // tab a no-op: nothing could ever reach commit().
      expect(find.text('Add 1 to this dive'), findsOneWidget);
    });
  });

  // Issue #1098. Opened from a dive site, the tab offered no way to accept the
  // picked files: the commit button was gated on the dive matcher having
  // produced a group, and a site never produces one. The site is now the
  // target, so dive matching does not apply at all.
  group('site target', () {
    Widget wrap(FilesTabState seed) => ProviderScope(
      overrides: [
        filesTabNotifierProvider.overrideWith(
          (ref) => _SeededFilesTabNotifier(seed),
        ),
      ],
      child: _host(const FilesTab(target: SiteAttachTarget('site-1'))),
    );

    FilesTabState staged(List<ExtractedFile> files) =>
        FilesTabState.initial().copyWith(
          files: files,
          // What auto-match leaves behind when nothing lines up with a dive,
          // which is the normal outcome for a site.
          match: MatchedSelection(matched: const {}, unmatched: files),
        );

    testWidgets('offers an enabled commit button for unmatched files', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(staged([_ef('/a.jpg')])));

      expect(find.text('Attach 1 item to this site'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Attach 1 item to this site'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('pluralises the commit button label', (tester) async {
      await tester.pumpWidget(wrap(staged([_ef('/a.jpg'), _ef('/b.jpg')])));

      expect(find.text('Attach 2 items to this site'), findsOneWidget);
    });

    testWidgets('shows no commit button before any file is staged', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(FilesTabState.initial()));

      expect(find.textContaining('Attach '), findsNothing);
    });

    testWidgets('hides the dive auto-match checkbox', (tester) async {
      // A site has no time window, so matching photos to dives by date would
      // silently route them somewhere the user did not ask for.
      await tester.pumpWidget(wrap(staged([_ef('/a.jpg')])));

      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Auto-match'), findsNothing);
    });

    testWidgets('offers no dive assignment affordances', (tester) async {
      await tester.pumpWidget(wrap(staged([_ef('/a.jpg')])));

      expect(find.textContaining('to this dive'), findsNothing);
      expect(find.text('Unmatched'), findsNothing);
      // The assign affordances are icon buttons carrying only a tooltip, so a
      // visible-text assertion alone passes vacuously.
      expect(find.byTooltip('Choose a dive'), findsNothing);
      expect(find.byTooltip('Add to this dive'), findsNothing);
    });

    testWidgets('counts staged files as items, not photos', (tester) async {
      // FileType.media admits video, and the folder scan admits
      // .mp4/.mov/.m4v, so a staged set can be entirely video.
      final clip = ExtractedFile(
        sourcePath: '/clip.mp4',
        file: File('/clip.mp4'),
        metadata: const MediaSourceMetadata(mimeType: 'video/mp4'),
      );
      await tester.pumpWidget(wrap(staged([clip])));

      expect(find.text('1 item'), findsOneWidget);
      expect(find.textContaining('photo'), findsNothing);
    });

    testWidgets('lists every staged file flat', (tester) async {
      await tester.pumpWidget(wrap(staged([_ef('/a.jpg'), _ef('/b.jpg')])));

      expect(find.text('a.jpg'), findsOneWidget);
      expect(find.text('b.jpg'), findsOneWidget);
      // No dive grouping to expand or collapse.
      expect(find.byType(ExpansionTile), findsNothing);
    });
  });
}
