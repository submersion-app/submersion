import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/services/color_analysis_service.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/share_color_matrix.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';

final _blue = Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: 8, height: 8)..clear(img.ColorRgb8(20, 100, 160)),
  ),
);
final _blueRgba = Uint8List.fromList([
  for (var i = 0; i < 64; i++) ...[20, 100, 160, 255],
]);

MediaItem item({
  MediaType type = MediaType.photo,
  ColorAdjustment? adjustment,
  String filename = 'reef.jpg',
  bool lean = false,
}) => MediaItem(
  id: 'm1',
  diveId: 'd1',
  mediaType: type,
  sourceType: MediaSourceType.platformGallery,
  originalFilename: filename,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  colorAdjustment: adjustment,
  enrichment: lean
      ? null
      : MediaEnrichment(
          id: 'e1',
          mediaId: 'm1',
          diveId: 'd1',
          depthMeters: 18,
          elapsedSeconds: 600,
          matchConfidence: MatchConfidence.interpolated,
          createdAt: DateTime.utc(2026),
        ),
);

/// Issue #3520: a shared photo carries its correction; a video does not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('share_color_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'getTemporaryDirectory' ? temp.path : null,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await temp.delete(recursive: true);
  });

  /// Reads a file for real: plain file IO in a testWidgets body deadlocks
  /// the fake-async zone.
  Future<Uint8List> read(WidgetTester tester, String path) async =>
      (await tester.runAsync(() => File(path).readAsBytes()))!;

  /// Runs [body] with a live WidgetRef over a scope with [diverAuto].
  Future<T> withRef<T>(
    WidgetTester tester,
    Future<T> Function(WidgetRef ref) body, {
    bool diverAuto = false,
    MediaEnrichment? stored,
  }) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diverAutoColorCorrectionProvider.overrideWithValue(diverAuto),
          mediaColorAdjustmentRepositoryProvider.overrideWithValue(
            _StoredEnrichment(stored),
          ),
          colorAnalysisServiceProvider.overrideWithValue(
            ColorAnalysisService(decodeRgba: (_) async => _blueRgba),
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

  testWidgets('a video is never corrected', (tester) async {
    final m = await withRef(
      tester,
      (ref) => shareColorMatrixFor(
        ref,
        item(
          type: MediaType.video,
          adjustment: const ColorAdjustment(warmth: 1),
        ),
        _blue,
      ),
    );
    expect(m.isIdentity, isTrue);
  });

  testWidgets('a hand adjustment is applied', (tester) async {
    const a = ColorAdjustment(warmth: 0.5);
    final m = await withRef(
      tester,
      (ref) => shareColorMatrixFor(ref, item(adjustment: a), _blue),
    );
    expect(m, composeCorrection(adjustment: a));
  });

  testWidgets('the automatic fix is applied when it is on', (tester) async {
    final m = await withRef(
      tester,
      (ref) => shareColorMatrixFor(ref, item(), _blue),
      diverAuto: true,
    );
    expect(
      m,
      computeAutoCorrection(
        ChannelStats.fromRgba(_blueRgba)!,
        depthMeters: 18,
      ).toMatrix(),
    );
  });

  testWidgets('a lean library row uses its stored match (surface shot)', (
    tester,
  ) async {
    final m = await withRef(
      tester,
      (ref) => shareColorMatrixFor(ref, item(lean: true), _blue),
      diverAuto: true,
      stored: MediaEnrichment(
        id: 'e1',
        mediaId: 'm1',
        diveId: 'd1',
        depthMeters: 0.3,
        elapsedSeconds: 3700,
        matchConfidence: MatchConfidence.estimated,
        timestampOffsetSeconds: 400,
        createdAt: DateTime.utc(2026),
      ),
    );
    expect(m.isIdentity, isTrue);
  });

  testWidgets('an adjusted photo is shared as a corrected JPEG', (
    tester,
  ) async {
    final file = await withRef(
      tester,
      (ref) => writeShareFileFor(
        ref,
        item(adjustment: const ColorAdjustment(warmth: 1)),
        _blue,
      ),
    );
    expect(file.name, 'reef.jpg');
    expect(file.mimeType, 'image/jpeg');
    expect(await read(tester, file.path), isNot(_blue));
  });

  testWidgets('an unadjusted photo is shared byte for byte', (tester) async {
    final file = await withRef(
      tester,
      (ref) => writeShareFileFor(ref, item(), _blue),
    );
    expect(await read(tester, file.path), _blue);
  });

  testWidgets('a video is shared byte for byte', (tester) async {
    final bytes = Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112]);
    final file = await withRef(
      tester,
      (ref) => writeShareFileFor(
        ref,
        item(
          type: MediaType.video,
          filename: 'dive.mp4',
          adjustment: const ColorAdjustment(warmth: 1),
        ),
        bytes,
      ),
    );
    expect(await read(tester, file.path), bytes);
    expect(file.name, 'dive.mp4');
  });

  testWidgets('a photo the encoder cannot read is shared as it is', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final file = await withRef(
      tester,
      (ref) => writeShareFileFor(
        ref,
        item(adjustment: const ColorAdjustment(warmth: 1)),
        bytes,
      ),
    );
    expect(await read(tester, file.path), bytes);
  });
}

/// Answers the stored-match lookup with [stored]; nothing else is used.
class _StoredEnrichment implements MediaColorAdjustmentRepository {
  _StoredEnrichment(this.stored);

  final MediaEnrichment? stored;

  @override
  Future<MediaEnrichment?> enrichmentFor(String mediaId) async => stored;

  @override
  Stream<void> watchEnrichmentChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
