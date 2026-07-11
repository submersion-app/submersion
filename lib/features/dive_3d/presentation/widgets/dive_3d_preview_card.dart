import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/application/providers.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Static software-rendered 3D preview of the dive on the detail page.
/// No GL: repaints only when geometry changes. Tapping opens the
/// fullscreen interactive page.
class Dive3dPreviewCard extends ConsumerWidget {
  final String diveId;

  const Dive3dPreviewCard({super.key, required this.diveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geometry = ref.watch(
      dive3dGeometryProvider((diveId: diveId, metric: SceneMetric.depth)),
    );
    final value = geometry.value;
    if (value == null) return const SizedBox.shrink();
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => Dive3dPage(diveId: diveId)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.dive3d_previewTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  const Icon(Icons.open_in_full, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CustomPaint(
                  painter: Dive3dPreviewPainter(geometry: value),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.dive3d_previewHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
