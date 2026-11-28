import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/scratch/scratch_session.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/camera/identify_camera.dart';
import 'package:submersion/features/media/presentation/camera/live_label_overlay.dart';
import 'package:submersion/features/media/presentation/pages/identify_viewer_page.dart';
import 'package:submersion/features/species_id/data/camera/camera_frame_jpeg.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/services/live_naming_controller.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether the camera plugin sends image frames during a recording on
/// [platform]: only Android does (`startVideoRecording`'s `onAvailable`).
bool recordingKeepsFrames(TargetPlatform platform) =>
    platform == TargetPlatform.android;

/// The Identify camera (issue #5122): suggestions over the live picture,
/// and photos and clips that open in the Identify viewer. Phones and
/// tablets only.
class IdentifyCameraPage extends ConsumerStatefulWidget {
  const IdentifyCameraPage({super.key});

  @override
  ConsumerState<IdentifyCameraPage> createState() => _IdentifyCameraPageState();
}

enum _CameraState { opening, ready, denied }

class _IdentifyCameraPageState extends ConsumerState<IdentifyCameraPage> {
  late final IdentifyCamera _camera = ref.read(identifyCameraFactoryProvider)();
  _CameraState _state = _CameraState.opening;
  bool _video = false;
  bool _recording = false;
  bool _namesOn = true;
  bool _encoding = false;
  bool _startingNaming = false;
  List<MediaItem> _captures = const [];
  LiveNamingController? _naming;
  LiveLabels? _labels;

