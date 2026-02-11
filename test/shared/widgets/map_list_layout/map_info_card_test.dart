import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

void main() {
  Widget buildTestWidget({
    required String title,
    String? subtitle,
    Widget? leading,
    VoidCallback? onTap,
    VoidCallback? onDetailsTap,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: MapInfoCard(
                title: title,
                subtitle: subtitle,
                leading: leading,
                onTap: onTap,
                onDetailsTap: onDetailsTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('displays title', (tester) async {
    await tester.pumpWidget(buildTestWidget(title: 'Test Site'));
    expect(find.text('Test Site'), findsOneWidget);
  });

  testWidgets('displays subtitle when provided', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(title: 'Test Site', subtitle: 'Location info'),
    );
    expect(find.text('Location info'), findsOneWidget);
  });

  testWidgets('hides subtitle when null', (tester) async {
    await tester.pumpWidget(buildTestWidget(title: 'Test Site'));
    expect(find.text('Location info'), findsNothing);
  });

  testWidgets('displays leading widget when provided', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        title: 'Test Site',
        leading: const Icon(Icons.location_on, key: Key('leading-icon')),
      ),
    );
    expect(find.byKey(const Key('leading-icon')), findsOneWidget);
  });

  testWidgets('shows chevron_right icon for details navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(title: 'Test Site', onDetailsTap: () {}),
    );
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('calls onTap when card is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildTestWidget(title: 'Test Site', onTap: () => tapped = true),
    );
    await tester.tap(find.byType(MapInfoCard));
    expect(tapped, isTrue);
  });

  testWidgets('calls onDetailsTap when chevron is tapped', (tester) async {
    var detailsTapped = false;
    await tester.pumpWidget(
      buildTestWidget(
        title: 'Test Site',
        onDetailsTap: () => detailsTapped = true,
      ),
    );
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(detailsTapped, isTrue);
  });

  testWidgets('has correct styling', (tester) async {
    await tester.pumpWidget(buildTestWidget(title: 'Test Site'));

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.elevation, 4);
    expect(card.shape, isA<RoundedRectangleBorder>());
  });
}
