import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/capture_time_offset_bar.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_pane.dart';

import '../../../../helpers/test_app.dart';

ExtractedFile _ef(String path) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: MediaSourceMetadata(
    takenAt: DateTime.utc(2024, 4, 1),
    mimeType: 'image/jpeg',
  ),
);

FilesTabState _staged() => FilesTabState.initial().copyWith(
  files: [_ef('/a.jpg'), _ef('/b.jpg'), _ef('/c.jpg')],
  match: MatchedSelection(
    matched: {
      'd1': [_ef('/a.jpg'), _ef('/b.jpg')],
    },
    unmatched: [_ef('/c.jpg')],
  ),
);

Future<void> _pumpPane(
  WidgetTester tester,
  FilesTabState state, {
  bool flat = false,
  String? assignableDiveId,
  List<dynamic>? overrides,
  List<Dive> dives = const [],
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        divesProvider.overrideWith((ref) async => dives),
        ...?overrides,
      ],
      child: FileReviewPane(
        state: state,
        flat: flat,
        assignableDiveId: assignableDiveId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fails loudly if the bulk action reaches past the notifier method under
/// test into any collaborator.
class _UnusedDependency
    implements MediaRepository, LocalBookmarkStorage, LocalMediaPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// Records the dive ids passed to [assignAllUnmatched] instead of mutating
/// state, so a test can see exactly what the pane's bulk action dispatched.
class _RecordingFilesTabNotifier extends FilesTabNotifier {
  _RecordingFilesTabNotifier()
    : super(
        mediaRepository: _UnusedDependency(),
        bookmarkStorage: _UnusedDependency(),
        platform: _UnusedDependency(),
      );

  final List<String> assignedDiveIds = [];

  @override
  void assignAllUnmatched(String diveId) => assignedDiveIds.add(diveId);
}

void main() {
  testWidgets('summary shows file/dive/unmatched counts', (tester) async {
    await _pumpPane(tester, _staged());

    // "files", not "photos": the tab admits video too.
    expect(find.textContaining('3 files'), findsOneWidget);
    expect(find.textContaining('1 dive'), findsOneWidget);
    expect(find.textContaining('1 unmatched'), findsOneWidget);
  });

  testWidgets('a dive group is headed by the dive, not its id', (tester) async {
    // Issue #3423: the header printed "Dive <uuid>", an id shown nowhere else
    // in the app, so the user could not tell which dive the photos landed on.
    // The header's date comes from DateFormat, which reads the process-global
    // Intl.defaultLocale rather than testApp's MaterialApp locale; pin it.
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previousLocale);
    final entry = DateTime.utc(2016, 8, 11, 9, 40);
    final dive = Dive(
      id: 'd1',
      diveNumber: 142,
      dateTime: entry,
      entryTime: entry,
      exitTime: DateTime.utc(2016, 8, 11, 10, 35),
      site: const DiveSite(id: 's1', name: 'Blue Hole'),
    );

    await _pumpPane(tester, _staged(), dives: [dive]);

    expect(find.text('Dive #142 · Blue Hole'), findsOneWidget);
    expect(
      find.text('Aug 11, 2016 · 9:40 AM – 10:35 AM · 2 files'),
      findsOneWidget,
    );
    expect(find.textContaining('d1'), findsNothing);
  });

  testWidgets('a group whose dive is not loaded is headed "Dive", not its id', (
    tester,
  ) async {
    // The dive list may still be loading, or the dive was deleted mid-review.
    await _pumpPane(tester, _staged());

    expect(find.text('Dive'), findsOneWidget);
    expect(find.textContaining('d1'), findsNothing);
  });

  testWidgets('the offset bar is shown while files are staged', (tester) async {
    await _pumpPane(tester, _staged());

    expect(find.byType(CaptureTimeOffsetBar), findsOneWidget);
  });

  testWidgets('the offset bar stays visible once everything matched', (
    tester,
  ) async {
    // Gating the bar on unmatched.isNotEmpty would hide it here, stranding a
    // user who shifted too far with no way back.
    final state = FilesTabState.initial().copyWith(
      files: [_ef('/a.jpg')],
      match: MatchedSelection(
        matched: {
          'd1': [_ef('/a.jpg')],
        },
        unmatched: const [],
      ),
    );

    await _pumpPane(tester, state);

    expect(find.byType(CaptureTimeOffsetBar), findsOneWidget);
  });

  testWidgets('the offset bar is hidden when auto-match is off', (
    tester,
  ) async {
    await _pumpPane(tester, _staged().copyWith(autoMatchByDate: false));

    expect(find.byType(CaptureTimeOffsetBar), findsNothing);
  });

  testWidgets('the offset bar is hidden with no staged files', (tester) async {
    await _pumpPane(tester, FilesTabState.initial());

    expect(find.byType(CaptureTimeOffsetBar), findsNothing);
  });

  testWidgets('the offset bar is hidden in a site session', (tester) async {
    // A site owns every picked file, so there is no matching to correct.
    await _pumpPane(tester, _staged(), flat: true);

    expect(find.byType(CaptureTimeOffsetBar), findsNothing);
  });

  testWidgets('the site variant offers no dive assignment affordance', (
    tester,
  ) async {
    // commit() for a site persists every staged file with the site id and
    // ignores dive grouping outright, so a "choose a dive" action there does
    // nothing and misleads.
    await _pumpPane(tester, _staged(), flat: true);

    expect(find.byTooltip('Choose a dive'), findsNothing);
    expect(find.byTooltip('Add to this dive'), findsNothing);
    expect(find.byIcon(Icons.add_link), findsNothing);
  });

  testWidgets('the Unmatched header keeps its chevron and its bulk action '
      'assigns without collapsing the group', (tester) async {
    // The bulk action lives in the header's subtitle, not its trailing:
    // trailing would replace the expand chevron and, measured before the
    // title, squeeze "Unmatched" to one fragment per line (issue #2717).
    // Inside the header it must still take its own tap rather than toggling
    // the group shut.
    final notifier = _RecordingFilesTabNotifier();
    final state = FilesTabState.initial().copyWith(
      files: [_ef('/a.jpg'), _ef('/b.jpg'), _ef('/c.jpg')],
      match: MatchedSelection(
        matched: {
          'd1': [_ef('/a.jpg')],
        },
        unmatched: [_ef('/b.jpg'), _ef('/c.jpg')],
      ),
    );

    await _pumpPane(
      tester,
      state,
      assignableDiveId: 'd1',
      overrides: [filesTabNotifierProvider.overrideWith((ref) => notifier)],
    );

    final unmatchedTile = find.ancestor(
      of: find.text('Unmatched'),
      matching: find.byType(ExpansionTile),
    );
    expect(unmatchedTile, findsOneWidget);
    expect(
      find.descendant(
        of: unmatchedTile,
        matching: find.byIcon(Icons.expand_more),
      ),
      findsOneWidget,
      reason: 'the bulk action must not replace the expand chevron',
    );

    await tester.tap(find.text('Add all 2 to this dive'));
    await tester.pumpAndSettle();

    expect(notifier.assignedDiveIds, ['d1']);
    expect(
      find.text('b.jpg'),
      findsOneWidget,
      reason: 'tapping the action must not collapse the Unmatched group',
    );
    expect(find.text('c.jpg'), findsOneWidget);
  });
}
