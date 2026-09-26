import 'dart:math' as math;
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// Size and stroke rules shared by the painter, the hit tester and the
/// selection UI, so a node is drawn and picked at the same radius.
/// What a node disc shows inside it.
enum NodeGlyph { none, initials, icon, photo }

class NodeMetrics {
  const NodeMetrics._();

  static const double minRadius = 7;
  static const double maxRadius = 26;

  static double radiusFor(int diveCount, int maxDiveCount) {
    if (maxDiveCount <= 0) return maxRadius;
    final t = math.sqrt((diveCount / maxDiveCount).clamp(0.0, 1.0));
    return minRadius + (maxRadius - minRadius) * t;
  }

  static double edgeWidthFor(int weight, int maxWeight) {
    if (maxWeight <= 0) return 1;
    return 1 + 5 * (weight / maxWeight).clamp(0.0, 1.0);
  }

  static double edgeOpacityFor(int weight, int maxWeight) {
    if (maxWeight <= 0) return 0.5;
    return 0.25 + 0.55 * (weight / maxWeight).clamp(0.0, 1.0);
  }

  /// First letter of up to two words, upper-cased.
  static String initialsFor(String label) {
    final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  /// What to draw inside a node disc of [radius] screen pixels.
  static NodeGlyph glyphFor({
    required ConnectionKind kind,
    required bool hasPhoto,
    required double radius,
  }) {
    if (hasPhoto && radius >= 14) return NodeGlyph.photo;
    if (kind != ConnectionKind.buddy && radius >= 18) return NodeGlyph.icon;
    if (radius >= 12) return NodeGlyph.initials;
    return NodeGlyph.none;
  }
}
