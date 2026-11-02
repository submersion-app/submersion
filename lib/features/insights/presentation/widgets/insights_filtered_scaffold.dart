import 'package:flutter/material.dart';

import 'package:submersion/features/insights/presentation/widgets/insights_filter_action.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_bar.dart';

/// An Insights page on its own, as on a phone: the filter's bar and button
/// around [body], so a page the filter narrows always says so (#3479).
class InsightsFilteredScaffold extends StatelessWidget {
  const InsightsFilteredScaffold({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;

  /// Scrolls, so it takes the height the bar leaves.
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [InsightsFilterAction()],
      ),
      // Expanded is required: a Column would otherwise hand a scrolling body
      // unbounded height.
      body: Column(
        children: [
          const InsightsFilterBar(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
