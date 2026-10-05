import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';
import 'package:submersion/features/connections/presentation/canvas/node_metrics.dart';
import 'package:submersion/features/connections/presentation/canvas/node_photo_decoder.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_caption.dart';

const _log = LoggerService('ConnectionsShare');

/// Paints the whole map, offscreen, into a portrait PNG for sharing: the
/// current layout on a fixed deep-water background in every theme, with a
/// caption and the app mark. No selection, zoom or pan. Nothing is uploaded.
abstract final class ConnectionsShareRenderer {
  static const Size logicalSize = Size(360, 450);
  static const double pixelRatio = 3;
  static const Color background = Color(0xFF0F1E37);
  static const Color ink = Color(0xFFE6EDF7);
  static const double _captionHeight = 60;

  /// [render] after decoding the graph's buddy photos and the app icon. Any
  /// that fail to load are left out (initials, no icon), never an error.
  static Future<Uint8List> renderWithAssets({
    required ConnectionGraph graph,
    required LayoutFrame frame,
    required HighlightMode highlight,
    required GraphGroups groups,
    required ConnectionsShareCaption caption,
    String appIconAsset = 'assets/icon/icon.png',
  }) async {
    final photos = <NodeRef, ui.Image>{};
    ui.Image? icon;
    try {
      for (final n in graph.nodes) {
        final bytes = n.photo;
        if (bytes == null) continue;
        try {
          photos[n.ref] = await decodeNodePhoto(bytes);
        } catch (e) {
          _log.warning('Skipping a buddy photo that did not decode', error: e);
        }
      }
      try {
        final data = await rootBundle.load(appIconAsset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 60,
        );
        try {
          icon = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } catch (e) {
        _log.warning('Share image without the app icon', error: e);
      }
      return await render(
        graph: graph,
        frame: frame,
        highlight: highlight,
        groups: groups,
        caption: caption,
        photos: photos,
        appIcon: icon,
      );
    } finally {
      for (final img in photos.values) {
        img.dispose();
      }
      icon?.dispose();
    }
  }

  static Future<Uint8List> render({
    required ConnectionGraph graph,
    required LayoutFrame frame,
    required HighlightMode highlight,
    required GraphGroups groups,
    required ConnectionsShareCaption caption,
    Map<NodeRef, ui.Image> photos = const {},
    ui.Image? appIcon,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    const size = logicalSize;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final mapSize = Size(size.width, size.height - _captionHeight);
    const r = NodeMetrics.maxRadius;
    final viewport = const GraphViewport().fittedWithOverhang(
      frame.bounds,
      mapSize,
      left: 50,
      top: r,
      right: 50,
      bottom: r + 16,
      margin: 12,
    );
    const palette = FeatureAccentColors.dark;
    canvas.save();
    canvas.clipRect(Offset.zero & mapSize);
    ConnectionsPainter(
      graph: graph,
      frame: frame,
      viewport: viewport,
      colors: ConnectionKindColors.fromPalette(
        palette,
        palette.of('connections') ?? ink,
      ),
      labelStyle: const TextStyle(fontSize: 9, color: ink),
      photos: photos,
      labelZoomThreshold: 0,
      haloColor: background,
      highlight: highlight,
      groupOf: groups.groupOf,
    ).paint(canvas, mapSize);
    canvas.restore();

    _paintCaption(canvas, size, caption, appIcon);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  static void _paintCaption(
    Canvas canvas,
    Size size,
    ConnectionsShareCaption caption,
    ui.Image? icon,
  ) {
    final top = size.height - _captionHeight + 10;
    const markWidth = 110.0;
    final textWidth = size.width - 32 - markWidth;
    TextPainter text(String s, TextStyle style) => TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: textWidth);
    final title = text(
      caption.title,
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
    );
    final details = text(
      caption.details,
      TextStyle(fontSize: 10, color: ink.withValues(alpha: 0.75)),
    );
    title.paint(canvas, Offset(16, top));
    details.paint(canvas, Offset(16, top + title.height + 2));

    final name = TextPainter(
      text: const TextSpan(
        text: 'Submersion',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ink),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final nameLeft = size.width - 16 - name.width;
    final markTop = top + 6;
    name.paint(canvas, Offset(nameLeft, markTop + (20 - name.height) / 2));
    if (icon != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(nameLeft - 24, markTop, 20, 20),
        image: icon,
        fit: BoxFit.contain,
      );
    }
    for (final tp in [title, details, name]) {
      tp.dispose();
    }
  }
}
