import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_header_bar.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_lights_scroller.dart';

/// The thin row under Home's welcome banner (issue #5003): the + quick
/// actions menu, then the status lights. The banner itself stays as it was,
/// so the controls the compact bar holds live here. From tablet width up
/// every light shows in one scrolling line; on a phone, the short form the
/// compact bar's strip uses. As tall as the compact bar, so every control
/// keeps a 44-point hit area.
class HomeBannerRow extends ConsumerWidget {
  const HomeBannerRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final phone = homeWidthTierOf(context) == HomeWidthTier.phone;
    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        height: HomeHeaderBar.barHeight,
        padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            const HomeQuickActionsMenu(),
            const SizedBox(width: 4),
            Expanded(
              child: phone
                  ? HomeLightsScroller(
                      children: homePhoneLightChips(context, ref),
                    )
                  : homeWideLights(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pins [HomeBannerRow] to the top of Home's scroll view once the banner
/// above it has scrolled away, so the + menu and the safety lights stay in
/// view in banner mode as they do under the compact bar.
class HomeBannerRowDelegate extends SliverPersistentHeaderDelegate {
  const HomeBannerRowDelegate();

  @override
  double get minExtent => HomeHeaderBar.barHeight;

  @override
  double get maxExtent => HomeHeaderBar.barHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => const HomeBannerRow();

  @override
  bool shouldRebuild(HomeBannerRowDelegate oldDelegate) => false;
}
