import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
  final peek = ref.read(colorPeekOriginalNotifierProvider.notifier);
  peek.peek(item.id);
  try {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
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
  } catch (e, stackTrace) {
    // A failed capture is "no colour there", not an uncaught tap error.
    _log.warning(
      'Reading a white point from photo ${item.id} failed',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  } finally {
    peek.release();
  }
}

/// Samples a white point under [tap] from a paused video's frame at
/// [position], drawn contain-fit in a box of [boxSize]. [playing] is the
/// file the player has open, read in preference to resolving the clip
/// again (which can mean another photo-library export or store fetch).
///
/// Null, never an error, for anything that stops the read: the diver is
/// told the spot had no colour to read.
Future<WhitePoint?> sampleWhiteFromVideo(
  WidgetRef ref,
  MediaItem item,
  Duration position,
  Offset tap,
  Size boxSize, {
  String? playing,
}) async {
  try {
    final engine = ref.read(transcodeEngineProvider);
    final path =
        playing ?? await ref.read(resolvedFilePathProvider(item).future);
    if (engine == null || path == null) return null;
    final frames = await extractFramesGated(
      engine,
      path: path,
      times: [position],
      maxDimension: 640,
      // The paused frame itself, not a nearby keyframe.
      exact: true,
      timeout: ref.read(videoFrameTimeoutProvider),
    );
    final jpeg = frames.isEmpty ? null : frames.first;
    if (jpeg == null) return null;
    // A 640 px software decode: off the UI isolate.
    return await compute(_whiteInFrame, (
      jpeg: jpeg,
      tap: tap,
      boxSize: boxSize,
    ));
  } catch (e, stackTrace) {
    _log.warning(
      'Reading a white point from video ${item.id} failed',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

WhitePoint? _whiteInFrame(({Uint8List jpeg, Offset tap, Size boxSize}) job) {
  final (:jpeg, :tap, :boxSize) = job;
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
    ByteData.sublistView(rgba),
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
  final draft = ref.read(
    colorAdjustmentDraftNotifierProvider(item.id).notifier,
  );
  final previousDraft = ref.read(colorAdjustmentDraftNotifierProvider(item.id));
  final current =
      previousDraft ?? item.colorAdjustment ?? const ColorAdjustment();
  final next = current.copyWith(whitePoint: sample);
  // Only a live draft (the panel still editing this item) is moved on. With
  // none, the saved row redraws the item; setting one here, after the
  // sampling wait, could outlive a panel that has since closed, and would
  // then hide every later change to the row.
  final drawsDraft = previousDraft != null;
  if (drawsDraft) draft.set(next);
  try {
    await ref
        .read(mediaColorAdjustmentRepositoryProvider)
        .setColorAdjustment(item.id, next);
  } catch (e, stackTrace) {
    _log.error('Saving a white point failed', error: e, stackTrace: stackTrace);
    // Not saved, so not drawn: the photo goes back to what is stored.
    if (drawsDraft) draft.set(previousDraft);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.media_color_saveFailed)),
    );
  }
}
