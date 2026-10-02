import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _contentKey = Key('content');

void main() {
  Widget host({
    required MediaConsoleSection selected,
    required ValueChanged<MediaConsoleSection> onSelect,
    Map<MediaConsoleSection, int> badgeCounts = const {},
    String title = 'Media',
    ThemeData? theme,
    TextScaler? textScaler,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: MediaConsoleScaffold(
        title: title,
        selected: selected,
        onSelect: onSelect,
        badgeCounts: badgeCounts,
        child: const SizedBox.expand(key: _contentKey),
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

  bool tabsInline(WidgetTester tester) {
    // Inline tabs live in the title slot; stacked ones are the bottom.
    final bar = appBar(tester);
    final inTitle = find.descendant(
      of: find.byWidget(bar.title!),
      matching: find.byType(TabBar),
    );
    return bar.bottom == null && inTitle.evaluate().isNotEmpty;
  }

  test('the console has exactly four destinations', () {
    // Unlinked media no longer exists and Missing files is a Library chip,
    // so neither gets a tab.
    expect(MediaConsoleSection.values, [
      MediaConsoleSection.library,
      MediaConsoleSection.sources,
      MediaConsoleSection.transfers,
      MediaConsoleSection.importMedia,
    ]);
  });

  group('layout', () {
    testWidgets('wide layout puts the tabs inline beside the title', (
      tester,
    ) async {
      setWidth(tester, 1100);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.library, onSelect: (_) {}),
      );

      expect(find.byType(TabBar), findsOneWidget);
      expect(tabsInline(tester), isTrue);
      // Same row: the tabs and the title share the toolbar's centre line.
      expect(
        tester.getCenter(find.text('Library')).dy,
        moreOrLessEquals(tester.getCenter(find.text('Media')).dy, epsilon: 1),
      );
      // Inline tabs sit to the right of the title, never over it.
      expect(
        tester.getTopLeft(find.text('Library')).dx,
        greaterThan(tester.getTopRight(find.text('Media')).dx),
      );
    });

    testWidgets('no sidebar at any width: content spans the full width', (
      tester,
    ) async {
      for (final width in [500.0, 1100.0, 1600.0]) {
        setWidth(tester, width);
        await tester.pumpWidget(
          host(selected: MediaConsoleSection.library, onSelect: (_) {}),
        );
        expect(find.byType(ListTile), findsNothing, reason: 'width $width');
        expect(find.byType(VerticalDivider), findsNothing);
        expect(tester.getSize(find.byKey(_contentKey)).width, width);
      }
    });

    testWidgets('narrow layout stacks the tabs under the title', (
      tester,
    ) async {
      setWidth(tester, 360);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.library, onSelect: (_) {}),
      );

      expect(find.byType(TabBar), findsOneWidget);
      expect(appBar(tester).bottom, isA<TabBar>());
      expect(tabsInline(tester), isFalse);
      expect(
        tester.getCenter(find.text('Library')).dy,
        greaterThan(tester.getBottomLeft(find.text('Media')).dy),
      );
    });

    testWidgets('a title too long to share the bar stacks the tabs', (
      tester,
    ) async {
      // Stands in for a long translation: the decision is measured, so a
      // wide window alone does not force the tabs inline.
      setWidth(tester, 1100);
      await tester.pumpWidget(
        host(
          title: 'Mediathek und Medienverwaltung ' * 3,
          selected: MediaConsoleSection.library,
          onSelect: (_) {},
        ),
      );
      expect(appBar(tester).bottom, isA<TabBar>());
    });

    testWidgets('large text stacks the tabs at a width that fits normally', (
      tester,
    ) async {
      // The test font draws every glyph a full em wide, so this width is
      // comfortably past what the labels need at 1x, not at 2.5x.
      setWidth(tester, 800);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.library, onSelect: (_) {}),
      );
      expect(tabsInline(tester), isTrue);

      await tester.pumpWidget(
        host(
          selected: MediaConsoleSection.library,
          onSelect: (_) {},
          textScaler: const TextScaler.linear(2.5),
        ),
      );
      expect(appBar(tester).bottom, isA<TabBar>());
    });

    testWidgets('a back button narrows the bar and stacks the tabs', (
      tester,
    ) async {
      // A pushed route gets a leading back button, which takes title-slot
      // width. 720px fits the tabs inline at the root of the stack but not
      // beside a 56px back button (the test font draws glyphs an em wide).
      setWidth(tester, 720);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaConsoleScaffold(
            title: 'Media',
            selected: MediaConsoleSection.library,
            onSelect: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(tabsInline(tester), isTrue);

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => MediaConsoleScaffold(
            title: 'Media',
            selected: MediaConsoleSection.library,
            onSelect: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(appBar(tester).bottom, isA<TabBar>());
    });

    testWidgets('notch insets narrow the bar and stack the tabs', (
      tester,
    ) async {
      // Phone landscape: the app bar's SafeArea gives up the notch columns,
      // so a width that fits with no insets must not when they apply.
      setWidth(tester, 700);
      tester.view.padding = const FakeViewPadding(left: 150, right: 150);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.library, onSelect: (_) {}),
      );
      expect(appBar(tester).bottom, isA<TabBar>());
    });
  });

  group('selection', () {
    for (final width in [360.0, 1100.0]) {
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
        await tester.ensureVisible(find.text('Transfers'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Transfers'));
        expect(tapped, MediaConsoleSection.transfers);
      });
    }

    testWidgets('an outside selection change moves the tab indicator', (
      tester,
    ) async {
      // Sources' "Browse source" jumps to Library from outside the tab
      // strip; the indicator has to follow it.
      setWidth(tester, 1100);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.sources, onSelect: (_) {}),
      );
      TabController controller() =>
          tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(controller().index, MediaConsoleSection.sources.index);

      await tester.pumpWidget(
        host(selected: MediaConsoleSection.library, onSelect: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(controller().index, MediaConsoleSection.library.index);
    });

    testWidgets('the selected tab survives a switch between layouts', (
      tester,
    ) async {
      setWidth(tester, 1100);
      await tester.pumpWidget(
        host(selected: MediaConsoleSection.transfers, onSelect: (_) {}),
      );
      expect(tabsInline(tester), isTrue);

      setWidth(tester, 360);
      await tester.pumpAndSettle();
      expect(tabsInline(tester), isFalse);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        MediaConsoleSection.transfers.index,
      );
    });
  });

  testWidgets('a font change re-runs the inline measurement', (tester) async {
    // Nunito (Tropical, Console) arrives asynchronously; the fit measured
    // with the fallback font must be redone when it lands.
    setWidth(tester, 1100);
    await tester.pumpWidget(
      host(selected: MediaConsoleSection.library, onSelect: (_) {}),
    );
    final element = tester.element(find.byType(MediaConsoleScaffold));
    expect(element.dirty, isFalse);

    await tester.binding.handleSystemMessage(<String, dynamic>{
      'type': 'fontsChange',
    });
    expect(element.dirty, isTrue);
    await tester.pump();
  });

  testWidgets('inline tabs stay out of the title header semantics', (
    tester,
  ) async {
    // The app bar wraps its title slot in a route-naming header; inline tabs
    // share that slot but must stay separate, non-header nodes.
    // Disposed in the body: flutter_test checks for live handles before any
    // addTearDown callback runs.
    final semantics = tester.ensureSemantics();
    setWidth(tester, 1100);
    await tester.pumpWidget(
      host(selected: MediaConsoleSection.library, onSelect: (_) {}),
    );
    expect(tabsInline(tester), isTrue);

    final title = tester.getSemantics(find.text('Media')).getSemanticsData();
    expect(title.label, 'Media');
    expect(title.flagsCollection.isHeader, isTrue);

    final tab = tester.getSemantics(find.text('Library')).getSemanticsData();
    expect(tab.label, startsWith('Library'));
    expect(tab.flagsCollection.isHeader, isFalse);
    expect(tab.flagsCollection.namesRoute, isFalse);
    semantics.dispose();
  });

  testWidgets('badge count renders when nonzero', (tester) async {
    setWidth(tester, 1100);
    await tester.pumpWidget(
      host(
        selected: MediaConsoleSection.library,
        onSelect: (_) {},
        badgeCounts: const {MediaConsoleSection.transfers: 3},
      ),
    );
    expect(find.text('3'), findsOneWidget);
  });

  group('tab colours on the app bar surface', () {
    // Tabs now sit on the app bar, whose background is a brand colour on
    // several presets. A stock tab label is `primary`, which Tropical sets
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
      double width = 1100,
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
      Color? divider() =>
          tester.widget<TabBar>(find.byType(TabBar)).dividerColor;

      // Tropical's teal bar already contrasts with the page: no extra rule.
      await pumpPreset(tester, 'tropical', Brightness.light, width: 360);
      expect(appBar(tester).bottom, isA<TabBar>());
      expect(divider(), Colors.transparent);

      // Submersion's bar is the page colour: keep the stock divider.
      await pumpPreset(tester, 'submersion', Brightness.light, width: 360);
      expect(appBar(tester).bottom, isA<TabBar>());
      expect(divider(), isNull);
    });

    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        for (final width in [360.0, 1100.0]) {
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
              final unselected = labelColor(tester, 'Sources');

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
}
