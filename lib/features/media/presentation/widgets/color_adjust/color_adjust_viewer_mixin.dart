import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/presentation/helpers/color_pick_white.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_layout.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart';

/// The Adjust color wiring a media viewer shares (issue #3520): whether the
/// panel is open, the "Pick white" mode, the boundary around the gallery a
/// photo's white point is read from, and the panel's layout beside it.
///
/// Both the dive viewer and the site viewer mix this in, so a change to how
/// the panel opens, closes or picks a white point is made once.
mixin ColorAdjustViewerMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Whether the Adjust color panel is open.
  bool colorPanelOpen = false;

  /// Whether "Pick white" is waiting for a tap.
  bool pickingWhite = false;

  /// Wraps the gallery so "Pick white" can read the photo's pixels.
  final GlobalKey galleryBoundaryKey = GlobalKey();

  void openColorPanel() => setState(() => colorPanelOpen = true);

  /// Enters "Pick white", or cancels it when it is already waiting.
  void togglePickWhite() => setState(() => pickingWhite = !pickingWhite);

  /// "Pick white" answered by a tap at [at] on a photo: its pixels, read
  /// with its correction off for a frame, become its white point.
  Future<void> pickWhiteOnPhoto(MediaItem item, Offset at) => pickWhiteWith(
    item,
    () => sampleWhiteFromPhoto(ref, galleryBoundaryKey, item, at),
  );

  /// Leaves "Pick white", reads a sample with [sample] and saves it.
  Future<void> pickWhiteWith(
    MediaItem item,
    Future<WhitePoint?> Function() sample,
  ) async {
    setState(() => pickingWhite = false);
    final white = await sample();
    if (!mounted) return;
    await applyPickedWhite(context, ref, item, white);
  }

  /// [child] (the viewer) with the panel for [item] beside it while open,
  /// and never in fullscreen.
  Widget colorAdjustLayout({
    required MediaItem item,
    required bool fullscreen,
    required bool pickWhiteAvailable,
    required VoidCallback onPickWhite,
    required Widget child,
  }) => ColorAdjustLayout(
    open: colorPanelOpen && !fullscreen,
    panelBuilder: (layout) => ColorAdjustPanel(
      item: item,
      layout: layout,
      pickWhiteAvailable: pickWhiteAvailable,
      onPickWhite: onPickWhite,
      onDone: () => setState(() {
        colorPanelOpen = false;
        pickingWhite = false;
      }),
    ),
    child: child,
  );
}
