import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_bulk_membership_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

/// The dive bulk editor keeps its own wording after the editor moved to
/// lib/shared (issue #1942).
void main() {
  const rows = [
    BulkMembershipItem(id: 'a', label: 'Nitrox'),
    BulkMembershipItem(id: 'b', label: 'Night'),
    BulkMembershipItem(id: 'c', label: 'Wreck'),
  ];
  const counts = {'a': 3, 'b': 2, 'c': 0};

  Future<void> pumpEditor(
    WidgetTester tester, {
    required Locale locale,
    List<BulkMembershipItem> items = rows,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => BulkMembershipEditor(
              title: 'Tags',
              total: 3,
              labels: diveBulkMembershipLabels(context.l10n),
              items: items,
              counts: counts,
              onAdd: () {},
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('rows read as they did on the dive page', (tester) async {
    await pumpEditor(tester, locale: const Locale('en'));

    expect(find.text('on all 3'), findsOneWidget);
    expect(find.text('on 2 of 3'), findsOneWidget);
    expect(find.text('adding to all 3'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Add'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('membership-toggle-a')));
    await tester.pump();
    expect(find.text('removing from all'), findsOneWidget);
  });

  testWidgets('an empty collection keeps the dive empty state', (tester) async {
    await pumpEditor(tester, locale: const Locale('en'), items: const []);
    expect(find.text('No items on the selected dives yet'), findsOneWidget);
  });

  testWidgets('a translated locale keeps its dive wording', (tester) async {
    await pumpEditor(tester, locale: const Locale('de'));

    expect(find.text('auf allen 3'), findsOneWidget);
    expect(find.text('auf 2 von 3'), findsOneWidget);
    expect(find.text('wird zu allen 3 hinzugefügt'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Hinzufügen'), findsOneWidget);
  });
}
