import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/app_bar_tab_metrics.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// A choice between sections, rendered as the header's own title.
///
/// The section names sit where the title would. The one showing is underlined
/// in the selected colour and the others are dimmer, the same look and
/// colours as the Media section's tabs (issue #3465). That keeps the header
/// titled like every other list pane
/// while letting the title switch sections, where a separate control beside it
/// cost width the header does not have (issue #2256). Equipment | Sets and
/// Certifications | Courses (issue #3437) both use it.
///
/// It is a [TabBar] styled as plain text rather than a row of tappable
/// labels, which is what gives it tab semantics for screen readers, arrow-key
/// navigation and the pointer cursor on hover. It is driven by the page's
/// [TabController], so a phone layout keeps its swipe gesture in step.
///
/// It is scrollable for layout, not for overflow: a fixed [TabBar] stretches
/// its tabs into equal slots across the whole width, which would strand the
/// second name mid-header instead of beside the first. Scrollable with
/// [TabAlignment.start] gives each name its natural width, packed from the
/// start like a title. (A [Tab] fades a long label rather than overflowing
/// either way.)
///
/// The text takes its size and weight from the surrounding [DefaultTextStyle]:
/// an app bar's title style on phone, the pane header's on desktop.
class SectionTitleToggle extends StatelessWidget {
  const SectionTitleToggle({
    super.key,
    required this.controller,
    required this.featureId,
    required this.labels,
    this.tabHeight = defaultTabHeight,
    this.onAppBar = false,
    this.tabBarKey,
  });

  final TabController controller;

  /// The feature whose accent icon leads the names when section headers are
  /// accented.
  final String featureId;

  /// The section names, in tab order.
  final List<String> labels;

  /// Height of each [Tab], not counting the [indicatorWeight] the [TabBar]
  /// pads under it; taller only where the names need it, see
  /// [fittedTabHeight].
  final double tabHeight;

  /// Whether the switch sits on an [AppBar], whose colour some themes set
  /// apart from the page's (Tropical). The colours are judged against the
  /// bar there, and against the scheme's surface in a desktop pane header.
  final bool onAppBar;

  /// Key for the [TabBar] itself, for finding it in tests.
  final Key? tabBarKey;

  /// A text [Tab]'s own height, kept wherever the header grows to fit.
  static const double defaultTabHeight = 46;

  /// The tab height that leaves a subtitle line room in a standard 56px
  /// toolbar: [heightFor] gives 36, [subtitleGap] takes 4 and the entry
  /// count under it 16. The phone app bar uses it, where the toolbar clips
  /// rather than grows (issue #2776).
  static const double compactTabHeight = 34;

  /// Space between the underline and a line under the switcher, such as the
  /// entry count, which otherwise sits flush against the underline
  /// (issue #3663).
  static const double subtitleGap = 4;

  /// [TabBar]'s default, set here because it pads the bottom of every tab,
  /// so it counts toward the height.
  static const double indicatorWeight = 2;

  /// The text scale [AppBar] caps its title at (its private
  /// `_kMaxTitleTextScaleFactor`), which a switch in a toolbar and the count
  /// under it both sit in.
  static const double appBarTitleMaxTextScale = 1.34;

  /// The names' style in a standard toolbar: 18px, a step under the usual
  /// 22px app bar title, which leaves the count line room under the switch.
  static TextStyle toolbarTitleStyle(BuildContext context) =>
      (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontSize: 18,
      );

  /// The switcher's laid-out height with tabs of [tabHeight].
  static double heightFor(double tabHeight) => tabHeight + indicatorWeight;

  /// Horizontal padding either side of each name, inside its tab.
  static const double labelPadding = 8;

  /// The icon and gap [FeatureAppBarTitle] puts in front of a title when the
  /// section-headers accent is on.
  static const double _accentLead = 24 + 8;

  /// How far in from the switcher's leading edge the first name's text
  /// starts: its tab's padding, and the accent icon and gap ahead of it
  /// when the icon shows. A line under the switcher, such as the entry
  /// count, indents by this to start under the text the way every other
  /// list's does, rather than under the tab's edge.
  static double textInset({required bool withAccentIcon}) =>
      labelPadding + (withAccentIcon ? _accentLead : 0);

  /// Whether [FeatureAppBarTitle] puts the accent icon ahead of the names.
  static bool showsAccentIcon(
    BuildContext context,
    WidgetRef ref, {
    required String featureId,
  }) =>
      resolveFeatureAccent(
        context,
        ref,
        surface: AccentSurface.header,
        featureId: featureId,
      ) !=
      null;

  /// The width the switcher needs to show all [labels] in full in [style].
  ///
  /// Lets a host decide whether the switcher and its actions fit on one row
  /// before anything is laid out. Deciding wrongly would not overflow: a
  /// scrollable [TabBar] that is too narrow scrolls a name out of sight.
  static double naturalWidth(
    BuildContext context,
    TextStyle style, {
    required List<String> labels,
    required bool withAccentIcon,
  }) {
    final names = labels.fold(
      0.0,
      (width, name) =>
          width + _measure(context, name, style).width + 2 * labelPadding,
    );
    return names + (withAccentIcon ? _accentLead : 0);
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
    required List<String> labels,
    required double minHeight,
    TextScaler? textScaler,
  }) => labels.fold(
    minHeight,
    (height, name) => math.max(
      height,
      _measure(context, name, style, textScaler: textScaler).height,
    ),
  );

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
    final theme = Theme.of(context);
    final colors = onAppBar
        ? AppBarTabColors.of(theme)
        : AppBarTabColors.on(
            theme,
            background: theme.colorScheme.surface,
            foreground: theme.colorScheme.onSurface,
          );
    final style = DefaultTextStyle.of(context).style;
    final height = fittedTabHeight(
      context,
      style,
      labels: labels,
      minHeight: tabHeight,
    );

    return FeatureAppBarTitle.custom(
      featureId: featureId,
      child: TabBar(
        key: tabBarKey,
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        // Symmetric, so the underline and the hover highlight are both
        // centred on the name. Padding on one side only put the highlight
        // visibly off to that side.
        labelPadding: const EdgeInsets.symmetric(horizontal: labelPadding),
        indicatorWeight: indicatorWeight,
        indicatorColor: colors.selected,
        overlayColor: colors.overlay,
        dividerHeight: 0,
        labelStyle: style,
        unselectedLabelStyle: style,
        labelColor: colors.selected,
        unselectedLabelColor: colors.unselected,
        tabs: [for (final name in labels) Tab(text: name, height: height)],
      ),
    );
  }
}
