import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_text_section.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The legacy buddy text's link action (#1831), as the open Buddies card
/// offers it (issue #4527): a second tap while a link is under way is
/// ignored, so a second review sheet never opens over the first.
void main() {
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 3, 9),
    buddy: 'Bob Brown',
  );

  testWidgets('a second tap while the link runs is ignored', (tester) async {
    var calls = 0;
    var gate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LegacyBuddyTextSection(
            dive: dive,
            onLink: (_) {
              calls++;
              return gate.future;
            },
          ),
        ),
      ),
    );
    final link = find.text('Link to buddy records');

    await tester.tap(link);
    await tester.pump();
    await tester.tap(link, warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);

    // Once the link has finished, the action is offered again.
    gate.complete();
    await tester.pump();
    gate = Completer<void>();
    await tester.tap(link);
    await tester.pump();
    expect(calls, 2);
    gate.complete();
    await tester.pump();
  });
}
