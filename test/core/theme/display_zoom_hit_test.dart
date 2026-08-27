import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom.dart';

/// Window sizes to re-run the geometry checks at.
///
/// A dead band produced by hit-testing a `sizedByParent` box through the
/// enclosing transform is a FRACTION of the window, not a fixed inset, so it is
/// invisible at the default 800x600 test surface and obvious on a maximised
/// desktop window. Issue #953 was reported at roughly 1120x850 logical: the
/// same button was live in a narrow window and dead in a wide one.
const _windows = <Size>[
  Size(400, 300),
  Size(800, 600),
  Size(1120, 850),
  Size(1600, 1000),
];

/// Resizes the test view, which drives the layout constraints and the implicit
/// MediaQuery together.
///
/// `setSurfaceSize` is deliberately not used: it moves the render surface but
/// leaves the view metrics alone, so `DisplayZoomScope` would read a stale
/// `MediaQuery.size` and compute its logical size against a window that is not
/// the one being laid out.
void _resizeWindow(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  for (final zoom in const [0.7, 0.8, 1.0, 1.3, 1.4]) {
    testWidgets('forwards taps through the transform at zoom $zoom', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DisplayZoomScope(
            zoom: zoom,
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => taps++,
                  child: const Text('Tap me'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(taps, 1, reason: 'tap must register at zoom $zoom');
    });
  }

  // A centred target is not enough. The transform is anchored top-left, so a
  // widget at the middle of the screen sits at zoom * centre in the scaled
  // space and stays inside the window rect no matter how the boxes are
  // nested. Only targets past that rect expose a hit-test region that is
  // narrower than the painted area.
  for (final zoom in const [0.7, 0.8, 1.0, 1.3, 1.4]) {
    testWidgets('registers a tap on the bottom navigation bar at zoom $zoom', (
      tester,
    ) async {
      var selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DisplayZoomScope(
            zoom: zoom,
            child: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (index) => selected = index,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.scuba_diving),
                    label: 'Dives',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.place),
                    label: 'Sites',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sites'));
      await tester.pump();

      expect(
        selected,
        1,
        reason: 'bottom navigation bar must be tappable at zoom $zoom',
      );
    });
  }

  for (final zoom in const [0.7, 0.8, 0.95, 1.0, 1.05, 1.3, 1.4]) {
    for (final window in _windows) {
      testWidgets('hit-tests every corner of a ${window.width.toInt()}x'
          '${window.height.toInt()} window at zoom $zoom', (tester) async {
        _resizeWindow(tester, window);
        final hits = <Offset>[];

        await tester.pumpWidget(
          MaterialApp(
            home: DisplayZoomScope(
              zoom: zoom,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => hits.add(details.globalPosition),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );

        final corners = <Offset>[
          const Offset(1, 1),
          Offset(window.width - 1, 1),
          Offset(1, window.height - 1),
          Offset(window.width - 1, window.height - 1),
        ];

        for (final corner in corners) {
          await tester.tapAt(corner);
          await tester.pump();
        }

        expect(
          hits,
          corners,
          reason:
              'the whole painted window must stay hit-testable at zoom $zoom '
              'in a ${window.width}x${window.height} window; missing corners '
              'mean the scaled subtree is laid out larger than the box that '
              'guards the hit test',
        );
      });
    }
  }

  // Issue #953: the same controls were live in a narrow/short window and dead
  // in a wide/tall one at the same zoom. Growing the window must not move the
  // hit box off the control, so the identical probes run at every size.
  for (final window in _windows) {
    testWidgets('keeps edge controls live in a ${window.width.toInt()}x'
        '${window.height.toInt()} window at 95% zoom', (tester) async {
      _resizeWindow(tester, window);
      var menuTaps = 0;
      var rowTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DisplayZoomScope(
            zoom: 0.95,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Shearwater Petrel 3'),
                actions: [
                  IconButton(
                    tooltip: 'Show menu',
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () => menuTaps++,
                  ),
                ],
              ),
              // Fills the body so the last row sits against the bottom edge,
              // matching the tag list in the report.
              body: Column(
                children: [
                  const Spacer(),
                  ListTile(
                    title: const Text('backmount'),
                    onTap: () => rowTaps++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.tap(find.text('backmount'));
      await tester.pump();

      expect(
        menuTaps,
        1,
        reason:
            'the top-right app bar action must stay tappable in a '
            '${window.width}x${window.height} window',
      );
      expect(
        rowTaps,
        1,
        reason:
            'the bottom-most list row must stay tappable in a '
            '${window.width}x${window.height} window',
      );
    });
  }
}
