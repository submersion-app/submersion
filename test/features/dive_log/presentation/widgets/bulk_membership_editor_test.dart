import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_membership_editor.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  // a is on all 3 dives, b on 2 of 3, c on none (just added via the picker).
  const items = [
    BulkMembershipItem(id: 'a', label: 'Regulator'),
    BulkMembershipItem(id: 'b', label: 'Wetsuit'),
    BulkMembershipItem(id: 'c', label: 'Camera'),
  ];
  const counts = {'a': 3, 'b': 2, 'c': 0};

  Future<void> pumpEditor(
    WidgetTester tester, {
    void Function(MembershipDelta)? onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BulkMembershipEditor(
            title: 'Equipment',
            totalDives: 3,
            items: items,
            counts: counts,
            onAdd: () {},
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a presence subtitle per row', (tester) async {
    await pumpEditor(tester);
    expect(find.text('on all 3'), findsOneWidget); // a
    expect(find.text('on 2 of 3'), findsOneWidget); // b
    expect(find.text('adding to all 3'), findsOneWidget); // c (just added)
  });

  testWidgets('unchecking an on-all item yields a remove', (tester) async {
    MembershipDelta? last;
    await pumpEditor(tester, onChanged: (d) => last = d);
    await tester.tap(find.byKey(const ValueKey('membership-toggle-a')));
    await tester.pump();
    expect(last!.removeIds, contains('a'));
    expect(find.text('removing from all'), findsOneWidget);
  });

  testWidgets('a some-item is left unchanged; an added item is an add', (
    tester,
  ) async {
    MembershipDelta? last;
    await pumpEditor(tester, onChanged: (d) => last = d);
    // Baseline emitted post-frame: c (none) -> add; a (all) and b (some) no-op.
    expect(last, isNotNull);
    expect(last!.addIds, contains('c'));
    expect(last!.addIds, isNot(contains('b')));
    expect(last!.removeIds, isNot(contains('b')));
  });

  testWidgets('a some-item cycles leave -> add -> remove -> leave', (
    tester,
  ) async {
    MembershipDelta? last;
    await pumpEditor(tester, onChanged: (d) => last = d);
    final toggleB = find.byKey(const ValueKey('membership-toggle-b'));

    await tester.tap(toggleB); // -> ensureOn
    await tester.pump();
    expect(last!.addIds, contains('b'));

    await tester.tap(toggleB); // -> ensureOff
    await tester.pump();
    expect(last!.removeIds, contains('b'));
    expect(last!.addIds, isNot(contains('b')));

    await tester.tap(toggleB); // -> leaveAsIs
    await tester.pump();
    expect(last!.addIds, isNot(contains('b')));
    expect(last!.removeIds, isNot(contains('b')));
  });

  testWidgets(
    'unchecking a just-added item is a no-op with no false subtitle',
    (tester) async {
      MembershipDelta? last;
      await pumpEditor(tester, onChanged: (d) => last = d);
      // c (on no dives) starts checked -> "adding to all 3".
      expect(find.text('adding to all 3'), findsOneWidget);

      // Toggle c off: it changes nothing, so the subtitle must not still claim
      // "adding to all", and c must not appear in the delta.
      await tester.tap(find.byKey(const ValueKey('membership-toggle-c')));
      await tester.pump();
      expect(find.text('adding to all 3'), findsNothing);
      expect(last!.addIds, isNot(contains('c')));
      expect(last!.removeIds, isNot(contains('c')));
    },
  );
}
