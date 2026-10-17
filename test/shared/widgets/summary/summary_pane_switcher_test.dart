import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/summary_pane_view.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/summary/summary_pane_switcher.dart';

import '../../../helpers/mock_providers.dart';

Widget _switcher(String sectionId, {bool isEmpty = false}) {
  return SummaryPaneSwitcher(
    sectionId: sectionId,
    isEmpty: isEmpty,
    scene: (_) => Text('$sectionId scene'),
    details: (_) => Text('$sectionId details'),
  );
}

Widget _app(
  Widget child, {
  AppSettings settings = const AppSettings(),
  TextDirection direction = TextDirection.ltr,
  Key? scopeKey,
}) {
  return ProviderScope(
    key: scopeKey,
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the scene by default', (tester) async {
    await tester.pumpWidget(_app(_switcher('dives')));

    expect(find.text('dives scene'), findsOneWidget);
    expect(find.text('dives details'), findsNothing);
  });

  testWidgets('shows the details when the setting says details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _switcher('dives'),
        settings: const AppSettings(summaryPaneView: SummaryPaneView.details),
      ),
    );

    expect(find.text('dives details'), findsOneWidget);
  });

  testWidgets('an empty page shows the details and keeps the toggle', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_switcher('dives', isEmpty: true)));

    expect(find.text('dives details'), findsOneWidget);
    expect(find.byType(SummaryPaneToggle), findsOneWidget);

    await tester.tap(find.byType(SummaryPaneToggle));
    await tester.pump();

    expect(find.text('dives scene'), findsOneWidget);
  });

  testWidgets('the toggle flips the pane for the session only', (tester) async {
    const scope = ValueKey('scope-a');
    await tester.pumpWidget(_app(_switcher('dives'), scopeKey: scope));

    await tester.tap(find.byType(SummaryPaneToggle));
    await tester.pump();
    expect(find.text('dives details'), findsOneWidget);

    // Same session: the override survives a rebuild.
    await tester.pumpWidget(_app(_switcher('dives'), scopeKey: scope));
    expect(find.text('dives details'), findsOneWidget);

    // A fresh session (new ProviderScope) starts from the default again.
    await tester.pumpWidget(
      _app(_switcher('dives'), scopeKey: const ValueKey('scope-b')),
    );
    expect(find.text('dives scene'), findsOneWidget);
  });

  testWidgets('the override is per section', (tester) async {
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            Expanded(child: _switcher('dives')),
            Expanded(child: _switcher('sites')),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(SummaryPaneToggle).first);
    await tester.pump();

    expect(find.text('dives details'), findsOneWidget);
    expect(find.text('sites scene'), findsOneWidget);
  });

  testWidgets('the toggle names the other view and keeps a 48 px target', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_switcher('dives')));

    expect(find.byTooltip('Show details'), findsOneWidget);
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byType(SummaryPaneToggle));
    await tester.pump();

    expect(find.byTooltip('Show scene'), findsOneWidget);
  });

  testWidgets('the toggle sits at the end edge in a right-to-left locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_switcher('dives'), direction: TextDirection.rtl),
    );

    final pane = tester.getRect(find.byType(SummaryPaneSwitcher));
    final toggle = tester.getRect(find.byType(SummaryPaneToggle));
    expect(toggle.left, lessThan(pane.width / 2));
  });
}
