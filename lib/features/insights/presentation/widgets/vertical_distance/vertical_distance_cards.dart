import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_scale_layout.dart';
import 'package:submersion/features/insights/presentation/providers/vertical_distance_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_card.dart';

/// Room for the cards (the page's content width, not the window's) from
/// which the two cards sit side by side; below it they stack.
/// Each card then has at least about 390 px, what its scale needs for the
/// labels, the bar and the headlines.
const double kVerticalCardsSideBySideMinWidth = 800;

/// Total Ascent & Descent and Max Depths Added Up on Insights > Profile
/// (issue #4569): side by side on a wide screen, stacked on a narrow one.
///
/// Both are drawn on one scale, sized for the larger of the two totals, so
/// their bars compare at a glance. Until both timelines have loaded, each
/// card keeps its own scale.
class VerticalDistanceCards extends ConsumerWidget {
  const VerticalDistanceCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(verticalDistanceTimelineProvider).value;
    final maxDepths = ref.watch(maxDepthTimelineProvider).value;
    final extent = profile == null || maxDepths == null
        ? null
        : math.max(
            verticalScaleExtent(profile.totalMeters),
            verticalScaleExtent(maxDepths.totalMeters),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            constraints.maxWidth >= kVerticalCardsSideBySideMinWidth;
        final first = VerticalDistanceCard(scaleExtentMeters: extent);
        // Beside the first card it keeps an empty note row, so the two
        // cards end level.
        final second = VerticalDistanceCard.maxDepths(
          scaleExtentMeters: extent,
          keepNoteRow: sideBySide,
        );
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 16), second],
        );
      },
    );
  }
}
