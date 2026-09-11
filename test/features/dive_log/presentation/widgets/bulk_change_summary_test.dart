import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_change_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_membership_editor.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  const equipment = [
    BulkMembershipItem(id: 'e1', label: 'Wing'),
    BulkMembershipItem(id: 'e2', label: 'DSMB'),
    BulkMembershipItem(id: 'e3', label: 'camera'),
    BulkMembershipItem(id: 'e4', label: 'Knife'),
  ];
  const tags = [BulkMembershipItem(id: 't1', label: 'Nitrox')];

  group('summarizeBulkMembership', () {
    test('names the adds and removes of each changed collection', () {
      final sections = summarizeBulkMembership([
        (
          title: 'Tags',
          delta: const MembershipDelta([], ['t1']),
          members: tags,
        ),
        (
          title: 'Equipment',
          delta: const MembershipDelta(['e4'], ['e2', 'e3', 'e1']),
          members: equipment,
        ),
      ]);

      expect(sections.map((s) => s.title), ['Tags', 'Equipment']);
      expect(sections[0].added, isEmpty);
      expect(sections[0].removed, ['Nitrox']);
      expect(sections[1].added, ['Knife']);
      // Sorted case-insensitively, so the diver can scan for a name.
      expect(sections[1].removed, ['camera', 'DSMB', 'Wing']);
    });

    test('leaves out a collection with no change', () {
      final sections = summarizeBulkMembership([
        (title: 'Tags', delta: MembershipDelta.empty, members: tags),
        (
          title: 'Equipment',
          delta: const MembershipDelta(['e4'], []),
          members: equipment,
        ),
      ]);

      expect(sections.map((s) => s.title), ['Equipment']);
    });

    test('falls back to the id for an item with no listed row', () {
      final sections = summarizeBulkMembership([
        (
          title: 'Equipment',
          delta: const MembershipDelta(['gone'], []),
          members: equipment,
        ),
      ]);

      expect(sections.single.added, ['gone']);
    });
  });

  group('BulkChangeSummary', () {
    Future<void> pumpSummary(
      WidgetTester tester,
      List<BulkChangeSection> sections,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BulkChangeSummary(sections: sections, totalDives: 19),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows what is added to and removed from every dive', (
      tester,
    ) async {
      await pumpSummary(tester, const [
        BulkChangeSection(
          title: 'Equipment',
          added: ['Knife'],
          removed: ['DSMB', 'Wing'],
        ),
      ]);

      expect(find.text('Equipment'), findsOneWidget);
      expect(find.text('Adding to all 19 dives'), findsOneWidget);
      expect(find.text('Knife'), findsOneWidget);
      expect(find.text('Removing from all 19 dives'), findsOneWidget);
      expect(find.text('DSMB, Wing'), findsOneWidget);
    });

    testWidgets('omits the heading of an empty side', (tester) async {
      await pumpSummary(tester, const [
        BulkChangeSection(title: 'Tags', added: [], removed: ['Nitrox']),
      ]);

      expect(find.text('Adding to all 19 dives'), findsNothing);
      expect(find.text('Removing from all 19 dives'), findsOneWidget);
    });
  });
}
