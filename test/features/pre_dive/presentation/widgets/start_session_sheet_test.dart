import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/start_session_sheet.dart';

import '../../../../helpers/test_app.dart';

/// Serves canned template items so selecting a template in the sheet can
/// reveal (or not) the equipment-set picker.
class _FakeTemplateRepo implements PreDiveTemplateRepository {
  final Map<String, List<PreDiveChecklistTemplateItem>> itemsByTemplate;

  _FakeTemplateRepo(this.itemsByTemplate);

  @override
  Future<List<PreDiveChecklistTemplateItem>> getItemsForTemplate(
    String templateId,
  ) async => itemsByTemplate[templateId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Captures the composed start-session call so the begin flow can be asserted
/// without a database.
class _FakeSessionRepo implements PreDiveSessionRepository {
  int startCalls = 0;
  PreDiveChecklistTemplate? capturedTemplate;
  List<PreDiveSessionItem>? capturedItems;
  String? capturedDiverId;
  String? capturedDiveId;
  String? capturedEquipmentSetId;
  String? capturedEquipmentSetName;

  @override
  Future<PreDiveSession> startSession({
    required PreDiveChecklistTemplate template,
    required List<PreDiveSessionItem> items,
    String? diverId,
    String? diveId,
    String? tripId,
    String? equipmentSetId,
    String? equipmentSetName,
  }) async {
    startCalls++;
    capturedTemplate = template;
    capturedItems = items;
    capturedDiverId = diverId;
    capturedDiveId = diveId;
    capturedEquipmentSetId = equipmentSetId;
    capturedEquipmentSetName = equipmentSetName;
    return PreDiveSession(
      id: 'newsession',
      templateName: template.name,
      startedAt: DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveChecklistTemplate template(String id, String name) =>
      PreDiveChecklistTemplate(
        id: id,
        name: name,
        createdAt: now,
        updatedAt: now,
      );

  PreDiveChecklistTemplateItem tItem(String templateId, PreDiveItemType type) =>
      PreDiveChecklistTemplateItem(
        id: '$templateId-i',
        templateId: templateId,
        title: 'T',
        itemType: type,
        createdAt: now,
        updatedAt: now,
      );

  final defaultSet = EquipmentSet(
    id: 'set1',
    name: 'Warm water rig',
    isDefault: true,
    equipmentIds: const ['g1'],
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpSheet(WidgetTester tester) async {
    final fakeRepo = _FakeTemplateRepo({
      'plain': [tItem('plain', PreDiveItemType.check)],
      'packing': [tItem('packing', PreDiveItemType.equipmentSet)],
    });
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveTemplateRepositoryProvider.overrideWithValue(fakeRepo),
          preDiveTemplatesProvider.overrideWith(
            (ref) async => [
              template('plain', 'BWRAF'),
              template('packing', 'Gear Packing'),
            ],
          ),
          equipmentSetsProvider.overrideWith((ref) async => [defaultSet]),
        ],
        child: Builder(
          builder: (context) => Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () => showStartSessionSheet(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'equipment picker appears only for equipmentSet-bearing templates',
    (tester) async {
      await pumpSheet(tester);
      expect(find.text('Start pre-dive checklist'), findsOneWidget);
      expect(find.text('Equipment set'), findsNothing);

      // Choose the plain template: still no equipment picker.
      await tester.tap(find.text('Checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BWRAF').last);
      await tester.pumpAndSettle();
      expect(find.text('Equipment set'), findsNothing);

      // Choose the packing template: picker appears with the default set
      // pre-selected.
      await tester.tap(find.text('BWRAF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gear Packing').last);
      await tester.pumpAndSettle();
      expect(find.text('Equipment set'), findsOneWidget);
      expect(find.text('Warm water rig'), findsOneWidget);
    },
  );

  testWidgets('Begin disabled until a template is chosen', (tester) async {
    await pumpSheet(tester);
    final begin = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Begin'),
    );
    expect(begin.onPressed, isNull);
  });

  /// Opens the sheet inside a GoRouter so the post-start `context.push` to the
  /// runner resolves. Returns the fake session repo for assertions.
  Future<_FakeSessionRepo> pumpSheetForBegin(WidgetTester tester) async {
    final fakeTemplateRepo = _FakeTemplateRepo({
      'plain': [tItem('plain', PreDiveItemType.check)],
      'packing': [tItem('packing', PreDiveItemType.equipmentSet)],
    });
    final fakeSessionRepo = _FakeSessionRepo();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => showStartSessionSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/pre-dive-sessions/:id',
          builder: (_, state) =>
              Scaffold(body: Text('SESSION ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          preDiveTemplateRepositoryProvider.overrideWithValue(fakeTemplateRepo),
          preDiveSessionRepositoryProvider.overrideWithValue(fakeSessionRepo),
          preDiveTemplatesProvider.overrideWith(
            (ref) async => [
              template('plain', 'BWRAF'),
              template('packing', 'Gear Packing'),
            ],
          ),
          equipmentSetsProvider.overrideWith((ref) async => [defaultSet]),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver1'),
        ],
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return fakeSessionRepo;
  }

  testWidgets('Begin composes items and starts a session, then navigates', (
    tester,
  ) async {
    final repo = await pumpSheetForBegin(tester);

    // Choose the plain template (no equipment set involved).
    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BWRAF').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Begin'));
    await tester.pumpAndSettle();

    expect(repo.startCalls, 1);
    expect(repo.capturedTemplate?.id, 'plain');
    expect(repo.capturedDiverId, 'diver1');
    expect(repo.capturedItems, isNotEmpty);
    // Plain template carries no equipment set.
    expect(repo.capturedEquipmentSetId, isNull);
    expect(repo.capturedEquipmentSetName, isNull);
    // The runner route was pushed with the new session id.
    expect(find.text('SESSION newsession'), findsOneWidget);
  });

  testWidgets(
    'Begin on an equipmentSet template with no set chosen omits the set',
    (tester) async {
      final repo = await pumpSheetForBegin(tester);

      // Choose the packing template: the equipment picker appears with the
      // default set pre-selected.
      await tester.tap(find.text('Checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gear Packing').last);
      await tester.pumpAndSettle();
      expect(find.text('Equipment set'), findsOneWidget);

      // Switch the equipment set to None so the gear-loading branch is
      // skipped (avoids hitting the concrete EquipmentRepository/database).
      await tester.tap(find.text('Warm water rig'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Begin'));
      await tester.pumpAndSettle();

      expect(repo.startCalls, 1);
      expect(repo.capturedTemplate?.id, 'packing');
      expect(repo.capturedEquipmentSetId, isNull);
      expect(repo.capturedEquipmentSetName, isNull);
      // The equipmentSet item degrades to a plain check row.
      expect(repo.capturedItems, isNotEmpty);
      expect(find.text('SESSION newsession'), findsOneWidget);
    },
  );
}
