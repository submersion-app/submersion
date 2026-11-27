import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

Widget _host(RecordCardFrameData? frame) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: RecordCardFrameScope(
      data: frame,
      child: const DiveAltitudeMismatchNote(),
    ),
  ),
);

/// The altitude mismatch note opens the Altitude card while its dive is
/// unlocked, with the same pencil every other card shows (issue #4527).
void main() {
  testWidgets('locked, it shows no pencil', (tester) async {
    await tester.pumpWidget(_host(null));

    expect(find.byType(RecordPencilDisc), findsNothing);
  });

  testWidgets('unlocked, the shared pencil, and a tap opens the card', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        RecordCardFrameData(
          isOpen: false,
          isChanged: false,
          onOpen: () => opened++,
          onDone: () {},
        ),
      ),
    );

    expect(find.byType(RecordPencilDisc), findsOneWidget);
    await tester.tap(find.byType(DiveAltitudeMismatchNote));
    expect(opened, 1);
    // The pencil itself is part of the note's tap, not a target of its own.
    await tester.tap(find.byType(RecordPencilDisc));
    expect(opened, 2);
  });
}
