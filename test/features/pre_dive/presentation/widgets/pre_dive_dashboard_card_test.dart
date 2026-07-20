import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/pre_dive_dashboard_card.dart';

import '../../../../helpers/test_app.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveSession session() => PreDiveSession(
    id: 's1',
    templateName: 'CCR Build',
    startedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveSessionItem item(int order, PreDiveItemState state) =>
      PreDiveSessionItem(
        id: 'i$order',
        sessionId: 's1',
        title: 'Item $order',
        sortOrder: order,
        state: state,
        createdAt: now,
        updatedAt: now,
      );

  PreDiveChecklistTemplate builtIn() => PreDiveChecklistTemplate(
    id: 'b1',
    name: 'BWRAF',
    isBuiltIn: true,
    builtinKey: 'b1',
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    PreDiveSession? active,
    List<PreDiveSession> sessions = const [],
    List<PreDiveChecklistTemplate>? templates,
    List<PreDiveSessionItem> items = const [],
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => active),
          preDiveSessionsProvider.overrideWith((ref) async => sessions),
          preDiveTemplatesProvider.overrideWith(
            (ref) async => templates ?? [builtIn()],
          ),
          preDiveSessionItemsProvider('s1').overrideWith((ref) async => items),
        ],
        child: const PreDiveDashboardCard(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hidden when unused (built-ins alone do not surface it)', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('Start pre-dive check'), findsNothing);
    expect(find.text('Pre-Dive Check'), findsNothing);
  });

  testWidgets('active session shows Resume with progress', (tester) async {
    final s = session();
    await pumpCard(
      tester,
      active: s,
      sessions: [s],
      items: [
        item(0, PreDiveItemState.done),
        item(1, PreDiveItemState.pending),
        item(2, PreDiveItemState.pending),
      ],
    );
    expect(find.text('Resume - 1 of 3'), findsOneWidget);
  });

  testWidgets('history without an active session shows Start', (tester) async {
    final s = session();
    await pumpCard(tester, sessions: [s]);
    expect(find.text('Start pre-dive check'), findsOneWidget);
  });
}
