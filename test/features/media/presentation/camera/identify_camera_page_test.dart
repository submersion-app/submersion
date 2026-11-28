import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/presentation/camera/identify_camera.dart';
import 'package:submersion/features/media/presentation/camera/identify_camera_page.dart';
import 'package:submersion/features/media/presentation/camera/live_label_overlay.dart';
import 'package:submersion/features/species_id/data/camera/camera_frame_jpeg.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/live_naming_controller.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../species_id/presentation/species_id_fakes.dart';

/// A service that names live, and counts the holds let go.
class _LiveService extends RecordingIdentificationService {
  int holds = 0;
  int releases = 0;

  @override
  Future<LiveNaming?> liveNaming() async {
    holds++;
    return (
      analyze: (Uint8List _) async =>
          const VisionAnalysis(imageWidth: 1, imageHeight: 1, detections: []),
      name: (List<VisionDetection> _) async => const <String?>[],
    );
  }

  @override
  void releaseLiveNaming() => releases++;
}

class _FakeCamera implements IdentifyCamera {
  _FakeCamera(this.dir, {this.denied = false, this.initFailure});

  final Directory dir;
  final bool denied;

  /// Thrown by [initialize] other than a refusal: a camera held by
  /// another app, say.
  final Object? initFailure;
  int _taken = 0;
  bool recording = false;

  /// Holds [takePhoto] until completed: a photo still being taken.
  Completer<void>? photoGate;

  String _file(String ext) {
    final path = p.join(dir.path, 'capture_${_taken++}.$ext');
    File(path).writeAsBytesSync([0xff, 0xd8, 0xff, 0xd9]);
    return path;
  }

  @override
  Future<void> initialize() async {
    if (denied) throw const IdentifyCameraDenied();
    if (initFailure case final failure?) throw failure;
  }

  @override
  Widget preview() => const ColoredBox(color: Colors.blueGrey);

  @override
  double get aspectRatio => 3 / 4;

  @override
  Future<String> takePhoto() async {
    await photoGate?.future;
    return _file('jpg');
  }

  @override
  Future<void> startRecording({
    void Function(CameraFrameData)? onFrame,
  }) async => recording = true;

  @override
  Future<String> stopRecording() async {
    recording = false;
    return _file('mp4');
  }

  @override
  Future<void> startFrames(void Function(CameraFrameData) onFrame) async {}

  @override
  Future<void> stopFrames() async {}

  @override
  Future<void> dispose() async {}
}

/// The Identify camera (issue #5122).
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('identify_camera_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  });

  Future<_FakeCamera> pump(
    WidgetTester tester, {
    bool denied = false,
    Object? initFailure,
    MediaIdentificationService? service,
  }) async {
    final camera = _FakeCamera(dir, denied: denied, initFailure: initFailure);
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identifyCameraFactoryProvider.overrideWithValue(() => camera),
          mediaIdentificationServiceProvider.overrideWithValue(
            service ?? RecordingIdentificationService(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: IdentifyCameraPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return camera;
  }

  final captures = find.byKey(const ValueKey('identify_camera_captures'));
  final shutter = find.byKey(const ValueKey('identify_camera_shutter'));

  /// How many captures the badge on the captures button shows.
  int captureCount(WidgetTester tester) {
    final badge = tester.widget<Badge>(
      find.ancestor(of: captures, matching: find.byType(Badge)),
    );
    if (!badge.isLabelVisible) return 0;
    return int.parse((badge.label! as Text).data!);
  }

  testWidgets('a photo joins the captures', (tester) async {
    await pump(tester);
    expect(captureCount(tester), 0);

    await tester.tap(shutter);
    await tester.pumpAndSettle();

    expect(captureCount(tester), 1);
  });

  testWidgets('a clip joins the captures once it stops', (tester) async {
    final camera = await pump(tester);
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    await tester.tap(shutter);
    await tester.pumpAndSettle();
    expect(camera.recording, isTrue);
    expect(captureCount(tester), 0);

    await tester.tap(shutter);
    await tester.pumpAndSettle();
    expect(camera.recording, isFalse);
    expect(captureCount(tester), 1);
  });

  testWidgets('says the location is not used', (tester) async {
    await pump(tester);

    expect(
      find.text('Suggestions only, from anywhere: your location is not used.'),
      findsOneWidget,
    );
  });

  testWidgets('a refused camera says so and still offers files', (
    tester,
  ) async {
    await pump(tester, denied: true);

    expect(find.textContaining("can't use the camera"), findsOneWidget);
    expect(
      find.byKey(const ValueKey('identify_camera_pick_files')),
      findsOneWidget,
    );
    expect(shutter, findsNothing);
  });

  testWidgets('a camera that fails to open offers files', (tester) async {
    await pump(tester, initFailure: StateError('camera in use'));

    expect(find.textContaining("can't use the camera"), findsOneWidget);
    expect(
      find.byKey(const ValueKey('identify_camera_pick_files')),
      findsOneWidget,
    );
  });

  testWidgets('a second shutter tap while a photo is taken is ignored', (
    tester,
  ) async {
    final camera = await pump(tester);
    camera.photoGate = Completer<void>();

    await tester.tap(shutter);
    await tester.pump();
    await tester.tap(shutter);
    await tester.pump();
    camera.photoGate!.complete();
    await tester.pumpAndSettle();

    expect(captureCount(tester), 1);
  });

  testWidgets('leaving lets go of the live naming hold', (tester) async {
    final service = _LiveService();
    await pump(tester, service: service);
    expect(service.holds, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(service.releases, 1);
  });

  testWidgets('labels name an animal as a suggestion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 300,
          height: 400,
          child: LiveLabelOverlay(
            labels: LiveLabels.boxes([
              LiveBox(
                box: IdentificationBox(x: 0.1, y: 0.1, width: 0.3, height: 0.2),
                name: 'Clownfish',
                track: 0,
              ),
              LiveBox(
                box: IdentificationBox(x: 0.5, y: 0.5, width: 0.2, height: 0.2),
                name: null,
                track: 1,
              ),
            ]),
          ),
        ),
      ),
    );

    expect(find.text('Clownfish?'), findsOneWidget);
    expect(find.byKey(const ValueKey('live_box_1')), findsOneWidget);
  });

  test('only Android keeps frames coming while recording', () {
    expect(recordingKeepsFrames(TargetPlatform.android), isTrue);
    expect(recordingKeepsFrames(TargetPlatform.iOS), isFalse);
  });
}
