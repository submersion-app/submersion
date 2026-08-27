import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/link_session_picker.dart';

import '../../../../helpers/test_app.dart';

/// The dive-side half of manual linking (issue #1066): from a dive, attach a
/// checklist run that was completed the evening before and so fell outside the
/// auto-linker's window.
void main() {
  PreDiveSession session(
    String id, {
    String name = 'CCR Build Check',
    DateTime? startedAt,
    PreDiveSessionStatus status = PreDiveSessionStatus.completed,
  }) {
    final at = startedAt ?? DateTime(2026, 8, 13, 19, 40);
    return PreDiveSession(
      id: id,
      templateName: name,
      status: status,
      startedAt: at,
      createdAt: at,
      updatedAt: at,
    );
  }

  Future<List<String?>> pumpPicker(
    WidgetTester tester, {
    required List<PreDiveSession> unlinked,
    String? diverId,
  }) async {
    final returned = <String?>[];

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveUnlinkedSessionsProvider(
            diverId,
          ).overrideWith((ref) async => unlinked),
        ],
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => returned.add(
              await showLinkSessionPicker(context, diverId: diverId),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    return returned;
  }

  testWidgets('lists unlinked runs with their name and date', (tester) async {
    await pumpPicker(
      tester,
      unlinked: [
        session('s1'),
        session('s2', name: 'BWRAF', startedAt: DateTime(2026, 8, 10, 7, 15)),
      ],
    );

    expect(find.text('Link pre-dive checklist'), findsOneWidget);
    expect(find.text('CCR Build Check'), findsOneWidget);
    expect(find.text('BWRAF'), findsOneWidget);
  });

  testWidgets('choosing a run closes the picker and returns its id', (
    tester,
  ) async {
    final returned = await pumpPicker(tester, unlinked: [session('s1')]);

    await tester.tap(find.text('CCR Build Check'));
    await tester.pumpAndSettle();

    expect(returned, ['s1']);
  });

  testWidgets('no unlinked runs says so instead of showing an empty list', (
    tester,
  ) async {
    await pumpPicker(tester, unlinked: []);

    expect(find.text('No unlinked checklist runs'), findsOneWidget);
  });

  testWidgets('the diver scope is passed through to the query', (tester) async {
    // Sessions are diver-scoped by exact match, matching the auto-linker, so
    // the picker must ask for the dive's diver rather than the whole history.
    await pumpPicker(
      tester,
      diverId: 'diver-7',
      unlinked: [session('s1', name: 'Diver 7 Run')],
    );

    expect(find.text('Diver 7 Run'), findsOneWidget);
  });

  testWidgets('dismissing without choosing returns null', (tester) async {
    final returned = await pumpPicker(tester, unlinked: [session('s1')]);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(returned, [null]);
  });
}
