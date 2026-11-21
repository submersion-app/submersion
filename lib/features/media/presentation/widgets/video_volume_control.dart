import 'package:flutter/material.dart';

import 'package:submersion/features/media/presentation/helpers/viewer_audio.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The video controls' sound: a mute button, and beside it a volume slider
/// while a mouse rests on the control, keyboard focus is inside it, or the
/// slider is being dragged (issue #4817).
///
/// A touch screen never hovers, so it gets the button alone: its hardware
/// buttons set the level, and a second slider would fight them.
class VideoVolumeControl extends StatefulWidget {
  final ViewerAudio audio;

  /// Whether the slider is in use (keyboard focus inside the control, or a
  /// drag under way), so a host that hides its controls on a timer can hold
  /// them meanwhile. Hover is the host's own to track.
  final ValueChanged<bool>? onHoldChanged;

  /// The mute button, for tests that tap or hover it.
  @visibleForTesting
  static const buttonKey = ValueKey('videoVolume.button');

  /// The volume slider, for tests that look for it or drag it.
  @visibleForTesting
  static const sliderKey = ValueKey('videoVolume.slider');

  /// How wide the slider is when shown.
  static const double sliderWidth = 96;

  const VideoVolumeControl({
    super.key,
    required this.audio,
    this.onHoldChanged,
  });

  @override
  State<VideoVolumeControl> createState() => _VideoVolumeControlState();
}

class _VideoVolumeControlState extends State<VideoVolumeControl> {
  bool _hovered = false;
  bool _focused = false;

  /// A drag on the slider, which may stray off the control: the slider stays
  /// until release rather than vanish from under the pointer.
  bool _dragging = false;

  void _setInUse({bool? focused, bool? dragging}) {
    final wasInUse = _focused || _dragging;
    setState(() {
      _focused = focused ?? _focused;
      _dragging = dragging ?? _dragging;
    });
    final inUse = _focused || _dragging;
    if (inUse != wasInUse) widget.onHoldChanged?.call(inUse);
  }

  IconData _icon(double volume) {
    if (volume == 0) return Icons.volume_off;
    return volume < 0.5 ? Icons.volume_down : Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // Tracks focus anywhere inside, so Tab from the button onto the slider
      // keeps the slider; takes none itself.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => _setInUse(focused: focused),
        child: ListenableBuilder(
          listenable: widget.audio,
          builder: (context, _) {
            final volume = widget.audio.effectiveVolume;
            final label = volume == 0
                ? l10n.media_photoViewer_unmuteVideoLabel
                : l10n.media_photoViewer_muteVideoLabel;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // One node, named for what a tap does; the tooltip is the
                // same words, so screen readers hear them once.
                MergeSemantics(
                  child: Semantics(
                    label: label,
                    child: Tooltip(
                      message: label,
                      excludeFromSemantics: true,
                      child: IconButton(
                        key: VideoVolumeControl.buttonKey,
                        onPressed: widget.audio.toggleMute,
                        // No taller than the bar it sits in, whose height
                        // the fullscreen fish labels keep clear: a touch
                        // screen's padded 48 px target would grow it.
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        iconSize: 20,
                        color: Colors.white,
                        icon: Icon(_icon(volume)),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  child: _hovered || _focused || _dragging
                      ? SizedBox(
                          width: VideoVolumeControl.sliderWidth,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withValues(
                                alpha: 0.3,
                              ),
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              // Sized to the scrub bar beside it: a 4 px
                              // track, a small thumb, and the track run up
                              // close to the button rather than inset by a
                              // full-size thumb's reach.
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              showValueIndicator: ShowValueIndicator.never,
                            ),
                            child: Slider(
                              key: VideoVolumeControl.sliderKey,
                              value: volume,
                              onChanged: widget.audio.setLevel,
                              onChangeStart: (_) => _setInUse(dragging: true),
                              onChangeEnd: (_) => _setInUse(dragging: false),
                              // The slider's own name for screen readers;
                              // the value bubble that would also show it is
                              // off in the theme above.
                              label: l10n.media_photoViewer_videoVolumeLabel,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
