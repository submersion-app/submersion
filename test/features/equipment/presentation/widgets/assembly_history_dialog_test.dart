import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The swap-with-history question (issue #1487): names the count and the
/// change, defaults to "from now on", and returns null when dismissed.
void main() {
  Future<Future<AssemblyHistoryChoice?>> open(
    WidgetTester tester, {
    required int count,
    required AssemblyHistoryChange change,
  }) async {
    final completer = Completer<Future<AssemblyHistoryChoice?>>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => completer.complete(
              showAssemblyHistoryDialog(
                context,
                pastDiveCount: count,
                change: change,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return completer.future;
  }

  testWidgets('names the count and the change, from now on is the default', (
    tester,
  ) async {
    final result = await open(
      tester,
      count: 3,
      change: AssemblyHistoryChange.added,
    );
    expect(find.text('Update past dives?'), findsOneWidget);
    expect(
      find.textContaining('This assembly is on 3 logged dives.'),
      findsOneWidget,
    );
    expect(find.textContaining('Add the new part'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'From now on'), findsOneWidget);
    await tester.tap(find.text('From now on'));
    await tester.pumpAndSettle();
    expect(await result, AssemblyHistoryChoice.futureOnly);
  });

  testWidgets('also update N returns alsoPast, singular at one', (
    tester,
  ) async {
    final result = await open(
      tester,
      count: 1,
      change: AssemblyHistoryChange.replaced,
    );
    expect(
      find.textContaining('This assembly is on 1 logged dive.'),
      findsOneWidget,
    );
    expect(find.textContaining('Swap the part'), findsOneWidget);
    await tester.tap(find.text('Also update 1 dive'));
    await tester.pumpAndSettle();
    expect(await result, AssemblyHistoryChoice.alsoPast);
  });

  testWidgets('dismissing returns null', (tester) async {
    final result = await open(
      tester,
      count: 2,
      change: AssemblyHistoryChange.removed,
    );
    expect(find.textContaining('Remove the part'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
