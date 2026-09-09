import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/media_share_helper.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart'
    show ResolutionStatus;
import 'package:submersion/l10n/arb/app_localizations.dart';

/// writeShareTempFile calls getTemporaryDirectory(), a platform channel with
/// no implementation under flutter_test -- unstubbed it never completes and
/// pumpAndSettle times out.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

/// Records what reached the platform so the success path can be asserted
/// without a real share sheet.
class _FakeSharePlatform extends SharePlatform {
  final List<ShareParams> calls = [];

  /// Makes the platform call fail after it has been recorded, which is how a
  /// real share sheet fails: invoked, then thrown out of.
  bool throwOnShare = false;

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    if (throwOnShare) throw StateError('share sheet unavailable');
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

MediaItem item(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  filePath: '/tmp/$id.jpg',
  originalFilename: '$id.jpg',
  takenAt: DateTime.utc(2026, 6, 12),
  createdAt: DateTime.utc(2026, 6, 12),
  updatedAt: DateTime.utc(2026, 6, 12),
);

void main() {
  // SharePlus.instance is a `static final` that captures
  // SharePlatform.instance the first time it is read and keeps it for the
  // whole isolate. Swapping the platform per test would leave every share
  // after the first one arriving at a fake nobody is looking at -- so there
  // is exactly one, reset between tests.
  final platform = _FakeSharePlatform();
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() => SharePlatform.instance = platform);

  setUp(() async {
    platform.calls.clear();
    tempDir = await Directory.systemTemp.createTemp('share-helper-test');
    // Unlike SharePlatform above, PathProviderPlatform is read per call, so
    // leaving the fake installed points later tests in this isolate at a temp
    // directory tearDown has already deleted.
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    await tempDir.delete(recursive: true);
  });

