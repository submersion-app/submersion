import 'dart:ui';

import 'package:submersion/features/connections/domain/entities/node_ref.dart';

class LabelCollision {
  const LabelCollision._();

  /// Keeps each label whose rect does not overlap an already-kept,
  /// higher-ranked label. [ranked] is in priority order.
  static Set<NodeRef> visible(List<({NodeRef ref, Rect rect})> ranked) {
    final kept = <Rect>[];
    final out = <NodeRef>{};
    for (final c in ranked) {
      final clashes = kept.any((k) => _strictlyOverlaps(k, c.rect));
      if (clashes) continue;
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
