import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('reads Closed and is not a Chip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: DiveCenterClosedTag())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Closed'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
  });

  test('every closed surface greys to the same opacity', () {
    expect(kClosedDiveCenterOpacity, 0.6);
  });

  testWidgets('the label uses onSurface so it stays readable when greyed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: DiveCenterClosedTag())),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(DiveCenterClosedTag));
    final text = tester.widget<Text>(find.text('Closed'));
    expect(text.style?.color, Theme.of(context).colorScheme.onSurface);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
