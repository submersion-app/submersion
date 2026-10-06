import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/built_in_show_column.dart';

void main() {
  Widget page({
    Locale locale = const Locale('en'),
    double trailingInset = 0,
    List<Widget> trailingAfterSwitch = const [],
    ValueChanged<bool>? onChanged,
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ListView(
        children: [
          BuiltInShowColumnHeader(
            title: 'Built-in',
            trailingInset: trailingInset,
          ),
          ListTile(
            title: const Text('Buddy'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BuiltInShowSwitch(
                  shown: true,
                  switchKey: builtInShowSwitchKey(
                    BuiltInCatalog.diveRoles,
                    'buddy',
                  ),
                  onChanged: onChanged ?? (_) {},
                ),
                ...trailingAfterSwitch,
              ],
            ),
          ),
        ],
      ),
    ),
  );

  double centerX(WidgetTester tester, Finder finder) =>
      tester.getCenter(finder).dx;

  testWidgets('the Show label sits centred over the switch', (tester) async {
    await tester.pumpWidget(page());
    final label = find.text('Show');
    expect(label, findsOneWidget);
    expect(
      centerX(tester, label),
      moreOrLessEquals(centerX(tester, find.byType(Switch)), epsilon: 0.5),
    );
  });

  testWidgets('a trailing inset keeps the label over a non-final switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        trailingInset: 48,
        trailingAfterSwitch: [
          PopupMenuButton<int>(itemBuilder: (_) => const []),
        ],
      ),
    );
    expect(
      centerX(tester, find.text('Show')),
      moreOrLessEquals(centerX(tester, find.byType(Switch)), epsilon: 0.5),
    );
  });

  testWidgets('a long translation still lines up and fits the column', (
    tester,
  ) async {
    await tester.pumpWidget(page(locale: const Locale('hu')));
    final label = find.text('Megjelenítés');
    expect(
      centerX(tester, label),
      moreOrLessEquals(centerX(tester, find.byType(Switch)), epsilon: 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the switch reports changes and carries its key', (tester) async {
    bool? reported;
    await tester.pumpWidget(page(onChanged: (v) => reported = v));
    await tester.tap(
      find.byKey(builtInShowSwitchKey(BuiltInCatalog.diveRoles, 'buddy')),
    );
    expect(reported, isFalse);
  });

  testWidgets('the switch has the generic tooltip', (tester) async {
    await tester.pumpWidget(page());
    expect(find.byTooltip('Show in pickers'), findsOneWidget);
  });
}
