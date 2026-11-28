import 'package:flutter/material.dart';

import 'package:submersion/features/species_id/domain/services/live_naming_controller.dart';

/// Boxes, and a suggestion's name where there is one, over the Identify
/// camera's picture (issue #5122). [labels] are normalised to the upright
/// frame, which the preview shows edge to edge.
class LiveLabelOverlay extends StatelessWidget {
  const LiveLabelOverlay({super.key, required this.labels});

  final LiveLabels labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            for (final live in labels.boxes)
              Positioned(
                key: ValueKey('live_box_${live.track}'),
                left: live.box.x * w,
                top: live.box.y * h,
                width: live.box.width * w,
                height: live.box.height * h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: live.name == null
                      ? null
                      : Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            color: scheme.primaryContainer,
                            child: Text(
                              // A suggestion, not a confident name.
                              '${live.name}?',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}
