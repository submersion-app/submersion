import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/pane_header_bar.dart';

import '../../../helpers/plain_header_title.dart';

const _contentKey = Key('content');

/// Phone widths, where the tabs are the app bar's bottom, and master-detail
/// widths, where they sit in a pane bar.
const _phoneWidth = 360.0;
const _desktopWidth = 1100.0;

void main() {
  Widget host({
    required MediaConsoleSection selected,
    required ValueChanged<MediaConsoleSection> onSelect,
    ValueChanged<MediaConsoleAction>? onAction,
    Map<MediaConsoleSection, int> badgeCounts = const {},
    ThemeData? theme,
    double appBarHeight = kToolbarHeight,
    PreferredSizeWidget Function(PreferredSizeWidget bar)? appBarPin,
    bool browser = false,
  }) {
    // The scaffold reads the header title's inset through a provider ref.
    return ProviderScope(
      overrides: [
        if (browser)
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaConsoleScaffold(
          headerTitle: plainHeaderTitle(
            'Media',
            appBarHeight: appBarHeight,
            // A switch's own label padding.
            titleTextInset: 8,
            appBarPin: appBarPin,
          ),
          selected: selected,
          onSelect: onSelect,
          onAction: onAction ?? (_) {},
          badgeCounts: badgeCounts,
          child: const SizedBox.expand(key: _contentKey),
        ),
      ),
    );
  }

  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  AppBar appBar(WidgetTester tester) =>
      tester.widget<AppBar>(find.byType(AppBar));

  /// Below master-detail width the tab row is the app bar's bottom.
  void expectTabsInAppBar(WidgetTester tester) {
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(TabBar)),
      findsOneWidget,
    );
  }

  Finder action(MediaConsoleAction a) =>
      find.byKey(ValueKey('media_console_action_${a.name}'));

  test('the console has exactly two tabs', () {
    // Only places to browse are tabs (#4587): Import, Transfers and Sources
    // are actions, so they are buttons on the tab row instead. Gear photos
    // have their own tab (issue #3355).
    expect(MediaConsoleSection.values, [
      MediaConsoleSection.library,
      MediaConsoleSection.gear,
    ]);
  });

  group('layout', () {
    // The tabs never share the title's row, at any width (#3631): beside the
    // Photos/Videos and Documents switch they read as one strip of six.
    for (final width in [_phoneWidth, 800.0, 1000.0]) {
      testWidgets('below master-detail width $width: the tabs are the app '
          "bar's bottom, under the title", (tester) async {
        setWidth(tester, width);
        await tester.pumpWidget(
          host(selected: MediaConsoleSection.library, onSelect: (_) {}),
        );

        expect(find.byType(TabBar), findsOneWidget);
        expectTabsInAppBar(tester);
        expect(find.byType(PaneHeaderBar), findsNothing);
        // With the switch's own 8px label padding, the switch's first name
        // lands on the 16px line a tab label starts on unpadded.
        expect(appBar(tester).titleSpacing, 8);
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).padding,
          const EdgeInsetsDirectional.only(start: 0),
        );
        expect(
          tester.getTopLeft(find.text('Library')).dy,
          greaterThan(tester.getBottomLeft(find.text('Media')).dy),
        );
      });
    }

    for (final width in [_desktopWidth, 1600.0]) {
      testWidgets('at master-detail width $width: the title and tabs sit in '
          'a pane bar, the tabs under the title', (tester) async {
        setWidth(tester, width);
        await tester.pumpWidget(
          host(selected: MediaConsoleSection.library, onSelect: (_) {}),
        );

        expect(find.byType(AppBar), findsNothing);
        final bar = find.byType(PaneHeaderBar);
        expect(bar, findsOneWidget);
        for (final text in ['Media', 'Library']) {
          expect(
            find.descendant(of: bar, matching: find.text(text)),
            findsOneWidget,
          );
        }
        expect(
          tester.getTopLeft(find.text('Library')).dy,
          greaterThan(tester.getBottomLeft(find.text('Media')).dy),
        );
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        // The pane bar draws the rule under the tabs; a second one from the
        // tab bar would double it.
        expect(tabBar.dividerColor, Colors.transparent);
        // In line with the switch's first name, 8px further in than a tab
        // label's own padding puts it.
        expect(tabBar.padding, const EdgeInsetsDirectional.only(start: 8));
      });
    }

    testWidgets('no sidebar at any width: content spans the full width', (
      tester,
    ) async {
      for (final width in [500.0, _desktopWidth, 1600.0]) {
        setWidth(tester, width);
        await tester.pumpWidget(
          host(selected: MediaConsoleSection.library, onSelect: (_) {}),
        );
        expect(find.byType(ListTile), findsNothing, reason: 'width $width');
        expect(find.byType(VerticalDivider), findsNothing);
        expect(tester.getSize(find.byKey(_contentKey)).width, width);
      }
    });

    testWidgets("phone: the app bar takes the header title's height and pin", (
      tester,
    ) async {
      // A host that slides the page sideways holds the bar still through
      // the pin, and a count line under the switch needs a taller toolbar.
      setWidth(tester, _phoneWidth);
      const pinKey = Key('pin');
      await tester.pumpWidget(
        host(
          selected: MediaConsoleSection.library,
          onSelect: (_) {},
          appBarHeight: 80,
          appBarPin: (bar) => PreferredSize(
            key: pinKey,
            preferredSize: bar.preferredSize,
            child: bar,
          ),
        ),
      );

      expect(appBar(tester).toolbarHeight, 80);
      expect(
        find.ancestor(of: find.byType(AppBar), matching: find.byKey(pinKey)),
        findsOneWidget,
      );
    });
  });

  group('selection', () {
    for (final width in [_phoneWidth, _desktopWidth]) {
      testWidgets('tapping a tab fires onSelect at width $width', (
        tester,
      ) async {
        setWidth(tester, width);
        MediaConsoleSection? tapped;
        await tester.pumpWidget(
          host(
            selected: MediaConsoleSection.library,
            onSelect: (s) => tapped = s,
          ),
        );
        // The tab strip can scroll at phone width: later sections may sit
        // off-screen until dragged into view.
        await tester.ensureVisible(find.text('Equipment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Equipment'));
        expect(tapped, MediaConsoleSection.gear);
      });
    }

    testWidgets('an outside selection change moves the tab indicator', (
      tester,
    ) async {
      // Browsing a source on the Sources page selects the Library from
      // outside the tab strip; the indicator has to follow it.
      setWidth(tester, _desktopWidth);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.gear, onSelect: (_) {}),
      );
      TabController controller() =>
          tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(controller().index, MediaConsoleSection.gear.index);

      await tester.pumpWidget(
        host(selected: MediaConsoleSection.library, onSelect: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(controller().index, MediaConsoleSection.library.index);
    });

    testWidgets('the selected tab survives a resize between layouts', (
      tester,
    ) async {
      setWidth(tester, _desktopWidth);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.gear, onSelect: (_) {}),
      );
      expect(find.byType(PaneHeaderBar), findsOneWidget);

      setWidth(tester, _phoneWidth);
      await tester.pumpAndSettle();
      expectTabsInAppBar(tester);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        MediaConsoleSection.gear.index,
      );
    });
  });

  testWidgets('badge count renders when nonzero', (tester) async {
    setWidth(tester, _desktopWidth);
    await tester.pumpWidget(
      host(
        selected: MediaConsoleSection.library,
        onSelect: (_) {},
        badgeCounts: const {MediaConsoleSection.library: 3},
      ),
    );
    expect(find.text('3'), findsOneWidget);
  });

  group('tab colours on the app bar surface', () {
    // Below master-detail width the tabs sit on the app bar, whose
    // background is a brand colour on several presets. A stock tab label is `primary`, which Tropical sets
    // to that very background, so contrast is checked on every preset.
    Color labelColor(WidgetTester tester, String label) {
      final text = tester.widget<RichText>(
        find.descendant(of: find.text(label), matching: find.byType(RichText)),
      );
      return text.text.style!.color!;
    }

    Color appBarBackground(WidgetTester tester, ThemeData theme) {
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            )
            .first,
      );
      // A translucent bar (Minimalist) shows the scaffold through it.
      return Color.alphaBlend(material.color!, theme.scaffoldBackgroundColor);
    }

    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    Future<ThemeData> pumpPreset(
      WidgetTester tester,
      String id,
      Brightness brightness, {
      double width = _phoneWidth,
    }) async {
      final theme = AppThemeRegistry.resolveTheme(
        AppThemeRegistry.findById(id),
        brightness,
      );
      setWidth(tester, width);
      await tester.pumpWidget(
        host(
          selected: MediaConsoleSection.library,
          onSelect: (_) {},
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      return theme;
    }

    testWidgets('keeps the stock primary selected label where it reads', (
      tester,
    ) async {
      final theme = await pumpPreset(tester, 'submersion', Brightness.light);
      expect(labelColor(tester, 'Library'), theme.colorScheme.primary);
    });

    testWidgets('falls back to the title colour where primary is the bar', (
      tester,
    ) async {
      // Tropical light paints its app bar in its primary colour.
      final theme = await pumpPreset(tester, 'tropical', Brightness.light);
      expect(
        appBarBackground(tester, theme),
        theme.colorScheme.primary,
        reason: 'precondition: the bar is primary',
      );
      expect(labelColor(tester, 'Library'), labelColor(tester, 'Media'));
    });

    testWidgets('stacked tabs drop the divider on a coloured bar only', (
      tester,
    ) async {
      // The row draws the rule, not the tab bar, so it runs under the
      // buttons as well as the tabs.
      BoxBorder? divider() =>
          (tester
                      .widget<DecoratedBox>(
                        find.byKey(const ValueKey('media_console_tab_row')),
                      )
                      .decoration
                  as BoxDecoration)
              .border;
      Color? tabBarDivider() =>
          tester.widget<TabBar>(find.byType(TabBar)).dividerColor;

      // Tropical's teal bar already contrasts with the page: no extra rule.
      await pumpPreset(tester, 'tropical', Brightness.light, width: 360);
      expectTabsInAppBar(tester);
      expect(divider(), isNull);
      expect(tabBarDivider(), Colors.transparent);

      // Submersion's bar is the page colour: a rule the row's full width.
      final submersion = await pumpPreset(
        tester,
        'submersion',
        Brightness.light,
        width: 360,
      );
      expectTabsInAppBar(tester);
      expect(
        divider(),
        Border(
          bottom: BorderSide(color: submersion.colorScheme.outlineVariant),
        ),
      );
      expect(tabBarDivider(), Colors.transparent);
      expect(
        tester.getSize(find.byKey(const ValueKey('media_console_tab_row'))),
        const Size(360, kTextTabBarHeight),
      );
    });

    testWidgets('the buttons take the unselected tab colour', (tester) async {
      // On Tropical's teal bar the stock icon colour would not read; the
      // buttons follow the tab labels instead.
      for (final id in ['tropical', 'submersion']) {
        await pumpPreset(tester, id, Brightness.light);
        final icon = tester.widget<Icon>(
          find.descendant(
            of: action(MediaConsoleAction.sources),
            matching: find.byType(Icon),
          ),
        );
        final iconColor =
            icon.color ??
            IconTheme.of(
              tester.element(
                find.descendant(
                  of: action(MediaConsoleAction.sources),
                  matching: find.byType(Icon),
                ),
              ),
            ).color;
        expect(iconColor, labelColor(tester, 'Equipment'), reason: id);
      }
    });

    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        for (final width in [_phoneWidth, 1000.0]) {
          testWidgets(
            '${preset.id} ${brightness.name} at $width: labels readable',
            (tester) async {
              final theme = AppThemeRegistry.resolveTheme(preset, brightness);
              setWidth(tester, width);
              await tester.pumpWidget(
                host(
                  selected: MediaConsoleSection.library,
                  onSelect: (_) {},
                  theme: theme,
                ),
              );
              await tester.pumpAndSettle();

              final background = appBarBackground(tester, theme);
              final title = labelColor(tester, 'Media');
              final selected = labelColor(tester, 'Library');
              final unselected = labelColor(tester, 'Equipment');

              // The selected label is stock `primary` where that reads on
              // the bar, else the title's own colour: the legibility the
              // theme chose for this surface (white on Tropical's teal is
              // only about 2.6:1), never less.
              final titleContrast = contrast(title, background);
              expect(
                selected,
                anyOf(theme.colorScheme.primary, title),
                reason: 'selected label is primary or the title colour',
              );
              expect(
                contrast(selected, background),
                greaterThanOrEqualTo(titleContrast < 4.5 ? titleContrast : 4.5),
                reason: 'selected label on the app bar',
              );
              // Dimmed for selection, yet still WCAG AA (4.5:1); where the
              // theme's own title falls short of AA, it keeps 80% of the
              // title's contrast instead.
              expect(
                contrast(unselected, background),
                greaterThanOrEqualTo(
                  titleContrast * 0.8 < 4.5 ? titleContrast * 0.8 : 4.5,
                ),
                reason: 'unselected label on the app bar',
              );
              expect(
                unselected,
                isNot(selected),
                reason: 'selection must be visible in the label colour',
              );
            },
          );
        }
      }
    }
  });

  group('tab colours on the desktop pane bar', () {
    // At master-detail width the tabs sit in the pane bar, drawn in the
    // scheme's surface whatever colour the app bar takes.
    Color labelColor(WidgetTester tester, String label) {
      final text = tester.widget<RichText>(
        find.descendant(of: find.text(label), matching: find.byType(RichText)),
      );
      return text.text.style!.color!;
    }

    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        testWidgets('${preset.id} ${brightness.name}: labels readable', (
          tester,
        ) async {
          final theme = AppThemeRegistry.resolveTheme(preset, brightness);
          setWidth(tester, _desktopWidth);
          await tester.pumpWidget(
            host(
              selected: MediaConsoleSection.library,
              onSelect: (_) {},
              theme: theme,
            ),
          );
          await tester.pumpAndSettle();

          final background = theme.colorScheme.surface;
          final selected = labelColor(tester, 'Library');
          final unselected = labelColor(tester, 'Equipment');
          final textContrast = contrast(
            theme.colorScheme.onSurface,
            background,
          );
          expect(
            contrast(selected, background),
            greaterThanOrEqualTo(textContrast < 4.5 ? textContrast : 4.5),
            reason: 'selected label on the pane bar',
          );
          expect(
            contrast(unselected, background),
            greaterThanOrEqualTo(
              textContrast * 0.8 < 4.5 ? textContrast * 0.8 : 4.5,
            ),
            reason: 'unselected label on the pane bar',
          );
          expect(unselected, isNot(selected));
        });
      }
    }
  });

  testWidgets('a browser shows only the Transfers button (#4121)', (
    tester,
  ) async {
    // A browser can neither import files nor watch folders.
    setWidth(tester, _desktopWidth);
    await tester.pumpWidget(
      host(
        selected: MediaConsoleSection.library,
        onSelect: (_) {},
        browser: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Equipment'), findsOneWidget);
    expect(action(MediaConsoleAction.transfers), findsOneWidget);
    expect(action(MediaConsoleAction.importMedia), findsNothing);
    expect(action(MediaConsoleAction.sources), findsNothing);
  });

  group('action buttons (#4587)', () {
    for (final width in [_phoneWidth, _desktopWidth]) {
      testWidgets('tapping each button fires onAction at width $width', (
        tester,
      ) async {
        setWidth(tester, width);
        final tapped = <MediaConsoleAction>[];
        MediaConsoleSection? selected;
        await tester.pumpWidget(
          host(
            selected: MediaConsoleSection.library,
            onSelect: (s) => selected = s,
            onAction: tapped.add,
          ),
        );
        for (final a in MediaConsoleAction.values) {
          await tester.tap(action(a));
        }
        expect(tapped, MediaConsoleAction.values);
        // A button is not a tab: the selection does not move.
        expect(selected, isNull);
      });

      testWidgets('buttons share the tab row at width $width', (tester) async {
        setWidth(tester, width);
        await tester.pumpWidget(
          host(selected: MediaConsoleSection.library, onSelect: (_) {}),
        );
        final tabsCentre = tester.getCenter(find.text('Library'));
        // The buttons start where the (scrollable) tab strip ends, never
        // over it.
        var previousRight = tester.getTopRight(find.byType(TabBar)).dx;
        for (final a in MediaConsoleAction.values) {
          final centre = tester.getCenter(action(a));
          expect(centre.dy, closeTo(tabsCentre.dy, 1), reason: a.name);
          final left = tester.getTopLeft(action(a)).dx;
          expect(left, greaterThanOrEqualTo(previousRight), reason: a.name);
          previousRight = tester.getTopRight(action(a)).dx;
        }
        // The last button ends at the row's trailing edge, less its gap.
        expect(previousRight, closeTo(width - 4, 1));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('media_console_tab_row')),
            matching: find.byType(IconButton),
          ),
          findsNWidgets(MediaConsoleAction.values.length),
        );
      });
    }

    testWidgets('a 320px phone fits two tabs and three buttons', (
      tester,
    ) async {
      setWidth(tester, 320);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.library, onSelect: (_) {}),
      );
      expect(tester.takeException(), isNull);
      for (final a in MediaConsoleAction.values) {
        expect(action(a).hitTestable(), findsOneWidget, reason: a.name);
      }
      // Where the labels outgrow the strip (large text), it scrolls rather
      // than run under the buttons: the Gear tab can still be reached.
      await tester.ensureVisible(find.text('Equipment'));
      await tester.pumpAndSettle();
      expect(find.text('Equipment').hitTestable(), findsOneWidget);
    });

    testWidgets('the buttons carry their names as tooltips', (tester) async {
      setWidth(tester, _desktopWidth);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.library, onSelect: (_) {}),
      );
      for (final (a, tip) in const [
        (MediaConsoleAction.importMedia, 'Import'),
        (MediaConsoleAction.transfers, 'Transfers'),
        (MediaConsoleAction.sources, 'Sources'),
      ]) {
        expect(tester.widget<IconButton>(action(a)).tooltip, tip);
      }
    });
  });
}
