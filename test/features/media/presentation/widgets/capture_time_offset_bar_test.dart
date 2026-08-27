import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/capture_time_offset_bar.dart';

import '../../../../helpers/test_app.dart';

ExtractedFile _ef(String path, DateTime takenAt) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: MediaSourceMetadata(takenAt: takenAt, mimeType: 'image/jpeg'),
);

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

/// Test-only notifier seeded with a staged state, so the bar's re-match lands
/// somewhere observable without a repository behind it.
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

/// A dive from 11:26 to 12:09, so a file stamped 16:47 needs a -5h shift to
/// land inside the window.
final _dive = Dive(
  id: 'dive-1',
  dateTime: DateTime.utc(2025, 12, 27, 11, 26),
  exitTime: DateTime.utc(2025, 12, 27, 12, 9),
);

Future<FilesTabState> _pumpBar(WidgetTester tester) async {
  final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));
  final seed = FilesTabState.initial().copyWith(
    files: [file],
    match: MatchedSelection(matched: const {}, unmatched: [file]),
  );

  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        divesProvider.overrideWith((ref) async => [_dive]),
        filesTabNotifierProvider.overrideWith(
          (ref) => _SeededFilesTabNotifier(seed),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) =>
            CaptureTimeOffsetBar(state: ref.watch(filesTabNotifierProvider)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return seed;
}

FilesTabState _stateOf(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CaptureTimeOffsetBar)),
  );
  return container.read(filesTabNotifierProvider);
}

void main() {
  testWidgets('starts at no shift', (tester) async {
    await _pumpBar(tester);
    expect(find.text('0m'), findsOneWidget);
  });

  testWidgets('stepping back five hours rescues an unmatched file', (
    tester,
  ) async {
    await _pumpBar(tester);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
      await tester.pumpAndSettle();
    }

    final state = _stateOf(tester);
    expect(state.captureTimeOffset, const Duration(hours: -5));
    expect(state.match.matched['dive-1'], isNotNull);
    expect(state.match.unmatched, isEmpty);
  });

  testWidgets('the fine stepper moves in fifteen-minute steps', (tester) async {
    await _pumpBar(tester);

    await tester.tap(find.byTooltip('Shift 15m later'));
    await tester.pumpAndSettle();

    expect(_stateOf(tester).captureTimeOffset, const Duration(minutes: 15));
    expect(find.text('+15m'), findsOneWidget);
  });

  testWidgets('reset returns the offset to zero and re-matches', (
    tester,
  ) async {
    await _pumpBar(tester);

    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pumpAndSettle();
    expect(_stateOf(tester).captureTimeOffset, const Duration(hours: -1));

    await tester.tap(find.byTooltip('Reset to no shift'));
    await tester.pumpAndSettle();

    final state = _stateOf(tester);
    expect(state.captureTimeOffset, Duration.zero);
    expect(state.match.unmatched, isNotEmpty);
  });

  testWidgets('reset is disabled while there is no shift to undo', (
    tester,
  ) async {
    await _pumpBar(tester);

    // byTooltip resolves to the internal RawTooltip, so reach the button by
    // its icon to inspect onPressed.
    final reset = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.restart_alt),
    );
    expect(reset.onPressed, isNull);
  });

  testWidgets('a file removed while the bounds load is not resurrected', (
    tester,
  ) async {
    // diveBoundsProvider hits the database on first use, so the await in
    // _apply is a real window. setCaptureTimeOffset replaces `match` but not
    // `files`; matching against a stale file list would put a removed file
    // back into a rendered group.
    final keep = _ef('/keep.jpg', DateTime.utc(2025, 12, 27, 16, 47));
    final doomed = _ef('/doomed.jpg', DateTime.utc(2025, 12, 27, 16, 50));
    final seed = FilesTabState.initial().copyWith(
      files: [keep, doomed],
      match: MatchedSelection(matched: const {}, unmatched: [keep, doomed]),
    );
    final notifier = _SeededFilesTabNotifier(seed);
    final gate = Completer<List<Dive>>();

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          divesProvider.overrideWith((ref) => gate.future),
          filesTabNotifierProvider.overrideWith((ref) => notifier),
        ],
        child: Consumer(
          builder: (context, ref, _) =>
              CaptureTimeOffsetBar(state: ref.watch(filesTabNotifierProvider)),
        ),
      ),
    );
    await tester.pump();

    // Start the shift, then remove a file before the bounds resolve.
    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pump();
    notifier.removeFile('/doomed.jpg');
    expect(notifier.state.files, [keep]);

    gate.complete([_dive]);
    await tester.pumpAndSettle();

    final everywhere = [
      ...notifier.state.match.unmatched,
      ...notifier.state.match.matched.values.expand((l) => l),
    ].map((f) => f.sourcePath);
    expect(everywhere, isNot(contains('/doomed.jpg')));
    expect(notifier.state.files, [keep]);
  });

  testWidgets('two quick steps both count', (tester) async {
    // Each tap computed its new offset from the widget's build-time state, so
    // a second tap landing before the first resolved based its arithmetic on
    // the same stale value and silently lost a step.
    final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));
    final notifier = _SeededFilesTabNotifier(
      FilesTabState.initial().copyWith(
        files: [file],
        match: MatchedSelection(matched: const {}, unmatched: [file]),
      ),
    );
    final gate = Completer<List<Dive>>();

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          divesProvider.overrideWith((ref) => gate.future),
          filesTabNotifierProvider.overrideWith((ref) => notifier),
        ],
        child: Consumer(
          builder: (context, ref, _) =>
              CaptureTimeOffsetBar(state: ref.watch(filesTabNotifierProvider)),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pump();
    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pump();

    gate.complete([_dive]);
    await tester.pumpAndSettle();

    expect(notifier.state.captureTimeOffset, const Duration(hours: -2));
  });
}
