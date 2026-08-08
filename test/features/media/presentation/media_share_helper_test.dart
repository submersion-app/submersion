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

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
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

  setUpAll(() => SharePlatform.instance = platform);

  setUp(() async {
    platform.calls.clear();
    tempDir = await Directory.systemTemp.createTemp('share-helper-test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() => tempDir.delete(recursive: true));

  Widget host({
    required List<MediaItem> items,
    required ResolvedAssetResult Function(MediaItem) resolve,
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
              onPressed: () => shareMediaItems(context, ref, items),
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

  /// Taps Share and lets the real event loop run.
  ///
  /// writeShareTempFile does genuine file I/O, and testWidgets' fake async
  /// clock never advances real time -- pumpAndSettle would spin through its
  /// whole budget while the write sits pending. runAsync hands control back
  /// to the real loop for the duration.
  Future<void> tapShareAndDrain(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('SHARE'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
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
}
