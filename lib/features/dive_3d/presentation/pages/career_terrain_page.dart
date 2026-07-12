import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/application/career_providers.dart';
import 'package:submersion/features/dive_3d/domain/career/career_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fullscreen career "terrain": the diver's dives at a site or in a date
/// range, stacked along Z as parallel depth ribbons. A static explorable
/// object - orbit/zoom, no timeline.
class CareerTerrainPage extends ConsumerStatefulWidget {
  final CareerQuery query;
  final String? title;

  const CareerTerrainPage({super.key, required this.query, this.title});

  @override
  ConsumerState<CareerTerrainPage> createState() => _CareerTerrainPageState();
}

class _CareerTerrainPageState extends ConsumerState<CareerTerrainPage> {
  final ValueNotifier<double> _idle = ValueNotifier(0);
  CareerColorMode _colorMode = CareerColorMode.recency;

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sceneAsync = ref.watch(
      careerGeometryProvider((query: widget.query, colorMode: _colorMode)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? context.l10n.dive3d_career_title),
      ),
      body: sceneAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(context.l10n.dive3d_career_empty)),
        data: (scene) {
          if (scene == null || scene.layers.isEmpty) {
            return Center(child: Text(context.l10n.dive3d_career_empty));
          }
          return Stack(
            children: [
              Positioned.fill(
                child: Dive3dInteractiveViewport(
                  scene: scene,
                  scrubPosition: _idle,
                  visibleOverlays: const {SceneOverlay.markers},
                ),
              ),
              Positioned(top: 8, left: 8, right: 8, child: _colorControl()),
            ],
          );
        },
      ),
    );
  }

  Widget _colorControl() => Align(
    alignment: Alignment.topLeft,
    child: SegmentedButton<CareerColorMode>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(
          value: CareerColorMode.recency,
          label: Text(context.l10n.dive3d_career_colorRecency),
        ),
        ButtonSegment(
          value: CareerColorMode.depth,
          label: Text(context.l10n.dive3d_career_colorDepth),
        ),
      ],
      selected: {_colorMode},
      onSelectionChanged: (s) => setState(() => _colorMode = s.first),
      showSelectedIcon: false,
    ),
  );
}
