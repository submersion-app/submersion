import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/white_point_sampler.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(WhitePoint);

/// Samples a white point under [tap] from the photo drawn inside
/// [boundaryKey]'s RepaintBoundary, with [item]'s correction switched off
/// for that one frame so the sample is the uncorrected colour.
Future<WhitePoint?> sampleWhiteFromPhoto(
  WidgetRef ref,
  GlobalKey boundaryKey,
  MediaItem item,
  Offset tap,
) async {
  final peek = ref.read(colorPeekOriginalProvider.notifier);
  peek.peek(item.id);
  try {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return null;
      return averageWhiteAround(data, image.width, image.height, tap);
    } finally {
      image.dispose();
    }
  } finally {
    peek.release();
  }
}

/// Samples a white point under [tap] from a paused video's frame at
/// [position], drawn contain-fit in a box of [boxSize].
Future<WhitePoint?> sampleWhiteFromVideo(
  WidgetRef ref,
  MediaItem item,
  Duration position,
  Offset tap,
  Size boxSize,
) async {
  final engine = ref.read(transcodeEngineProvider);
  final path = await ref.read(resolvedFilePathProvider(item).future);
  if (engine == null || path == null) return null;
  final frames = await engine.extractFrames(
    source: File(path),
    times: [position],
    maxDimension: 640,
  );
  final jpeg = frames.isEmpty ? null : frames.first;
  if (jpeg == null) return null;
  final decoded = img.decodeImage(jpeg);
  if (decoded == null) return null;
  final at = tapToFramePixel(
    tap,
    boxSize: boxSize,
    frameSize: Size(decoded.width.toDouble(), decoded.height.toDouble()),
  );
  if (at == null) return null;
  final rgba = decoded
      .convert(numChannels: 4)
      .getBytes(order: img.ChannelOrder.rgba);
  return averageWhiteAround(
    ByteData.sublistView(Uint8List.fromList(rgba)),
    decoded.width,
    decoded.height,
    at,
  );
}

/// Saves [sample] as [item]'s white point, or tells the diver the spot had
/// no colour to read.
Future<void> applyPickedWhite(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
  WhitePoint? sample,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  if (sample == null) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.media_color_pickWhiteFailed)),
    );
    return;
  }
  final current = effectiveAdjustment(ref, item) ?? const ColorAdjustment();
  final next = current.copyWith(whitePoint: sample);
  ref.read(colorAdjustmentDraftProvider(item.id).notifier).set(next);
  try {
    await ref
        .read(mediaColorAdjustmentRepositoryProvider)
        .setColorAdjustment(item.id, next);
  } catch (e, stackTrace) {
    _log.error('Saving a white point failed', error: e, stackTrace: stackTrace);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.media_color_saveFailed)),
    );
  }
}
