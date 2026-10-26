import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Mean colour of the usable pixels of a small decode of a photo or video
/// frame, which is all the automatic correction needs. Channels are 0..1.
class ChannelStats extends Equatable {
  const ChannelStats({
    required this.meanR,
    required this.meanG,
    required this.meanB,
  });

  final double meanR;
  final double meanG;
  final double meanB;

  /// Pixels darker than this (Rec. 709 luma, 0..1) carry no colour signal.
  static const _minLuma = 0.04;

  /// Pixels with any channel above this are clipped highlights.
  static const _maxChannel = 0.98;

  /// Below this share of usable pixels the frame is black water, a blown-out
  /// strobe shot or a blank poster, and is not analysed.
  static const _minUsableShare = 0.05;

  /// Reads straight (unpremultiplied) RGBA bytes, sampling every [stride]th
  /// pixel. Null when too few pixels are usable.
  static ChannelStats? fromRgba(Uint8List rgba, {int stride = 1}) {
    final pixels = rgba.length ~/ 4;
    var sampled = 0;
    var used = 0;
    var sumR = 0.0, sumG = 0.0, sumB = 0.0;
    for (var p = 0; p < pixels; p += stride) {
      sampled++;
      final o = p * 4;
      final r = rgba[o] / 255, g = rgba[o + 1] / 255, b = rgba[o + 2] / 255;
      final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      if (luma < _minLuma) continue;
      if (r > _maxChannel || g > _maxChannel || b > _maxChannel) continue;
      used++;
      sumR += r;
      sumG += g;
      sumB += b;
    }
    if (used == 0 || used < sampled * _minUsableShare) return null;
    return ChannelStats(
      meanR: sumR / used,
      meanG: sumG / used,
      meanB: sumB / used,
    );
  }

  /// A strong blue or green cast with little red, bright enough to be lit
  /// water rather than a dark frame. Used only when there is no depth.
  bool get looksUnderwater {
    final cool = meanG > meanB ? meanG : meanB;
    return meanR < 0.6 * cool && cool > 0.15;
  }

  @override
  List<Object?> get props => [meanR, meanG, meanB];
}
