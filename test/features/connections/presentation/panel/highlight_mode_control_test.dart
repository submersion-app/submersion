import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/panel/highlight_mode_control.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/connections/presentation/widgets/highlight_key.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<ProviderContainer> _pump(WidgetTester tester, Widget child) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('the segments write the mode and show its key', (tester) async {
    final c = await _pump(tester, const HighlightModeControl(groupCount: 3));
    expect(find.text('Color by'), findsOneWidget);
    expect(find.byKey(const ValueKey('highlight-key-groups')), findsNothing);

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).highlight, HighlightMode.groups);
    expect(find.byKey(const ValueKey('highlight-key-groups')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-swatch-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-swatch-3')), findsNothing);

    await tester.tap(find.text('Recency'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).highlight, HighlightMode.recency);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
  });

  testWidgets('the legend follows the mode', (tester) async {
    Future<void> show(HighlightMode m) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ConnectionsLegend(
            kinds: const {ConnectionKind.buddy},
            colors: const ConnectionKindColors({}, Colors.teal),
            highlight: m,
            groupCount: 2,
          ),
        ),
      ),
    );
    await show(HighlightMode.byKind);
    expect(find.text('Buddies'), findsOneWidget);
    await show(HighlightMode.groups);
    expect(find.text('Buddies'), findsNothing);
    expect(find.text('Color: group'), findsOneWidget);
    await show(HighlightMode.recency);
    expect(find.text('Buddies'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('the recency fade follows the reading direction', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(child: HighlightKey(mode: HighlightMode.recency)),
        ),
      ),
    );
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('highlight-key-recency')),
        matching: find.byType(Container),
      ),
    );
    final gradient =
        (box.decoration! as BoxDecoration).gradient! as LinearGradient;
    final resolved = gradient.begin.resolve(TextDirection.rtl);
    expect(resolved, Alignment.centerRight, reason: 'recent end sits at start');
  });
}
