import 'dart:ui';

import 'package:submersion/features/connections/domain/entities/node_ref.dart';

class LabelCollision {
  const LabelCollision._();

  /// Keeps each label whose rect overlaps neither an already-kept,
  /// higher-ranked label nor any of [obstacles] (the node discs).
  static Set<NodeRef> visible(
    List<({NodeRef ref, Rect rect})> ranked, {
    List<Rect> obstacles = const [],
  }) {
    final kept = <Rect>[];
    final out = <NodeRef>{};
    for (final c in ranked) {
      if (obstacles.any((o) => _strictlyOverlaps(o, c.rect))) continue;
      if (kept.any((k) => _strictlyOverlaps(k, c.rect))) continue;
      kept.add(c.rect);
      out.add(c.ref);
    }
    return out;
  }

  static bool _strictlyOverlaps(Rect a, Rect b) =>
      a.left < b.right &&
      b.left < a.right &&
      a.top < b.bottom &&
      b.top < a.bottom;
}