  @override
  void initState() {
    super.initState();
    // The preview, the frames and the boxes over them are laid out upright
    // for a portrait screen.
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      await _camera.initialize();
    } on IdentifyCameraDenied {
      if (mounted) setState(() => _state = _CameraState.denied);
      return;
    }
    if (!mounted) return;
    setState(() => _state = _CameraState.ready);
    await _startNaming();
  }

  /// Starts naming frames, when names are on and a model can run.
  Future<void> _startNaming() async {
    if (!_namesOn || _naming != null || _startingNaming) return;
    _startingNaming = true;
    final service = ref.read(mediaIdentificationServiceProvider);
    final LiveNaming? live;
    try {
      live = await service.liveNaming();
    } finally {
      _startingNaming = false;
    }
    // Turned off, or the page gone, while the models loaded.
    if (live == null || !mounted || !_namesOn) {
      if (live != null) service.releaseLiveNaming();
      return;
    }
    final engine = ref.read(visionEngineProvider);
    final naming = LiveNamingController(
      analyze: live.analyze,
      name: live.name,
      memory: engine.memory,
    );
    _naming = naming;
    naming.labels.listen((labels) {
      if (mounted && _naming == naming) setState(() => _labels = labels);
    });
    if (!_recording) await _camera.startFrames(_onFrame);
  }

  /// Hands a frame to the namer when it wants one; the rest are dropped
  /// before they are encoded.
  void _onFrame(CameraFrameData frame) {
    final naming = _naming;
    if (naming == null || _encoding || !naming.wantsFrame) return;
    _encoding = true;
    unawaited(
      compute(cameraFrameToJpeg, frame)
          .then((jpeg) => naming.offer(LiveFrame(jpeg)))
          .whenComplete(() => _encoding = false),
    );
  }

  Future<void> _stopNaming() async {
    final naming = _naming;
    if (naming == null) return;
    _naming = null;
    if (!_recording) await _camera.stopFrames();
    await naming.dispose();
    ref.read(mediaIdentificationServiceProvider).releaseLiveNaming();
    if (mounted) setState(() => _labels = null);
  }

  Future<void> _toggleNames(bool on) async {
    setState(() => _namesOn = on);
    on ? await _startNaming() : await _stopNaming();
  }

  MediaItem _capture(String path, MediaType type) {
    final now = DateTime.now();
    return MediaItem(
      id: ScratchSession.newId(),
      mediaType: type,
      sourceType: MediaSourceType.localFile,
      filePath: path,
      localPath: path,
      originalFilename: p.basename(path),
      takenAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _shutter() async {
    if (_video) {
      if (_recording) {
        final path = await _camera.stopRecording();
        setState(() {
          _recording = false;
          _captures = [..._captures, _capture(path, MediaType.video)];
        });
        if (_naming != null) await _camera.startFrames(_onFrame);
      } else {
        if (_naming != null) await _camera.stopFrames();
        // Frames keep coming through a recording for the names only where
        // the camera plugin sends them (Android): elsewhere the labels go
        // rather than freeze on the last frame before recording.
        final framesWhileRecording =
            _naming != null && recordingKeepsFrames(defaultTargetPlatform);
        await _camera.startRecording(
          onFrame: framesWhileRecording ? _onFrame : null,
        );
        setState(() {
          _recording = true;
          if (!framesWhileRecording) _labels = null;
        });
      }
      return;
    }
    // A camera that streams cannot always take a photo at the same time.
    if (_naming != null) await _camera.stopFrames();
    final path = await _camera.takePhoto();
    if (_naming != null) await _camera.startFrames(_onFrame);
    if (mounted) {
      setState(
        () => _captures = [..._captures, _capture(path, MediaType.photo)],
      );
    }
  }

  Future<void> _openCaptures() async {
    final kept = await openIdentifyViewer(
      context,
      _captures,
      captures: {for (final c in _captures) c.id},
    );
    if (kept.isEmpty || !mounted) return;
    // A kept capture is in the photo library now: its copy here goes, and
    // it is not offered again.
    for (final capture in _captures.where((c) => kept.contains(c.id))) {
      _deleteCapture(capture);
    }
    setState(
      () => _captures = [
        for (final c in _captures)
          if (!kept.contains(c.id)) c,
      ],
    );
  }

  void _deleteCapture(MediaItem capture) {
    final path = capture.localPath;
    if (path == null) return;
    unawaited(File(path).delete().then((_) {}, onError: (Object _) {}));
  }

  Future<void> _pickFiles() async {
    final items = await pickIdentifyItems(ref);
    if (mounted) await openIdentifyViewer(context, items);
  }

  @override
  void dispose() {
    final naming = _naming;
    if (naming != null) {
      unawaited(naming.dispose());
      ref.read(mediaIdentificationServiceProvider).releaseLiveNaming();
    }
    unawaited(_camera.dispose());
    // Captures not kept go with the camera; a kept one is in the photo
    // library by now.
    _captures.forEach(_deleteCapture);
    // Back to whatever the app allows.
    unawaited(SystemChrome.setPreferredOrientations(const []));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.media_identify_cameraTitle),
        actions: [
          if (_state == _CameraState.ready)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: const ValueKey('identify_camera_names'),
                label: Text(l10n.media_identify_namesOn),
                selected: _namesOn,
                onSelected: (on) => unawaited(_toggleNames(on)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_state) {
          _CameraState.opening => const Center(
            child: CircularProgressIndicator(),
          ),
          _CameraState.denied => _Denied(onPick: _pickFiles),
          _CameraState.ready => Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _camera.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _camera.preview(),
                        if (_namesOn && _labels != null)
                          LiveLabelOverlay(labels: _labels!),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _labels?.pause == LivePause.memory
                      ? l10n.media_identify_namesPaused
                      : l10n.media_identify_noLocation,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
              _Controls(
                video: _video,
                recording: _recording,
                captures: _captures,
                onMode: _recording ? null : (v) => setState(() => _video = v),
                onShutter: () => unawaited(_shutter()),
                onOpenCaptures: _captures.isEmpty
                    ? null
                    : () => unawaited(_openCaptures()),
                onPickFiles: () => unawaited(_pickFiles()),
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _Denied extends StatelessWidget {
  const _Denied({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.media_identify_cameraDenied,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('identify_camera_pick_files'),
              onPressed: onPick,
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.media_identify_pickFiles),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.video,
    required this.recording,
    required this.captures,
    required this.onMode,
    required this.onShutter,
    required this.onOpenCaptures,
    required this.onPickFiles,
  });

  final bool video;
  final bool recording;
  final List<MediaItem> captures;
  final ValueChanged<bool>? onMode;
  final VoidCallback onShutter;
  final VoidCallback? onOpenCaptures;
  final VoidCallback onPickFiles;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<bool>(
            key: const ValueKey('identify_camera_mode'),
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l10n.media_identify_photo),
              ),
              ButtonSegment(
                value: true,
                label: Text(l10n.media_identify_video),
              ),
            ],
            selected: {video},
            onSelectionChanged: onMode == null
                ? null
                : (s) => onMode!(s.single),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Badge.count(
                count: captures.length,
                isLabelVisible: captures.isNotEmpty,
                child: IconButton.filledTonal(
                  key: const ValueKey('identify_camera_captures'),
                  tooltip: l10n.media_identify_captures,
                  onPressed: onOpenCaptures,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
              ),
              IconButton.filled(
                key: const ValueKey('identify_camera_shutter'),
                iconSize: 40,
                tooltip: video
                    ? (recording
                          ? l10n.media_identify_stop
                          : l10n.media_identify_record)
                    : l10n.media_identify_takePhoto,
                onPressed: onShutter,
                icon: Icon(
                  video
                      ? (recording ? Icons.stop : Icons.fiber_manual_record)
                      : Icons.camera,
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('identify_camera_pick_files'),
                tooltip: l10n.media_identify_pickFiles,
                onPressed: onPickFiles,
                icon: const Icon(Icons.folder_open),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
