import 'dart:math' as math;

/// Size and stroke rules shared by the painter, the hit tester and the
/// selection UI, so a node is drawn and picked at the same radius.
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
}
