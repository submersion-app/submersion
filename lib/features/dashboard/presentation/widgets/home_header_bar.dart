import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_with_buddy_button.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_light_chip.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_status_lights.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/widgets/diver_switcher_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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
      type: HomeChipType.sync,
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

/// Home's slim header: the logo, the status lights (tablet and up), the
/// main actions, a More menu and, with more than one diver profile, the
/// diver switcher. Every control has at least a 44 by 44 hit area.
class HomeHeaderBar extends ConsumerWidget {
  const HomeHeaderBar({super.key});

  /// Height of the bar's content. Tall enough for 44-point hit areas.
  static const double barHeight = 48;

  static const Key switcherKey = ValueKey('home-header-switcher');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final phone = homeWidthTierOf(context) == HomeWidthTier.phone;
    final gaugesAsync = ref.watch(dashboardGaugesProvider);
    final lights = _watchLights(context, ref);

    Widget lightsRow() {
      if (gaugesAsync.hasError && lights == null) {
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: HomeLightChip(_retryLight(context, ref), dense: true),
        );
      }
      if (lights == null) return const SizedBox.shrink();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final light in lights)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: HomeLightChip(light, dense: true),
              ),
          ],
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        height: barHeight,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/icon/icon.png',
                width: 24,
                height: 24,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Submersion',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: phone ? const SizedBox() : lightsRow()),
            if (phone)
              IconButton(
                tooltip: l10n.dashboard_quickActions_logDive,
                onPressed: () => _logDive(context),
                style: _iconStyle,
                icon: const Icon(Icons.add),
              )
            else ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _logDive(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.dashboard_quickActions_logDive),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => context.push('/planning/dive-planner'),
                child: Text(l10n.dashboard_quickActions_planDive),
              ),
            ],
            _MoreMenu(includePlan: phone),
            _DiverSwitcher(showName: !phone),
          ],
        ),
      ),
    );
  }
}

/// Icon buttons in the bar reach the 44-point minimum hit area.
final ButtonStyle _iconStyle = IconButton.styleFrom(
  minimumSize: const Size.square(44),
);

enum _MoreAction { plan, swap, emergency }

class _MoreMenu extends ConsumerWidget {
  final bool includePlan;

  const _MoreMenu({required this.includePlan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // A browser has none of the radios the swap runs over (issue #4121).
    final swap = ref.watch(deviceCapabilitiesProvider).nearby;
    return PopupMenuButton<_MoreAction>(
      tooltip: l10n.dashboard_header_more,
      style: _iconStyle,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => switch (action) {
        _MoreAction.plan => context.push('/planning/dive-planner'),
        _MoreAction.swap => openBuddySwap(context),
        _MoreAction.emergency => context.push(
          '/settings/diver-profile/emergency-card',
        ),
      },
      itemBuilder: (context) => [
        if (includePlan)
          PopupMenuItem(
            value: _MoreAction.plan,
            child: Text(l10n.dashboard_quickActions_planDive),
          ),
        if (swap)
          PopupMenuItem(
            value: _MoreAction.swap,
            child: Text(l10n.buddySwap_title),
          ),
        PopupMenuItem(
          value: _MoreAction.emergency,
          child: Text(l10n.dashboard_quickAction_emergency),
        ),
      ],
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
        if (split.clear > 0 || split.attention.isEmpty)
          HomeLightChip(
            HomeStatusLight(
              type: HomeChipType.sync,
              icon: Icons.check_circle_outline,
              label: split.attention.isEmpty
                  ? l10n.dashboard_header_allClear
                  : l10n.dashboard_header_clearCount(split.clear),
              tone: HomeLightTone.ok,
              onTap: () => _showAllLights(context, lights),
            ),
            dense: true,
          ),
      ];
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in children)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: c,
              ),
          ],
        ),
      ),
    );
  }

  void _showAllLights(BuildContext context, List<HomeStatusLight> lights) {
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final l in lights) HomeLightChip(l)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
