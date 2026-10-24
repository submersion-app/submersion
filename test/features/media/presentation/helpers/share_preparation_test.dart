import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/share_preparation.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

MediaItem _item(
  String id, {
  MediaType type = MediaType.video,
  ColorAdjustment? adjustment,
}) => MediaItem(
  id: id,
  diveId: 'd1',
  mediaType: type,
  sourceType: MediaSourceType.platformGallery,
  originalFilename: type == MediaType.video ? '$id.mov' : '$id.jpg',
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  durationSeconds: 10,
  colorAdjustment: adjustment,
);

const _warm = ColorAdjustment(warmth: 0.5);

enum _Outcome { ok, fail, unsupported, waitForCancel, systemCancel }

class _FakeEncoder implements ColorEncoder {
  _FakeEncoder(this.outcomes);
  final List<_Outcome> outcomes;
  final calls = <({String source, String output, ColorTimeline timeline})>[];

  @override
  Future<void> encodeWithColor({
    required File source,
    required File output,
    required ColorTimeline timeline,
    ColorEncodeCancel? cancel,
    void Function(double fraction)? onProgress,
  }) async {
    calls.add((source: source.path, output: output.path, timeline: timeline));
    final outcome = outcomes[calls.length - 1];
    onProgress?.call(0.5);
    switch (outcome) {
      case _Outcome.ok:
        await output.writeAsBytes([1, 2, 3]);
      case _Outcome.fail:
        throw const TranscodeException('encoder error');
      case _Outcome.unsupported:
        throw const TranscodeUnsupportedException('8K');
      case _Outcome.waitForCancel:
        await cancel!.whenCancelled;
        throw const TranscodeCancelledException();
      case _Outcome.systemCancel:
        throw const TranscodeCancelledException();
    }
  }
}

