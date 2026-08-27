import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/media_nav_arrows.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Const-constructible callback, so the RTL case can pump a const subtree.
void _noop() {}

void main() {
  Future<void> pumpArrows(
    WidgetTester tester, {
    required int currentIndex,
    required int totalCount,
    List<String>? log,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // flutter_test forwards the HOST locale list; without this pin the
        // English assertions below fail on a non-English dev machine.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              MediaNavArrows(
                currentIndex: currentIndex,
                totalCount: totalCount,
                onPrevious: () => log?.add('previous'),
                onNext: () => log?.add('next'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hidden for a single item', (tester) async {
    await pumpArrows(tester, currentIndex: 0, totalCount: 1);

    expect(find.byTooltip('Previous media'), findsNothing);
    expect(find.byTooltip('Next media'), findsNothing);
  });

  testWidgets('hidden for an empty list', (tester) async {
    await pumpArrows(tester, currentIndex: 0, totalCount: 0);

    expect(find.byTooltip('Previous media'), findsNothing);
    expect(find.byTooltip('Next media'), findsNothing);
  });

  testWidgets('no previous arrow on the first item', (tester) async {
    await pumpArrows(tester, currentIndex: 0, totalCount: 3);

    expect(find.byTooltip('Previous media'), findsNothing);
    expect(find.byTooltip('Next media'), findsOneWidget);
  });

  testWidgets('no next arrow on the last item', (tester) async {
    await pumpArrows(tester, currentIndex: 2, totalCount: 3);

    expect(find.byTooltip('Previous media'), findsOneWidget);
    expect(find.byTooltip('Next media'), findsNothing);
  });

  testWidgets('both arrows in the middle, and each fires its callback', (
    tester,
  ) async {
    final log = <String>[];
    await pumpArrows(tester, currentIndex: 1, totalCount: 3, log: log);

    expect(find.byTooltip('Previous media'), findsOneWidget);
    expect(find.byTooltip('Next media'), findsOneWidget);

    await tester.tap(find.byTooltip('Next media'));
    await tester.tap(find.byTooltip('Previous media'));
    expect(log, ['next', 'previous']);
  });

  testWidgets(
    'the next arrow sits on the trailing edge even with no previous',
    (tester) async {
      await pumpArrows(tester, currentIndex: 0, totalCount: 3);

      // Dropping the leading arrow must not slide the trailing one inward:
      // spaceBetween keeps it pinned to the right edge.
      final next = tester.getCenter(find.byTooltip('Next media'));
      final screen = tester.getSize(find.byType(Scaffold));
      expect(next.dx, greaterThan(screen.width / 2));
    },
  );

  testWidgets('RTL mirrors both the edges and the chevrons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              MediaNavArrows(
                currentIndex: 1,
                totalCount: 3,
                onPrevious: _noop,
                onNext: _noop,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final centre = tester.getSize(find.byType(Scaffold)).width / 2;
    // Previous sits on the right and points right; next mirrors it. Both must
    // agree with the pager, which also reverses under RTL.
    expect(
      tester.getCenter(find.byIcon(Icons.chevron_right)).dx,
      greaterThan(centre),
    );
    expect(
      tester.getCenter(find.byIcon(Icons.chevron_left)).dx,
      lessThan(centre),
    );
  });

  testWidgets('taps between the arrows fall through to the chrome toggle', (
    tester,
  ) async {
    // The arrows cover the whole viewer so they can pin themselves to the
    // edges; a Row does not hit-test its empty space, so the tap-to-toggle
    // target beneath still receives centre taps. Without that the arrows
    // would silently kill chrome toggling on every multi-item gallery.
    var passThroughTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => passThroughTaps++,
                  child: const SizedBox.expand(),
                ),
              ),
              MediaNavArrows(
                currentIndex: 1,
                totalCount: 3,
                onPrevious: () {},
                onNext: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byType(Scaffold)));
    await tester.pump();

    expect(passThroughTaps, 1);
  });
}
