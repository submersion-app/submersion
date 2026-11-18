import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_fold_pencil.dart';

Widget _host({required bool isChanged, VoidCallback? onOpen}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: RecordFoldPencil(
      title: 'Notes',
      isChanged: isChanged,
      onOpen: onOpen ?? () {},
    ),
  ),
);

/// The pencil on a folded section's header row while its record is
/// unlocked (issue #4527).
void main() {
  final l = AppLocalizationsEn();

  testWidgets('the dot shows only when the card has changes', (tester) async {
    await tester.pumpWidget(_host(isChanged: false));
    expect(find.byType(RecordChangedDot), findsNothing);

    await tester.pumpWidget(_host(isChanged: true));
    expect(find.byType(RecordChangedDot), findsOneWidget);
  });

  testWidgets('the pencil opens the card', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(isChanged: false, onOpen: () => opened++));

    await tester.tap(find.byIcon(Icons.edit_outlined));

    expect(opened, 1);
  });

  testWidgets('the pencil names the card it opens', (tester) async {
    await tester.pumpWidget(_host(isChanged: false));

    expect(
      find.byTooltip(l.recordEdit_editCardTooltip('Notes')),
      findsOneWidget,
    );
  });
}
