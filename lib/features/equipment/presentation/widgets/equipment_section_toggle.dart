import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
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
  const EquipmentSectionToggle({
    super.key,
    required this.controller,
    this.tabHeight = defaultTabHeight,
  });

  final TabController controller;

  /// Height of each [Tab], not counting the [indicatorWeight] the [TabBar]
  /// pads under it; taller only where the names need it, see
  /// [fittedTabHeight]. The pill keeps its size whatever this is.
  final double tabHeight;

  /// A text [Tab]'s own height, kept wherever the header grows to fit.
  static const double defaultTabHeight = 46;

  /// The tab height that leaves a subtitle line room in a standard 56px
  /// toolbar: [heightFor] gives 40, and the entry count under it takes 16.
  /// The phone app bar uses it, where the toolbar clips rather than grows
  /// (issue #2776).
  static const double compactTabHeight = 38;

  /// [TabBar]'s default, set here because it pads the bottom of every tab
  /// even with a custom [TabBar.indicator], so it counts toward the height.
  static const double indicatorWeight = 2;

  /// The selected section's pill: [defaultTabHeight] and [indicatorWeight]
  /// less the 7px inset it has always had above and below.
  static const double pillHeight = 34;

  /// The switcher's laid-out height with tabs of [tabHeight].
  static double heightFor(double tabHeight) => tabHeight + indicatorWeight;

  /// Horizontal padding either side of each name, inside its pill.
  static const double labelPadding = 8;

  /// The icon and gap [FeatureAppBarTitle] puts in front of a title when the
  /// section-headers accent is on.
  static const double _accentLead = 24 + 8;

  /// How far in from the switcher's leading edge the first name's text
  /// starts: its pill's padding, and the accent icon and gap ahead of it
  /// when the icon shows. A line under the switcher, such as the entry
  /// count, indents by this to start under the text the way every other
  /// list's does, rather than under the pill's edge.
  static double textInset({required bool withAccentIcon}) =>
      labelPadding + (withAccentIcon ? _accentLead : 0);

  /// Whether [FeatureAppBarTitle] puts the accent icon ahead of the names.
  static bool showsAccentIcon(BuildContext context, WidgetRef ref) =>
      resolveFeatureAccent(
        context,
        ref,
        surface: AccentSurface.header,
        featureId: 'equipment',
      ) !=
      null;

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
    final labels = _names(context).fold(
      0.0,
      (width, name) =>
          width + _measure(context, name, style).width + 2 * labelPadding,
    );
    return labels + (withAccentIcon ? _accentLead : 0);
  }

  /// [minHeight], or the names' own line height in [style] where a large
  /// text size makes that taller.
  ///
  /// A [Tab] boxes its label at the tab's height and fades what overflows,
  /// so a tab that did not grow with the text would fade the bottom of the
  /// names away. [textScaler] defaults to the context's; a host measuring
  /// from outside a scale clamp, such as an app bar's, passes the clamped
  /// one.
  static double fittedTabHeight(
    BuildContext context,
    TextStyle style, {
    required double minHeight,
    TextScaler? textScaler,
  }) => _names(context).fold(
    minHeight,
    (height, name) => math.max(
      height,
      _measure(context, name, style, textScaler: textScaler).height,
    ),
  );

  static List<String> _names(BuildContext context) => [
    context.l10n.equipment_tab_equipment,
    context.l10n.equipment_tab_sets,
  ];

  /// [text] laid out on one line in [style], at [textScaler] or else the
  /// context's text scale.
  static Size _measure(
    BuildContext context,
    String text,
    TextStyle style, {
    TextScaler? textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: textScaler ?? MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final colors = EquipmentSectionColors.of(Theme.of(context).colorScheme);
    final style = DefaultTextStyle.of(context).style;
    final height = fittedTabHeight(context, style, minHeight: tabHeight);
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
        indicatorWeight: indicatorWeight,
        // Centred in whatever height the tabs have, so a compact switcher
        // trims the space around the pill rather than the pill itself.
        indicatorPadding: EdgeInsets.symmetric(
          vertical: math.max(0, (heightFor(height) - pillHeight) / 2),
        ),
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
          Tab(text: context.l10n.equipment_tab_equipment, height: height),
          Tab(text: context.l10n.equipment_tab_sets, height: height),
        ],
      ),
    );
  }
}
