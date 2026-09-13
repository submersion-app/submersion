import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/missing_dives_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(ImportNotice notice) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: MissingDivesCard(notice: notice)),
);

void main() {
  testWidgets('refuses a notice about dives that did import', (tester) async {
    // Only kinds that report missing dives have wording here. Showing any
    // other kind in this card would dress a footnote up as a failure.
    await tester.pumpWidget(
      _host(
        const ImportNotice(kind: ImportNoticeKind.noTankPressure, count: 1),
      ),
    );

    expect(tester.takeException(), isA<ArgumentError>());
  });

  testWidgets('shows skipped dives without a row line', (tester) async {
    // Skipped dives did not come from spreadsheet rows, so there are none to
    // name.
    await tester.pumpWidget(
      _host(const ImportNotice(kind: ImportNoticeKind.divesSkipped, count: 2)),
    );

    expect(find.text('2 dives skipped'), findsOneWidget);
    expect(find.textContaining('Row'), findsNothing);
  });
}
