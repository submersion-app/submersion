import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// The Equipment / Sets choice, rendered as the header's own title.
///
/// The two section names sit where the title would. The one showing sits in a
/// pill, the same shape and colour the sidebar gives the active page, and the
/// other is dimmer. That keeps the header titled like every other list pane
/// while letting the title switch sections, where a separate control beside it
/// cost width the header does not have (issue #2256).
///
/// It is a [TabBar] styled as plain text rather than a pair of tappable
/// labels, which is what gives it tab semantics for screen readers, arrow-key
/// navigation and the pointer cursor on hover. It is driven by the page's
/// [TabController], so the phone layout keeps its swipe gesture in step.
///
/// It is scrollable for layout, not for overflow: a fixed [TabBar] stretches
/// its tabs into equal slots across the whole width, which would strand "Sets"
/// mid-header instead of beside "Equipment". Scrollable with
/// [TabAlignment.start] gives each name its natural width, packed from the
/// start like a title. (A [Tab] fades a long label rather than overflowing
/// either way.)
///
/// The text takes its size and weight from the surrounding [DefaultTextStyle]:
/// an app bar's title style on phone, the pane header's on desktop.
class EquipmentSectionToggle extends StatelessWidget {
  const EquipmentSectionToggle({super.key, required this.controller});

  final TabController controller;

  /// Horizontal padding either side of each name, inside its pill.
  static const double labelPadding = 8;

  /// The icon and gap [FeatureAppBarTitle] puts in front of a title when the
  /// section-headers accent is on.
  static const double _accentLead = 24 + 8;

  /// The width the switcher needs to show both names in full in [style].
  ///
  /// Lets a host decide whether the switcher and its actions fit on one row
  /// before anything is laid out. Deciding wrongly would not overflow: a
  /// scrollable [TabBar] that is too narrow scrolls a name out of sight.
  static double naturalWidth(
    BuildContext context,
    TextStyle style, {
    required bool withAccentIcon,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final names = [
      context.l10n.equipment_tab_equipment,
      context.l10n.equipment_tab_sets,
    ];
    final labels = names.fold(
      0.0,
      (width, name) => width + measure(name) + 2 * labelPadding,
    );
    return labels + (withAccentIcon ? _accentLead : 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = EquipmentSectionColors.of(Theme.of(context).colorScheme);
    final style = DefaultTextStyle.of(context).style;
    const pillRadius = BorderRadius.all(Radius.circular(16));

    return FeatureAppBarTitle.custom(
      featureId: 'equipment',
      child: TabBar(
        key: const ValueKey('equipment_section_toggle'),
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        // Symmetric, so the pill and the hover highlight are both centred on
        // the name. Padding on one side only put the highlight visibly off to
        // that side.
        labelPadding: const EdgeInsets.symmetric(horizontal: labelPadding),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(vertical: 7),
        indicator: BoxDecoration(color: colors.pill, borderRadius: pillRadius),
        // Hover and focus take the pill's shape, so a highlight reads as a
        // preview of selection rather than a stray rectangle.
        splashBorderRadius: pillRadius,
        dividerHeight: 0,
        labelStyle: style,
        unselectedLabelStyle: style,
        labelColor: colors.selected,
        unselectedLabelColor: colors.unselected,
        tabs: [
          Tab(text: context.l10n.equipment_tab_equipment),
          Tab(text: context.l10n.equipment_tab_sets),
        ],
      ),
    );
  }
}
