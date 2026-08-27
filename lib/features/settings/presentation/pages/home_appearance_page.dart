import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Appearance settings for the Home tab: which cards appear (and in what
/// order), and which status chips appear in the gauge strip.
///
/// The whole page is ONE CustomScrollView with the card list as a
/// SliverReorderableList: a shrink-wrapped ReorderableListView nested in a
/// ListView would disable auto-scroll-while-dragging.
///
/// When [embedded] is true, omits the Scaffold/AppBar for embedding in the
/// desktop settings detail pane.
class HomeAppearancePage extends ConsumerWidget {
  final bool embedded;

  const HomeAppearancePage({this.embedded = false, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(settingsProvider.select((s) => s.hiddenHomeChips));
    final homeCardOrder = ref.watch(
      settingsProvider.select((s) => s.homeCardOrder),
    );
    final hiddenHomeCards = ref.watch(
      settingsProvider.select((s) => s.hiddenHomeCards),
    );
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final cards = reconcileHomeCardOrder(homeCardOrder);

    String chipName(HomeChipType type) => switch (type) {
      HomeChipType.gear => l10n.settings_homeChips_gear,
      HomeChipType.insurance => l10n.settings_homeChips_insurance,
      HomeChipType.noFly => l10n.settings_homeChips_noFly,
      HomeChipType.lastDive => l10n.settings_homeChips_lastDive,
      HomeChipType.certifications => l10n.settings_homeChips_certifications,
      HomeChipType.trip => l10n.settings_homeChips_trip,
      HomeChipType.checklist => l10n.settings_homeChips_checklist,
      HomeChipType.course => l10n.settings_homeChips_course,
      HomeChipType.uploads => l10n.settings_homeChips_uploads,
      HomeChipType.backup => l10n.settings_homeChips_backup,
      HomeChipType.sync => l10n.settings_homeChips_sync,
      HomeChipType.dataQuality => l10n.settings_homeChips_dataQuality,
      HomeChipType.flightWindow => l10n.settings_homeChips_flightWindow,
    };

    Widget sectionHeader(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    Widget sectionDescription(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    final content = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: sectionHeader(l10n.settings_homeCards_sectionTitle),
        ),
        SliverToBoxAdapter(
          child: sectionDescription(l10n.settings_homeCards_description),
        ),
        SliverReorderableList(
          itemCount: cards.length,
          proxyDecorator: (child, index, animation) =>
              Material(elevation: 4, child: child),
          // onReorderItem pre-adjusts newIndex for the removed item, so no
          // manual decrement is needed (unlike the deprecated onReorder).
          onReorderItem: (oldIndex, newIndex) {
            final updated = List.of(cards);
            final moved = updated.removeAt(oldIndex);
            updated.insert(newIndex, moved);
            notifier.setHomeCardOrder([for (final c in updated) c.name]);
          },
          itemBuilder: (context, index) {
            final card = cards[index];
            final visible = !hiddenHomeCards.contains(card.name);
            return _CardTile(
              key: Key('homeCardTile_${card.name}'),
              card: card,
              index: index,
              visible: visible,
              onToggle: (enabled) =>
                  notifier.setHomeCardEnabled(card.name, enabled),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                key: const Key('homeCardsReset'),
                icon: const Icon(Icons.restore),
                label: Text(l10n.settings_homeCards_resetToDefault),
                onPressed: () => _confirmReset(context, notifier),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 24)),
        SliverToBoxAdapter(
          child: sectionHeader(l10n.settings_homeChips_sectionTitle),
        ),
        SliverToBoxAdapter(
          child: sectionDescription(l10n.settings_homeChips_description),
        ),
        SliverList.list(
          children: [
            for (final type in HomeChipType.values)
              SwitchListTile(
                key: Key('homeChipToggle_${type.name}'),
                title: Text(chipName(type)),
                value: !hidden.contains(type.name),
                onChanged: (enabled) =>
                    notifier.setHomeChipEnabled(type.name, enabled),
              ),
          ],
        ),
      ],
    );

    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_homeChips_pageTitle)),
      body: content,
    );
  }
}

/// One reorderable row in the Cards section: drag handle, localized card
/// name, auto-hide hint for conditional cards, and a visibility switch.
class _CardTile extends StatelessWidget {
  const _CardTile({
    super.key,
    required this.card,
    required this.index,
    required this.visible,
    required this.onToggle,
  });

  final HomeCardType card;
  final int index;
  final bool visible;
  final ValueChanged<bool> onToggle;

  /// Conditional cards auto-hide on the dashboard when they have no
  /// content; the subtitle explains why a toggled-on card may not appear.
  static const Set<HomeCardType> _autoHiding = {
    HomeCardType.milestones,
    HomeCardType.photoRibbon,
    HomeCardType.onThisDay,
    HomeCardType.yearInReview,
    HomeCardType.activeCourses,
    HomeCardType.recentSitesMap,
  };

  static String _cardName(
    AppLocalizations l10n,
    HomeCardType card,
  ) => switch (card) {
    HomeCardType.hero => l10n.settings_homeCards_card_hero,
    HomeCardType.gaugeStrip => l10n.settings_homeCards_card_gaugeStrip,
    HomeCardType.preDive => l10n.settings_homeCards_card_preDive,
    HomeCardType.recentDives => l10n.settings_homeCards_card_recentDives,
    HomeCardType.quickActions => l10n.settings_homeCards_card_quickActions,
    HomeCardType.milestones => l10n.settings_homeCards_card_milestones,
    HomeCardType.photoRibbon => l10n.settings_homeCards_card_photoRibbon,
    HomeCardType.onThisDay => l10n.settings_homeCards_card_onThisDay,
    HomeCardType.yearInReview => l10n.settings_homeCards_card_yearInReview,
    HomeCardType.activeCourses => l10n.settings_homeCards_card_activeCourses,
    HomeCardType.recentSitesMap => l10n.settings_homeCards_card_recentSitesMap,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: visible ? 1.0 : 0.5,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(_cardName(l10n, card)),
        subtitle: _autoHiding.contains(card)
            ? Text(l10n.settings_homeCards_autoHides)
            : null,
        trailing: Switch(
          key: Key('homeCardToggle_${card.name}'),
          value: visible,
          onChanged: onToggle,
        ),
      ),
    );
  }
}

Future<void> _confirmReset(
  BuildContext context,
  SettingsNotifier notifier,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settings_homeCards_resetDialog_title),
      content: Text(l10n.settings_homeCards_resetDialog_message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.settings_homeCards_resetDialog_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settings_homeCards_resetDialog_confirm),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await notifier.resetHomeCards();
  }
}
