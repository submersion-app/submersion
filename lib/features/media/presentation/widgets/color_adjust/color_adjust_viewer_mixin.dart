import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/presentation/helpers/color_pick_white.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_layout.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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

  /// The photo's sitting, where the panel and Pick white hold their changes
  /// (issue #4527). Null while the photo is locked: nothing is changed.
  EditSession<PhotoRecord>? get colorSitting => null;

  /// Closes the panel and leaves Pick white: the photo was locked.
  void closeColorEditing() => setState(() {
    colorPanelOpen = false;
    pickingWhite = false;
  });

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
    // Captured first: a sitting that ends while the sample is read must not
    // turn it into a write.
    final held = colorSitting;
    final white = await sample();
    if (!mounted) return;
    // The viewers have the photo's lock: with no sitting (one that ended
    // meanwhile, or a device that cannot unlock) the colour stays as it is.
    if (held == null) return;
    await applyPickedWhite(context, ref, item, white, sitting: held);
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
      sitting: colorSitting,
      onDone: () => setState(() {
        colorPanelOpen = false;
        pickingWhite = false;
      }),
    ),
    child: child,
  );
}
