import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/domain/compare/compare_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/divergence_builder.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_legend.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_readout_panel.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shared body for both comparison entry points (the standalone dives page and
/// the Dive3dPage "Computers" mode). Renders N profiles as a compare scene
/// with a layout toggle, legend, synchronized scrub readout, and (in overlay)
/// a divergence surface for the focused profile. Self-contained: owns its own
/// scrub notifier and playback controller.
class CompareProfile3dView extends ConsumerStatefulWidget {
  final AsyncValue<List<ComparisonProfile>> profiles;
  final CompareLayout initialLayout;

  /// Optional control placed before the layout toggle (e.g. the Dive3dPage
  /// scene switcher when this view is embedded in the Computers mode).
  final Widget? leading;

  const CompareProfile3dView({
    super.key,
    required this.profiles,
    this.initialLayout = CompareLayout.sideBySide,
    this.leading,
  });

  @override
  ConsumerState<CompareProfile3dView> createState() =>
      _CompareProfile3dViewState();
}

class _CompareProfile3dViewState extends ConsumerState<CompareProfile3dView>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _position = ValueNotifier(0);
  late final AnimationController _player;
  late CompareLayout _layout;
  int _referenceIndex = 0;
  int? _focusedIndex;

  @override
  void initState() {
    super.initState();
    _layout = widget.initialLayout;
    _player = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..addListener(() => _position.value = _player.value);
  }

  @override
  void dispose() {
    _player.dispose();
    _position.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_player.isAnimating) {
        _player.stop();
      } else {
        if (_position.value >= 1.0) _player.value = 0;
        _player.forward(from: _position.value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.profiles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _empty(context),
      data: (all) {
        if (all.length < 2) return _empty(context);
        final shown = all.length > kMaxComparisonProfiles
            ? all.sublist(0, kMaxComparisonProfiles)
            : all;
        return _scene(context, shown, all.length);
      },
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        context.l10n.dive3d_compare_empty,
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _scene(
    BuildContext context,
    List<ComparisonProfile> profiles,
    int totalCount,
  ) {
    final refIndex = _referenceIndex.clamp(0, profiles.length - 1);
    final focused = (_focusedIndex != null && _focusedIndex! < profiles.length)
        ? _focusedIndex
        : null;
    final scene = const CompareGeometryService().build(
      profiles,
      layout: _layout,
      referenceIndex: refIndex,
      focusedIndex: focused,
    );
    final maxGaps = DivergenceBuilder.maxGaps(profiles, refIndex);
    final duration = scene.bounds.durationSeconds <= 0
        ? 1.0
        : scene.bounds.durationSeconds;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Dive3dInteractiveViewport(
                  scene: scene,
                  scrubPosition: _position,
                  visibleOverlays: const {SceneOverlay.markers},
                  scrubCursor: ScrubCursorStyle.timePlane,
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: _controls(context, profiles.length, totalCount),
              ),
              Positioned(
                top: 60,
                left: 8,
                child: CompareLegend(
                  profiles: profiles,
                  referenceIndex: refIndex,
                  focusedIndex: focused,
                  maxGaps: maxGaps,
                  onFocus: (i) => setState(
                    () => _focusedIndex = _focusedIndex == i ? null : i,
                  ),
                  onSetReference: (i) => setState(() => _referenceIndex = i),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: CompareReadoutPanel(
                  profiles: profiles,
                  referenceIndex: refIndex,
                  position: _position,
                  durationSeconds: duration,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: TimeScrubBar(
            position: _position,
            playing: _player.isAnimating,
            onPlayPause: _togglePlay,
            onScrubStart: () {
              if (_player.isAnimating) setState(() => _player.stop());
            },
          ),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context, int shownCount, int totalCount) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (widget.leading != null) widget.leading!,
        SegmentedButton<CompareLayout>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(
              value: CompareLayout.sideBySide,
              label: Text(context.l10n.dive3d_compare_layout_sideBySide),
            ),
            ButtonSegment(
              value: CompareLayout.overlay,
              label: Text(context.l10n.dive3d_compare_layout_overlay),
            ),
          ],
          selected: {_layout},
          onSelectionChanged: (s) => setState(() => _layout = s.first),
          showSelectedIcon: false,
        ),
        if (totalCount > shownCount)
          Chip(
            label: Text(
              context.l10n.dive3d_compare_showing(shownCount, totalCount),
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
