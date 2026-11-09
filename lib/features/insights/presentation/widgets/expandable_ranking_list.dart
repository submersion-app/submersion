import 'package:flutter/material.dart';

import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/widgets/equipment/gear_report_row.dart';
import 'package:submersion/features/insights/presentation/widgets/ranking_list.dart';

/// A [RankingList] that shows its first [gearReportRowLimit] rows and opens
/// the rest in place behind "Show all" (issue #4385).
///
/// Give it the whole ranking: the button appears only when there is more
/// than fits, and its open state lasts while the card is on screen.
class ExpandableRankingList extends StatefulWidget {
  final List<RankingItem> items;
  final String countLabel;
  final bool showMedals;
  final void Function(RankingItem)? onItemTap;

  const ExpandableRankingList({
    super.key,
    required this.items,
    this.countLabel = 'dives',
    this.showMedals = true,
    this.onItemTap,
  });

  @override
  State<ExpandableRankingList> createState() => _ExpandableRankingListState();
}

class _ExpandableRankingListState extends State<ExpandableRankingList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RankingList(
          items: showAllSlice(widget.items, expanded: _expanded),
          countLabel: widget.countLabel,
          showMedals: widget.showMedals,
          onItemTap: widget.onItemTap,
        ),
        GearReportShowAll(
          itemCount: widget.items.length,
          expanded: _expanded,
          onChanged: (value) => setState(() => _expanded = value),
        ),
      ],
    );
  }
}