  Widget host({
    required List<MediaItem> items,
    required ResolvedAssetResult Function(MediaItem) resolve,
    Rect? anchor,
  }) {
    return ProviderScope(
      overrides: [
        resolvedFullResolutionProvider.overrideWith(
          (ref, MediaItem arg) async => resolve(arg),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () =>
                  shareMediaItems(context, ref, items, anchor: anchor),
              child: const Text('SHARE'),
            ),
          ),
        ),
      ),
    );
  }

  ResolvedAssetResult resolved() => ResolvedAssetResult(
    bytes: Uint8List.fromList([1, 2, 3, 4]),
    status: ResolutionStatus.resolved,
  );

  const unavailable = ResolvedAssetResult(status: ResolutionStatus.unavailable);

  testWidgets('a progress indicator covers the resolve', (tester) async {
    final gate = Completer<ResolvedAssetResult>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resolvedFullResolutionProvider.overrideWith(
            (ref, MediaItem arg) => gate.future,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => shareMediaItems(context, ref, [item('a')]),
                child: const Text('SHARE'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('SHARE'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(unavailable);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('nothing resolvable reports it and never opens the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(items: [item('a'), item('b')], resolve: (_) => unavailable),
    );

    await tester.tap(find.text('SHARE'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot share this photo'), findsOneWidget);
    expect(platform.calls, isEmpty);
  });

  /// Taps Share and waits for the share to reach the platform.
  ///
  /// writeShareTempFile does genuine file I/O, and testWidgets' fake async
  /// clock never advances real time -- pumpAndSettle would spin through its
  /// whole budget while the write sits pending. runAsync hands control back
  /// to the real loop for the duration.
  ///
  /// It polls for the recorded call rather than sleeping a fixed span: how
  /// long the resolve and the temp-file write take is a property of the
  /// filesystem, so any constant is a race that a slow CI runner eventually
  /// loses. The deadline only bounds a share that never arrives, and the
  /// caller's own assertion is what fails when it does not.
  ///
  /// Every caller is a success-path test, so "a call was recorded" is the
  /// right thing to wait for. A test asserting the sheet never opens has
  /// nothing to wait for and drives the tap itself.
  Future<void> tapShareAndDrain(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('SHARE'));
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (platform.calls.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      // The call is recorded on entry to the fake's share(), so yield one
      // more turn to let the awaiting handler resume and report its result.
      // A scheduling yield, not a wall-clock guess.
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
  }

  testWidgets('resolvable items reach the share sheet as files', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(items: [item('a'), item('b')], resolve: (_) => resolved()),
    );

    await tapShareAndDrain(tester);

    expect(platform.calls, hasLength(1));
    expect(platform.calls.single.files, hasLength(2));
    expect(platform.calls.single.files!.first.mimeType, 'image/jpeg');
    expect(find.text('Cannot share this photo'), findsNothing);
  });

  testWidgets('unresolvable items are skipped, the rest still share', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        items: [item('good'), item('bad')],
        resolve: (i) => i.id == 'good' ? resolved() : unavailable,
      ),
    );

    await tapShareAndDrain(tester);

    expect(platform.calls.single.files, hasLength(1));
  });

  testWidgets('the temp file actually carries the resolved bytes', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(items: [item('a')], resolve: (_) => resolved()),
    );

    await tapShareAndDrain(tester);

    // Reading the file back is real I/O too, so it needs the real event loop
    // exactly as the write did.
    List<int>? written;
    await tester.runAsync(() async {
      written = await File(
        platform.calls.single.files!.single.path,
      ).readAsBytes();
    });
    expect(written, [1, 2, 3, 4]);
  });

  testWidgets('a resolve failure surfaces instead of hanging the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resolvedFullResolutionProvider.overrideWith(
            (ref, MediaItem arg) async => throw StateError('disk gone'),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => shareMediaItems(context, ref, [item('a')]),
                child: const Text('SHARE'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('SHARE'));
    await tester.pumpAndSettle();

    // The modal barrier must come down even on the failure path, or the user
    // is left staring at a spinner they cannot dismiss.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Failed to share'), findsOneWidget);
    expect(platform.calls, isEmpty);
  });

  group('what the share reports back', () {
    // The library's selection bar leaves multi-select only when its action
    // says it finished (#1262), so this return value is what stops Share
    // being the one bulk action that strands the diver in the mode.
    Widget recordingHost({
      required ResolvedAssetResult Function(MediaItem) resolve,
      required List<bool?> log,
    }) {
      return ProviderScope(
        overrides: [
          resolvedFullResolutionProvider.overrideWith(
            (ref, MediaItem arg) async => resolve(arg),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    log.add(await shareMediaItems(context, ref, [item('a')])),
                child: const Text('SHARE'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('an opened share sheet reports success', (tester) async {
      final log = <bool?>[];
      await tester.pumpWidget(
        recordingHost(resolve: (_) => resolved(), log: log),
      );
      // Real temp-file I/O on the success path, so this needs runAsync the
      // same way the other success assertions do.
      await tapShareAndDrain(tester);

      expect(platform.calls, hasLength(1));
      expect(log, [true]);
    });

    testWidgets('nothing resolvable reports failure', (tester) async {
      final log = <bool?>[];
      await tester.pumpWidget(
        recordingHost(resolve: (_) => unavailable, log: log),
      );
      await tester.tap(find.text('SHARE'));
      await tester.pumpAndSettle();

      expect(platform.calls, isEmpty);
      expect(log, [false]);
    });

    testWidgets('a throwing resolve reports failure', (tester) async {
      final log = <bool?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resolvedFullResolutionProvider.overrideWith(
              (ref, MediaItem arg) async => throw StateError('disk gone'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async =>
                      log.add(await shareMediaItems(context, ref, [item('a')])),
                  child: const Text('SHARE'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SHARE'));
      await tester.pumpAndSettle();

      expect(log, [false]);
    });
  });

  group('iPad share popover anchor', () {
    // On iPad the share sheet is a popover and must point at the control that
    // opened it. share_plus takes that as ShareParams.sharePositionOrigin;
    // with none it centres the popover, so the arrow points at nothing.
    testWidgets('an explicit anchor reaches ShareParams', (tester) async {
      const anchor = Rect.fromLTWH(12, 34, 56, 78);

      await tester.pumpWidget(
        host(items: [item('a')], resolve: (_) => resolved(), anchor: anchor),
      );

      await tapShareAndDrain(tester);

      expect(platform.calls.single.sharePositionOrigin, anchor);
    });

    testWidgets('falls back to the calling widget rather than nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(items: [item('a')], resolve: (_) => resolved()),
      );

      await tapShareAndDrain(tester);

      final origin = platform.calls.single.sharePositionOrigin;
      expect(origin, isNotNull);
      // The host hands over a Consumer's context, which contributes no render
      // object, so the rect resolves to the share button below it -- the whole
      // TextButton, not just its label.
      expect(origin, tester.getRect(find.byType(TextButton)));
      expect(origin!.isEmpty, isFalse);
    });
  });

  group('a failing share leaves the page it was opened from', () {
    // The progress dialog is popped before the platform call, and the catch
    // popped again. A throwing share therefore took the route UNDERNEATH the
    // dialog with it, dropping the diver out of the page they shared from.
    testWidgets('a throwing share sheet does not pop the page underneath', (
      tester,
    ) async {
      platform.throwOnShare = true;
      addTearDown(() => platform.throwOnShare = false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resolvedFullResolutionProvider.overrideWith(
              (ref, MediaItem arg) async => resolved(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: Consumer(
                          builder: (context, ref, _) => Column(
                            children: [
                              const Text('DETAIL'),
                              TextButton(
                                onPressed: () =>
                                    shareMediaItems(context, ref, [item('a')]),
                                child: const Text('SHARE'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL'), findsOneWidget);

      await tapShareAndDrain(tester);
      await tester.pumpAndSettle();

      expect(platform.calls, hasLength(1));
      expect(
        find.text('DETAIL'),
        findsOneWidget,
        reason: 'a failed share must dismiss its own dialog, nothing else',
      );
      expect(find.textContaining('Failed to share'), findsOneWidget);
    });
  });
}
