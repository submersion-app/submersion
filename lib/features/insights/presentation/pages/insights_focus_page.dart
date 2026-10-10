import 'package:flutter/material.dart';

import 'package:submersion/features/insights/presentation/widgets/focus/focus_results.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_selector.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_action.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Pick a group of dives by one metric, see them, and see what they share
/// (issue #1611).
class InsightsFocusPage extends StatelessWidget {
  const InsightsFocusPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Slivers rather than a SingleChildScrollView, so the dive list builds
    // only the rows on screen however many dives the group holds (#3013).
    const content = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: FocusSelector()),
              SliverToBoxAdapter(child: SizedBox(height: 16)),
              FocusResults(),
            ],
          ),
        ),
      ],
    );
    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.insights_focus_title),
        actions: const [InsightsFilterAction()],
      ),
      // Expanded is required: content is a CustomScrollView, and a
      // Column would otherwise hand it unbounded height.
      body: const Column(
        children: [
          InsightsFilterBar(),
          Expanded(child: content),
        ],
      ),
    );
  }
}
