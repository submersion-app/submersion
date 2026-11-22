import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_with_buddy_button.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_light_chip.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_lights_scroller.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_status_lights_wrap.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_status_lights.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/widgets/diver_switcher_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/about_submersion.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The ordered status lights, or null while the gauges load or fail.
List<HomeStatusLight>? _watchLights(BuildContext context, WidgetRef ref) {
  final gauges = ref.watch(dashboardGaugesProvider).value;
  if (gauges == null) return null;
  final hidden = ref.watch(settingsProvider.select((s) => s.hiddenHomeChips));
  return orderLightsBySeverity(
    buildHomeStatusLights(context, ref, gauges, hidden),
  );
}

/// The light shown in place of the lights when the gauges fail to load:
/// tapping it loads them again.
HomeStatusLight _retryLight(BuildContext context, WidgetRef ref) =>
    HomeStatusLight(
      icon: Icons.refresh,
      label: context.l10n.dashboard_gauges_retry,
      tone: HomeLightTone.neutral,
      onTap: () => ref.invalidate(dashboardGaugesProvider),
    );

void _logDive(BuildContext context) => showAddDiveBottomSheet(
  context: context,
  // Push, not go: sub-pages stay poppable so Back returns to Home (#647).
  onLogManually: () => context.push('/dives/new'),
  onPlanDive: () =>
      context.push('/dives/new', extra: const DivePrefill(isPlanned: true)),
);

/// Home's slim header: a + button at the leading edge for the quick actions
/// (logging and planning a dive, the buddy swap and the emergency card), the
/// status lights after it (tablet and up) and a divider while there are
/// lights to part, the diver switcher with more than one diver profile, and
/// the logo (no wordmark) closing the bar, which opens About Submersion.
/// Every control has at least a 44 by 44 hit area.
class HomeHeaderBar extends ConsumerWidget {
  const HomeHeaderBar({super.key});

  /// Height of the bar's content. Tall enough for 44-point hit areas.
  static const double barHeight = 48;

  /// The app icon at the end of the bar, which opens About Submersion: the
  /// largest that leaves the bar a few points above and below it.
  static const double logoSize = 40;

  static const Key switcherKey = ValueKey('home-header-switcher');

  static const Key quickActionsKey = ValueKey('home-header-quick-actions');

  static const Key dividerKey = ValueKey('home-header-divider');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final phone = homeWidthTierOf(context) == HomeWidthTier.phone;
    final gaugesAsync = ref.watch(dashboardGaugesProvider);
    final lights = _watchLights(context, ref);
    final retry = gaugesAsync.hasError && lights == null;
    // The divider parts lights from the diver, so it shows only with a light
    // (or the retry pill) in the row.
    final divided = !phone && (retry || (lights?.isNotEmpty ?? false));

    Widget lightsRow() {
      if (retry) {
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: HomeLightChip(_retryLight(context, ref), dense: true),
        );
      }
      if (lights == null) return const SizedBox.shrink();
      return HomeLightsScroller(
        children: [
          for (final light in lights) HomeLightChip(light, dense: true),
        ],
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        height: barHeight,
        // The + button's own 44-point target spaces it from the edge.
        padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            // The quick actions open from the bar's leading edge (the right
            // in a right-to-left language).
            const _QuickActionsMenu(),
            const SizedBox(width: 4),
            // The lights take the room up to the switcher. On a phone they
            // sit in the strip below instead.
            Expanded(child: phone ? const SizedBox() : lightsRow()),
            // A rule with space each side parts the lights from the diver
            // and the logo, so the last pill never runs into the switcher
            // (issue #4920).
            if (divided)
              Padding(
                key: dividerKey,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            // The diver's name shows above phone width: with the actions in
            // the + menu there is room for it, capped and ellipsized.
            _DiverSwitcher(showName: !phone),
            // The logo closes the bar and opens About Submersion.
            const SizedBox(width: 4),
            const _AboutLogo(),
          ],
        ),
      ),
    );
  }
}

enum _QuickAction { logDive, planDive, swap, emergency }

