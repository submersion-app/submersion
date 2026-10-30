import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_builder.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card_share_choices.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/share_choices_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<List<BuddyCardShareChoices>> pump(
    WidgetTester tester, {
    Set<BuddyCardField> available = const {
      BuddyCardField.phone,
      BuddyCardField.certifications,
    },
  }) async {
    final saved = <BuddyCardShareChoices>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShareChoicesSheet(
            initial: BuddyCardShareChoices.defaults,
            available: available,
            onChanged: saved.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets('hides fields the diver has not filled in', (tester) async {
    await pump(tester);
    expect(find.widgetWithText(SwitchListTile, 'Phone'), findsOneWidget);
    expect(
      find.widgetWithText(SwitchListTile, 'Certifications'),
      findsOneWidget,
    );
    expect(find.widgetWithText(SwitchListTile, 'Email'), findsNothing);
    expect(find.widgetWithText(SwitchListTile, 'Photo'), findsNothing);
  });

  testWidgets('the name is always shared and has no switch', (tester) async {
    await pump(tester);
    expect(find.text('Always shared'), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Name'), findsNothing);
  });

  testWidgets('medical and insurance are never offered', (tester) async {
    await pump(tester);
    expect(
      find.text('Medical, insurance and emergency details are never shared.'),
      findsOneWidget,
    );
  });

  testWidgets('toggling a switch saves the choices', (tester) async {
    final saved = await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Phone'));
    await tester.pumpAndSettle();
    expect(saved.single.phone, isFalse);
    expect(saved.single.certifications, isTrue);
  });

  testWidgets('card details can only be shared with the certifications', (
    tester,
  ) async {
    await pump(
      tester,
      available: const {
        BuddyCardField.certifications,
        BuddyCardField.cardDetails,
      },
    );
    SwitchListTile details() => tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Card numbers and dates'),
    );
    expect(details().onChanged, isNotNull);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Certifications'));
    await tester.pumpAndSettle();
    expect(details().onChanged, isNull);
  });
}
