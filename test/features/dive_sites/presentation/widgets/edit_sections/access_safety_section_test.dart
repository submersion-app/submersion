import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The site edit page's "Access & safety" section (issue #1037).
///
/// The detail page and this edit section have to agree on the order a diver
/// needs the information in: where to park, how to get in, which buoy. The
/// detail side is covered by site_detail_page_test.dart; this covers the edit
/// side so a future reorder of one cannot silently drift from the other.
void main() {
  late TextEditingController accessNotes;
  late TextEditingController mooringNumber;
  late TextEditingController parkingInfo;
  late TextEditingController hazards;

  setUp(() {
    accessNotes = TextEditingController();
    mooringNumber = TextEditingController();
    parkingInfo = TextEditingController();
    hazards = TextEditingController();
  });

  tearDown(() {
    accessNotes.dispose();
    mooringNumber.dispose();
    parkingInfo.dispose();
    hazards.dispose();
  });

  Widget harness() => MaterialApp(
    // The assertions match on the English labels, so the platform locale of
    // the test runner must not decide them.
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: AccessSafetySection(
          expanded: true,
          onToggle: () {},
          summary: '',
          isEmpty: false,
          accessNotesController: accessNotes,
          mooringNumberController: mooringNumber,
          parkingInfoController: parkingInfo,
          hazardsController: hazards,
          entryMethod: EntryMethod.shore,
          exitMethod: EntryMethod.boat,
          onEntryMethodChanged: (_) {},
          onExitMethodChanged: (_) {},
        ),
      ),
    ),
  );

  testWidgets(
    'fields run parking, access notes, entry, exit, mooring, hazards (#1037)',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      double topOf(String label) => tester.getTopLeft(find.text(label)).dy;

      final order = [
        'Parking Information',
        'Access Notes',
        'Entry Method',
        'Exit Method',
        'Mooring Number',
        'Hazards',
      ];
      for (final label in order) {
        expect(find.text(label), findsOneWidget, reason: '$label is missing');
      }

      final tops = order.map(topOf).toList();
      for (var i = 1; i < order.length; i++) {
        expect(
          tops[i - 1],
          lessThan(tops[i]),
          reason: '${order[i - 1]} must sit above ${order[i]}',
        );
      }
    },
  );
}
