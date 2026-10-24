import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/media_share_helper.dart';
import 'package:submersion/features/media/presentation/helpers/share_preparation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

class _FakeSharePlatform extends SharePlatform {
  final List<ShareParams> calls = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

MediaItem _video(String id) => MediaItem(
  id: id,
  diveId: 'd1',
  mediaType: MediaType.video,
  sourceType: MediaSourceType.localFile,
  originalFilename: '$id.mov',
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

typedef _Prepare =
    Future<SharePreparation> Function(
      void Function(VideoShareProgress) onProgress,
      ColorEncodeCancel cancel,
      int Function() backgroundEntries,
    );

/// Issue #3521: the share flow's dialogs around preparing the files.
void main() {
  final platform = _FakeSharePlatform();
  late SharePlatform original;

  setUpAll(() {
    original = SharePlatform.instance;
    SharePlatform.instance = platform;
  });
  tearDownAll(() => SharePlatform.instance = original);
  setUp(platform.calls.clear);

  final corrected = XFile('/t/v1.mp4', name: 'v1.mp4');
  final originalFile = XFile('/t/v2.mov', name: 'v2.mov');

  Future<void> pumpHost(
    WidgetTester tester, {
    required _Prepare prepare,
    bool showVideoProgress = true,
    bool systemStopsEncodes = true,
    List<MediaItem>? items,
    List<MediaItem>? originalsAsked,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runShareFlow(
                context,
                showVideoProgress: showVideoProgress,
                systemStopsEncodes: systemStopsEncodes,
                prepare: prepare,
                originals: (failed) async {
                  originalsAsked?.addAll(failed);
                  return [originalFile];
                },
              ),
              child: const Text('SHARE'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SHARE'));
    await tester.pump();
  }

  testWidgets('a share with no video to correct keeps the spinner', (
    tester,
  ) async {
    final gate = Completer<SharePreparation>();
    await pumpHost(
      tester,
      showVideoProgress: false,
      prepare: (_, _, _) => gate.future,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Preparing video'), findsNothing);
    gate.complete(
      ShareReady(files: [corrected], failedVideos: [], correctedCopies: []),
    );
    await tester.pumpAndSettle();
    expect(platform.calls.single.files, [corrected]);
  });

  testWidgets('a corrected video share shows progress with percentage', (
    tester,
  ) async {
    final gate = Completer<SharePreparation>();
    late void Function(VideoShareProgress) report;
    await pumpHost(
      tester,
      prepare: (onProgress, _, _) {
        report = onProgress;
        return gate.future;
      },
    );
    report(const VideoShareProgress(index: 1, total: 1, fraction: 0.25));
    await tester.pump();
    expect(find.text('Preparing video'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    gate.complete(
      ShareReady(files: [corrected], failedVideos: [], correctedCopies: []),
    );
    await tester.pumpAndSettle();
    expect(find.text('Preparing video'), findsNothing);
    expect(platform.calls.single.files, [corrected]);
  });

  testWidgets('two corrected videos show 2 of 2', (tester) async {
    final gate = Completer<SharePreparation>();
    late void Function(VideoShareProgress) report;
    await pumpHost(
      tester,
      prepare: (onProgress, _, _) {
        report = onProgress;
        return gate.future;
      },
    );
    report(const VideoShareProgress(index: 2, total: 2));
    await tester.pump();
    expect(find.text('Preparing video 2 of 2'), findsOneWidget);
    gate.complete(const ShareCancelled());
    await tester.pumpAndSettle();
  });

  testWidgets('Cancel opens no share sheet and shows no error', (tester) async {
    late ColorEncodeCancel token;
    await pumpHost(
      tester,
      prepare: (_, cancel, _) async {
        token = cancel;
        await cancel.whenCancelled;
        return const ShareCancelled();
      },
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(token.isCancelled, isTrue);
    expect(platform.calls, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Preparing video'), findsNothing);
    expect(find.text('SHARE'), findsOneWidget);
  });

  testWidgets('Back during preparation cancels and keeps the page', (
    tester,
  ) async {
    late ColorEncodeCancel token;
    await pumpHost(
      tester,
      prepare: (_, cancel, _) async {
        token = cancel;
        await cancel.whenCancelled;
        return const ShareCancelled();
      },
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(token.isCancelled, isTrue);
    expect(find.text('SHARE'), findsOneWidget);
    expect(platform.calls, isEmpty);
  });

  testWidgets('Share original shares the original beside prepared files', (
    tester,
  ) async {
    final asked = <MediaItem>[];
    final failed = _video('v2');
    await pumpHost(
      tester,
      originalsAsked: asked,
      prepare: (_, _, _) async => ShareReady(
        files: [corrected],
        failedVideos: [failed],
        correctedCopies: [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't apply the color correction"), findsOneWidget);
    expect(
      find.text('This video can still be shared without it.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Share original'));
    await tester.pumpAndSettle();
    expect(asked, [failed]);
    expect(platform.calls.single.files, [corrected, originalFile]);
  });

  testWidgets('several failures say how many', (tester) async {
    await pumpHost(
      tester,
      prepare: (_, _, _) async => ShareReady(
        files: [],
        failedVideos: [_video('a'), _video('b')],
        correctedCopies: [],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('2 videos can still be shared without it.'),
      findsOneWidget,
    );
  });

  testWidgets('the failure dialog Cancel shares nothing', (tester) async {
    await pumpHost(
      tester,
      prepare: (_, _, _) async => ShareReady(
        files: [corrected],
        failedVideos: [_video('v2')],
        correctedCopies: [],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(platform.calls, isEmpty);
    expect(find.text("Couldn't apply the color correction"), findsNothing);
  });

  testWidgets('interrupted shows the background message', (tester) async {
    await pumpHost(
      tester,
      prepare: (_, _, _) async => const ShareInterrupted(),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Preparing the video stopped when Submersion went into the '
        'background. Share again to start over.',
      ),
      findsOneWidget,
    );
    expect(platform.calls, isEmpty);
  });

  testWidgets('on desktop, hiding the window is not a background trip', (
    tester,
  ) async {
    final gate = Completer<void>();
    late int Function() trips;
    await pumpHost(
      tester,
      systemStopsEncodes: false,
      prepare: (_, _, backgroundEntries) async {
        trips = backgroundEntries;
        await gate.future;
        return const ShareCancelled();
      },
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(trips(), 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('leaving the foreground is reported to the preparation', (
    tester,
  ) async {
    final gate = Completer<void>();
    late int Function() trips;
    await pumpHost(
      tester,
      prepare: (_, _, backgroundEntries) async {
        trips = backgroundEntries;
        await gate.future;
        return const ShareCancelled();
      },
    );
    expect(trips(), 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(trips(), 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    gate.complete();
    await tester.pumpAndSettle();
  });
}
