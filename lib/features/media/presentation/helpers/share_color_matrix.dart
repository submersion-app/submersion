import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/features/media/data/services/corrected_photo_encoder.dart';
import 'package:submersion/features/media/data/services/media_share_temp_file.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';

/// The colour correction a shared copy of [item] carries (issue #3520): the
/// same matrix the app draws it with, worked out from the full-resolution
/// [bytes]. Identity for videos and documents, which are shared as they are.
Future<ColorMatrix> shareColorMatrixFor(
  WidgetRef ref,
  MediaItem item,
  Uint8List bytes,
) async {
  if (item.mediaType != MediaType.photo) return ColorMatrix.identity;
  final adjustment =
      ref.read(colorAdjustmentDraftNotifierProvider(item.id)) ??
      item.colorAdjustment;
  final diverAuto =
      isAutoCorrectable(item) && ref.read(diverAutoColorCorrectionProvider);
  // A row shared from the library comes without its profile match; read it
  // so the shared copy gets the same depth and surface check as the tile.
  var placed = item;
  if (needsStoredMatch(
    item,
    adjustment: adjustment,
    diverAutoEnabled: diverAuto,
  )) {
    placed = item.copyWith(
      enrichment: await ref
          .read(mediaColorAdjustmentRepositoryProvider)
          .enrichmentFor(item.id),
    );
  }
  AutoCorrectionParams? auto;
  if (needsAutoStats(
    placed,
    adjustment: adjustment,
    diverAutoEnabled: diverAuto,
  )) {
    final stats = await ref
        .read(colorAnalysisServiceProvider)
        .statsFor(colorStatsKey(item), MemoryImage(bytes));
    auto = autoParamsForPhoto(placed, stats);
  }
  return composeCorrection(adjustment: adjustment, auto: auto);
}

/// Writes the share sheet's temp file for [item]: a corrected JPEG copy
/// when a correction is in effect, otherwise the original [bytes] exactly.
/// The original file and every cached copy are never touched.
Future<XFile> writeShareFileFor(
  WidgetRef ref,
  MediaItem item,
  Uint8List bytes,
) async {
  final matrix = await shareColorMatrixFor(ref, item, bytes);
  if (!matrix.isIdentity) {
    final corrected = await encodeCorrectedPhoto(
      bytes: bytes,
      matrix: matrix,
      filename: item.shareFilename,
      mime: item.shareMimeType,
    );
    if (corrected != null) {
      final file = await writeShareTempFile(
        item,
        corrected.bytes,
        filename: corrected.filename,
      );
      return XFile(file.path, mimeType: 'image/jpeg', name: corrected.filename);
    }
  }
  final file = await writeShareTempFile(item, bytes);
  return XFile(
    file.path,
    mimeType: item.shareMimeType,
    name: item.shareFilename,
  );
}
