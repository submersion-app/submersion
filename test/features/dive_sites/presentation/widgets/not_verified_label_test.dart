import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/presentation/widgets/not_verified_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('says Not verified', (tester) async {
    await tester.pumpWidget(_app(const NotVerifiedLabel()));

    expect(find.text('Not verified'), findsOneWidget);
  });

  testWidgets('draws its outline in the theme outline colour, light and dark', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _app(const NotVerifiedLabel(), brightness: brightness),
      );
      final scheme = Theme.of(
        tester.element(find.byType(NotVerifiedLabel)),
      ).colorScheme;
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(NotVerifiedLabel),
          matching: find.byType(DecoratedBox),
        ),
      );
      final border = (box.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, scheme.outline, reason: '$brightness');
      final text = tester.widget<Text>(find.text('Not verified'));
      expect(text.style?.color, scheme.onSurfaceVariant, reason: '$brightness');
    }
  });
}