/// Issue #3521: share files are prepared, corrected videos re-encoded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('share_prep_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathChannel,
          (call) async =>
              call.method == 'getTemporaryDirectory' ? temp.path : null,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    await temp.delete(recursive: true);
  });

  Future<T> withRef<T>(
    WidgetTester tester,
    Future<T> Function(WidgetRef ref) body, {
    ColorEncoder? encoder,
    bool noEncoder = false,
    String? Function(MediaItem)? pathFor,
    bool pathThrows = false,
    bool accessOpens = true,
    String? throwsFor,
  }) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diverAutoColorCorrectionProvider.overrideWithValue(false),
          colorEncoderProvider.overrideWithValue(noEncoder ? null : encoder),
          resolvedFilePathProvider.overrideWith((ref, item) async {
            if (pathThrows) throw StateError('store offline');
            return pathFor != null ? pathFor(item) : '/videos/${item.id}.mov';
          }),
          resolvedFullResolutionProvider.overrideWith((ref, item) async {
            if (item.id == throwsFor) throw StateError('resolve failed');
            return ResolvedAssetResult(
              bytes: Uint8List.fromList(item.id.codeUnits),
              status: ResolutionStatus.resolved,
            );
          }),
          videoFileAccessProvider.overrideWithValue(
            <R>({path, bookmarkRef, required read}) async =>
                path == null || !accessOpens ? null : read(path),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    return (await tester.runAsync(() => body(widgetRef))) as T;
  }

  Future<bool> exists(WidgetTester tester, String path) async =>
      (await tester.runAsync(() => File(path).exists()))!;

  testWidgets("uncorrected items keep today's files and never encode", (
    tester,
  ) async {
    final encoder = _FakeEncoder([]);
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [_item('v1'), _item('p1', type: MediaType.photo)],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      encoder: encoder,
    );
    final ready = result as ShareReady;
    expect(encoder.calls, isEmpty);
    expect(ready.failedVideos, isEmpty);
    expect(ready.files.map((f) => f.name), ['v1.mov', 'p1.jpg']);
  });

  testWidgets('a corrected video is encoded to share/<id>/<stem>.mp4', (
    tester,
  ) async {
    final encoder = _FakeEncoder([_Outcome.ok]);
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [_item('v1', adjustment: _warm)],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      encoder: encoder,
    );
    final ready = result as ShareReady;
    final call = encoder.calls.single;
    expect(call.source, '/videos/v1.mov');
    expect(call.output, p.join(temp.path, 'share', 'v1', 'v1.mp4'));
    expect(call.timeline.keys, hasLength(1));
    expect(ready.files.single.path, call.output);
    expect(ready.files.single.mimeType, 'video/mp4');
    expect(ready.files.single.name, 'v1.mp4');
  });

  testWidgets('progress reports index of total and fraction', (tester) async {
    final seen = <(int, int, double?)>[];
    await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [
          _item('v1', adjustment: _warm),
          _item('p1', type: MediaType.photo),
          _item('v2', adjustment: _warm),
        ],
        onProgress: (p) => seen.add((p.index, p.total, p.fraction)),
        cancel: ColorEncodeCancel(),
      ),
      encoder: _FakeEncoder([_Outcome.ok, _Outcome.ok]),
    );
    expect(seen, [(1, 2, null), (1, 2, 0.5), (2, 2, null), (2, 2, 0.5)]);
  });

  testWidgets('a failing video is listed and later items still prepared', (
    tester,
  ) async {
    final v1 = _item('v1', adjustment: _warm);
    final v2 = _item('v2', adjustment: _warm);
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [v1, v2, _item('p1', type: MediaType.photo)],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      encoder: _FakeEncoder([_Outcome.unsupported, _Outcome.ok]),
    );
    final ready = result as ShareReady;
    expect(ready.failedVideos, [v1]);
    expect(ready.files.map((f) => f.name), ['v2.mp4', 'p1.jpg']);
  });

  testWidgets('a failing encode leaves no partial or tmp file', (tester) async {
    final out = p.join(temp.path, 'share', 'v1', 'v1.mp4');
    await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [_item('v1', adjustment: _warm)],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      encoder: _FakeEncoder([_Outcome.fail]),
    );
    expect(await exists(tester, out), isFalse);
    expect(await exists(tester, '$out.tmp'), isFalse);
  });

  testWidgets('no encoder on this platform lists the video as failed', (
    tester,
  ) async {
    final v1 = _item('v1', adjustment: _warm);
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [v1],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      noEncoder: true,
    );
    expect((result as ShareReady).failedVideos, [v1]);
  });

  testWidgets('an unreachable file lists the video as failed', (tester) async {
    final v1 = _item('v1', adjustment: _warm);
    final encoder = _FakeEncoder([]);
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [v1],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      encoder: encoder,
      pathFor: (_) => null,
    );
    expect((result as ShareReady).failedVideos, [v1]);
    expect(encoder.calls, isEmpty);
  });

  testWidgets('cancel stops the encode and deletes written copies', (
    tester,
  ) async {
    final first = p.join(temp.path, 'share', 'v1', 'v1.mp4');
    final result = await withRef(tester, (ref) {
      // Made inside the real-async body: a Completer created in the
      // fake-async test zone completes through microtasks that never run
      // during runAsync.
      final cancel = ColorEncodeCancel();
      return prepareShareFiles(
        ref,
        [_item('v1', adjustment: _warm), _item('v2', adjustment: _warm)],
        onProgress: (p) {
          if (p.index == 2 && p.fraction != null) cancel.cancel();
        },
        cancel: cancel,
      );
    }, encoder: _FakeEncoder([_Outcome.ok, _Outcome.waitForCancel]));
    expect(result, isA<ShareCancelled>());
    expect(await exists(tester, first), isFalse);
  });

  testWidgets('failure after leaving the foreground is ShareInterrupted', (
    tester,
  ) async {
    var trips = 0;
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [_item('v1', adjustment: _warm)],
        // The app goes away while the encode runs.
        onProgress: (p) {
          if (p.fraction != null) trips++;
        },
        cancel: ColorEncodeCancel(),
        backgroundEntries: () => trips,
      ),
      encoder: _FakeEncoder([_Outcome.fail]),
    );
    expect(result, isA<ShareInterrupted>());
  });

  testWidgets('a failure after an earlier trip away is still a failure', (
    tester,
  ) async {
    final v2 = _item('v2', adjustment: _warm);
    var trips = 0;
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [_item('v1', adjustment: _warm), v2],
        // The app goes away during the first encode only.
        onProgress: (p) {
          if (p.index == 1 && p.fraction != null) trips++;
        },
        cancel: ColorEncodeCancel(),
        backgroundEntries: () => trips,
      ),
      encoder: _FakeEncoder([_Outcome.ok, _Outcome.unsupported]),
    );
    expect((result as ShareReady).failedVideos, [v2]);
  });

  testWidgets('a cancel the diver did not ask for is ShareInterrupted', (
    tester,
  ) async {
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [_item('v1', adjustment: _warm)],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      encoder: _FakeEncoder([_Outcome.systemCancel]),
    );
    expect(result, isA<ShareInterrupted>());
  });

  testWidgets('a correction that comes out as nothing shares the original', (
    tester,
  ) async {
    // Auto switched off for this clip and no sliders moved: it may need
    // correcting by the look of it, but nothing would change.
    final encoder = _FakeEncoder([]);
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [_item('v1', adjustment: const ColorAdjustment(autoOverride: false))],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      encoder: encoder,
    );
    expect(encoder.calls, isEmpty);
    expect((result as ShareReady).files.single.name, 'v1.mov');
  });

  testWidgets('a file that cannot be opened lists the video as failed', (
    tester,
  ) async {
    final v1 = _item('v1', adjustment: _warm);
    final encoder = _FakeEncoder([]);
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [v1],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      encoder: encoder,
      accessOpens: false,
    );
    expect((result as ShareReady).failedVideos, [v1]);
    expect(encoder.calls, isEmpty);
  });

  testWidgets('a path that fails to resolve lists the video as failed', (
    tester,
  ) async {
    final v1 = _item('v1', adjustment: _warm);
    final result = await withRef(
      tester,
      (ref) => prepareShareFiles(
        ref,
        [v1],
        onProgress: (_) {},
        cancel: ColorEncodeCancel(),
      ),
      encoder: _FakeEncoder([]),
      pathThrows: true,
    );
    expect((result as ShareReady).failedVideos, [v1]);
  });

  testWidgets('a cancel before anything starts prepares nothing', (
    tester,
  ) async {
    final encoder = _FakeEncoder([]);
    final result = await withRef(tester, (ref) {
      final cancel = ColorEncodeCancel()..cancel();
      return prepareShareFiles(
        ref,
        [_item('v1', adjustment: _warm)],
        onProgress: (_) {},
        cancel: cancel,
      );
    }, encoder: encoder);
    expect(result, isA<ShareCancelled>());
    expect(encoder.calls, isEmpty);
  });

  testWidgets('a resolve that throws later deletes written copies', (
    tester,
  ) async {
    final first = p.join(temp.path, 'share', 'v1', 'v1.mp4');
    Object? error;
    await withRef(
      tester,
      (ref) async {
        try {
          await prepareShareFiles(
            ref,
            [
              _item('v1', adjustment: _warm),
              _item('boom', type: MediaType.photo),
            ],
            onProgress: (_) {},
            cancel: ColorEncodeCancel(),
          );
        } on Object catch (e) {
          error = e;
        }
      },
      encoder: _FakeEncoder([_Outcome.ok]),
      throwsFor: 'boom',
    );
    expect(error, isA<StateError>());
    expect(await exists(tester, first), isFalse);
  });

  testWidgets('originalShareFiles writes the original bytes', (tester) async {
    final files = await withRef(
      tester,
      (ref) => originalShareFiles(ref, [_item('v1', adjustment: _warm)]),
    );
    expect(files.single.name, 'v1.mov');
  });
}