/// The + button, which opens every quick action: logging and planning a
/// dive first, then the buddy swap (where the device has the radios for it)
/// and the emergency card.
class _QuickActionsMenu extends ConsumerWidget {
  const _QuickActionsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // A browser has none of the radios the swap runs over (issue #4121).
    final swap = ref.watch(deviceCapabilitiesProvider).nearby;
    PopupMenuItem<_QuickAction> item(
      _QuickAction value,
      IconData icon,
      String label,
    ) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Flexible(child: Text(label)),
        ],
      ),
    );
    return PopupMenuButton<_QuickAction>(
      key: HomeHeaderBar.quickActionsKey,
      tooltip: l10n.dashboard_header_quickActions,
      icon: const Icon(Icons.add),
      style: IconButton.styleFrom(minimumSize: const Size.square(44)),
      position: PopupMenuPosition.under,
      onSelected: (action) => switch (action) {
        _QuickAction.logDive => _logDive(context),
        _QuickAction.planDive => context.push('/planning/dive-planner'),
        _QuickAction.swap => openBuddySwap(context),
        _QuickAction.emergency => context.push(
          '/settings/diver-profile/emergency-card',
        ),
      },
      itemBuilder: (context) => [
        item(
          _QuickAction.logDive,
          Icons.add,
          l10n.dashboard_quickActions_logDive,
        ),
        item(
          _QuickAction.planDive,
          Icons.route_outlined,
          l10n.dashboard_quickActions_planDive,
        ),
        const PopupMenuDivider(),
        if (swap)
          item(_QuickAction.swap, Icons.swap_horiz, l10n.buddySwap_title),
        item(
          _QuickAction.emergency,
          Icons.medical_information_outlined,
          l10n.dashboard_quickAction_emergency,
        ),
      ],
    );
  }
}

/// The app icon closing the bar: opens About Submersion, as Settings' About
/// section does. Its tap target is 44 points square around the icon.
class _AboutLogo extends StatelessWidget {
  const _AboutLogo();

  @override
  Widget build(BuildContext context) {
    // An icon button, as the + is: one node that a screen reader names by
    // the tooltip and can tap.
    return IconButton(
      tooltip: context.l10n.settings_about_aboutSubmersion,
      onPressed: () => showAboutSubmersion(context),
      padding: EdgeInsets.zero,
      iconSize: HomeHeaderBar.logoSize,
      style: IconButton.styleFrom(minimumSize: const Size.square(44)),
      icon: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/icon/icon.png',
          width: HomeHeaderBar.logoSize,
          height: HomeHeaderBar.logoSize,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

/// The active diver as a small avatar pill that opens the switcher. Absent
/// with a single profile: there is nothing to switch to.
class _DiverSwitcher extends ConsumerWidget {
  final bool showName;

  const _DiverSwitcher({required this.showName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Unknown (still loading) counts as one: most divers have one profile,
    // and the bar must not jump.
    final count = ref.watch(diverCountProvider).value ?? 1;
    if (count < 2) return const SizedBox.shrink();
    // `value`, not the valueOrNull polyfill: a switch reloads the diver, and
    // `value` keeps the previous one until the next has loaded.
    final Diver? diver = ref.watch(dashboardDiverProvider).value;
    if (diver == null) return const SizedBox(width: 44, height: 44);
    final theme = Theme.of(context);
    final label = context.l10n.settings_profileHub_switchDiver;
    return Tooltip(
      message: label,
      child: InkWell(
        key: HomeHeaderBar.switcherKey,
        onTap: () => showDiverSwitcherSheet(context),
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: Container(
              padding: EdgeInsetsDirectional.only(
                start: 2,
                end: showName ? 10 : 2,
                top: 2,
                bottom: 2,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfileAvatar(
                    photo: diver.photo,
                    initials: diver.initials,
                    radius: 12,
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (showName) ...[
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        diver.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// On a phone, the line under the header: every amber or red light by name,
/// then one pill counting the quiet ones, which opens them all. Renders
/// nothing at tablet width and up, where the lights sit in the bar.
class HomeStatusStrip extends ConsumerWidget {
  const HomeStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (homeWidthTierOf(context) != HomeWidthTier.phone) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final gaugesAsync = ref.watch(dashboardGaugesProvider);
    final lights = _watchLights(context, ref);
    final List<Widget> children;
    if (lights == null) {
      children = [
        if (gaugesAsync.hasError)
          HomeLightChip(_retryLight(context, ref), dense: true),
      ];
    } else {
      final split = splitForPhone(lights);
      children = [
        for (final light in split.attention) HomeLightChip(light, dense: true),
        // Nothing to vouch for when every light is hidden.
        if (lights.isNotEmpty && (split.clear > 0 || split.attention.isEmpty))
          HomeLightChip(
            HomeStatusLight(
              icon: Icons.check_circle_outline,
              label: split.attention.isEmpty
                  ? l10n.dashboard_header_allClear
                  : l10n.dashboard_header_clearCount(split.clear),
              tone: HomeLightTone.ok,
              onTap: () => _showAllLights(context),
            ),
            dense: true,
          ),
      ];
    }
    // Loading, or every light hidden: no empty bordered bar under the header.
    if (children.isEmpty) return const SizedBox.shrink();
    // No vertical padding: each pill's 44-point tap target already spaces
    // the strip.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: HomeLightsScroller(children: children),
    );
  }

  void _showAllLights(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.dashboard_header_statusTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const HomeStatusLightsWrap(),
            ],
          ),
        ),
      ),
    );
  }
}
