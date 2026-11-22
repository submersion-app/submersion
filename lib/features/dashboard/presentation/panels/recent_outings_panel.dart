import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_outings_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/dashboard/presentation/widgets/outing_card.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Home's Recent outings panel (issue #4898): a postcard per recent outing.
/// On a phone the cards page one at a time with dots under them; wider,
/// they sit side by side and the rest scroll sideways.
class RecentOutingsPanel extends ConsumerWidget {
  const RecentOutingsPanel({super.key});

  /// The narrowest a card is drawn beside others.
  static const double minCardWidth = 170;
  static const double gap = 8;

  /// How much of the next card shows when more outings follow.
  static const double peek = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final outings = ref.watch(homeRecentOutingsProvider);
    final list = outings.value;
    final summary = list == null || list.isEmpty
        ? null
        : l10n.dashboard_outings_summary(
            list.length,
            list.fold(0, (sum, o) => sum + o.outing.diveCount),
          );
    final phone = homeWidthTierOf(context) == HomeWidthTier.phone;

    void open(HomeOuting o) {
      final trip = o.outing.tripId;
      if (trip != null) {
        context.push('/trips/$trip');
      } else {
        openDiveList(context, ref, DiveFilterState(diveIds: o.outing.diveIds));
      }
    }

    return HomePanel(
      title: l10n.dashboard_panel_recentOutings,
      trailing: summary,
      semanticsValue: summary ?? '',
      onTap: () => context.push('/trips'),
      child: HomePanelAsync<List<HomeOuting>>(
        value: outings,
        isEmpty: (o) => o.isEmpty,
        emptyText: l10n.dashboard_outings_empty,
        builder: (shown) {
          // One depth scale across the cards, the deepest dive shown.
          final scale = shown
              .expand((o) => o.outing.depths)
              .fold(0.0, math.max);
          // Keyed by outing, so a card's state (its cover and map) follows
          // the outing when a new one arrives at the front of the list.
          Widget card(HomeOuting o) => OutingCard(
            key: ValueKey(o.outing.tripId ?? 'dives:${o.outing.diveIds.first}'),
            outing: o,
            skylineScaleMeters: scale,
            onTap: () => open(o),
          );
          // A mouse drags a horizontal list only when told to (as the
          // header's lights do), so the later cards stay reachable.
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: phone
                ? _OutingPager(
                    // A lone card fills the width; a new state gives it a
                    // controller with the other viewport fraction.
                    key: ValueKey(shown.length == 1),
                    outings: shown,
                    card: card,
                  )
                : _OutingRow(outings: shown, card: card),
          );
        },
      ),
    );
  }
}

class _OutingRow extends StatelessWidget {
  final List<HomeOuting> outings;
  final Widget Function(HomeOuting) card;

  const _OutingRow({required this.outings, required this.card});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = RecentOutingsPanel.gap;
      final fit = math.max(
        1,
        ((box.maxWidth + gap) / (RecentOutingsPanel.minCardWidth + gap))
            .floor(),
      );
      // With more outings than fit, the cards narrow so the next one peeks
      // in at the edge: a horizontal list draws no scrollbar, and a row of
      // whole cards would hide that there are more.
      final more = outings.length > fit;
      final width = more
          ? (box.maxWidth - gap * fit - RecentOutingsPanel.peek) / fit
          : (box.maxWidth - gap * (fit - 1)) / fit;
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: outings.length,
        separatorBuilder: (_, _) => const SizedBox(width: gap),
        itemBuilder: (_, i) => SizedBox(width: width, child: card(outings[i])),
      );
    },
  );
}

class _OutingPager extends StatefulWidget {
  final List<HomeOuting> outings;
  final Widget Function(HomeOuting) card;

  const _OutingPager({required this.outings, required this.card, super.key});

  @override
  State<_OutingPager> createState() => _OutingPagerState();
}

class _OutingPagerState extends State<_OutingPager> {
  late final _controller = PageController(
    viewportFraction: widget.outings.length == 1 ? 1 : 0.86,
  );
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = widget.outings.length;
    final page = math.min(_page, count - 1);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: count,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsetsDirectional.only(
                end: count == 1 ? 0 : RecentOutingsPanel.gap,
              ),
              child: widget.card(widget.outings[i]),
            ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Row(
              key: const Key('outing-page-dots'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: SizedBox(
                      width: i == page ? 16 : 6,
                      height: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: i == page
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
