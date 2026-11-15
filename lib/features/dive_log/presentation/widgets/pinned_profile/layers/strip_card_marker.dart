import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';

/// The dive details cards that add a layer to the pinned profile strip, as
/// they report themselves through [PinnedStripCardMarker] (issue #4562).
///
/// The pinned profile overlay owns one and measures the cards in it after
/// each layout, as it measures the profile card.
class PinnedStripCardRegistry {
  final Map<DiveDetailSectionId, BuildContext> _cards = {};

  /// Called when a card comes or goes, so the overlay measures again.
  VoidCallback? onChanged;

  void register(DiveDetailSectionId id, BuildContext context) {
    if (identical(_cards[id], context)) return;
    _cards[id] = context;
    onChanged?.call();
  }

  /// Forgets [id], but only if [context] is the one it holds: a card that
  /// moved (a pair stacking, say) registers its new place before the old
  /// one goes.
  void unregister(DiveDetailSectionId id, BuildContext context) {
    if (!identical(_cards[id], context)) return;
    _cards.remove(id);
    onChanged?.call();
  }

  /// Each card's rect in scroll-content coordinates: where it is on
  /// [overlay], shifted down by the scroll [pixels]. A card not laid out is
  /// left out.
  Map<DiveDetailSectionId, Rect> measure(RenderBox overlay, double pixels) => {
    for (final MapEntry(key: id, value: context) in _cards.entries)
      if (_boxOf(context) case final box?)
        id: (box.localToGlobal(Offset.zero, ancestor: overlay) & box.size)
            .shift(Offset(0, pixels)),
  };

  static RenderBox? _boxOf(BuildContext context) {
    if (!context.mounted) return null;
    final box = context.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }
}

/// Hands a [PinnedStripCardRegistry] down to the cards of the page it
/// wraps.
class PinnedStripCardScope extends InheritedWidget {
  const PinnedStripCardScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final PinnedStripCardRegistry registry;

  /// The registry above [context], without depending on it: the registry
  /// never changes, so nothing needs rebuilding for it.
  static PinnedStripCardRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PinnedStripCardScope>()?.registry;

  @override
  bool updateShouldNotify(PinnedStripCardScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Marks [child] as dive details card [id] for the pinned profile strip, so
/// the strip shows that card's layers while it is in view (issue #4562).
/// Outside a [PinnedStripCardScope] it does nothing.
class PinnedStripCardMarker extends StatefulWidget {
  const PinnedStripCardMarker({
    super.key,
    required this.id,
    required this.child,
  });

  final DiveDetailSectionId id;
  final Widget child;

  @override
  State<PinnedStripCardMarker> createState() => _PinnedStripCardMarkerState();
}

class _PinnedStripCardMarkerState extends State<PinnedStripCardMarker> {
  PinnedStripCardRegistry? _registry;
  DiveDetailSectionId? _id;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(PinnedStripCardMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _register();
  }

  void _register() {
    final registry = PinnedStripCardScope.maybeOf(context);
    if (identical(registry, _registry) && _id == widget.id) return;
    final oldId = _id;
    if (oldId != null) _registry?.unregister(oldId, context);
    _registry = registry;
    _id = widget.id;
    registry?.register(widget.id, context);
  }

  @override
  void dispose() {
    final id = _id;
    if (id != null) _registry?.unregister(id, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
