import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_templates_page.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';

import '../../../../helpers/test_app.dart';

/// Captures clone/delete calls so the tile's menu actions can be asserted to
/// route through the repository without touching a database.
class _FakeTemplateRepo implements PreDiveTemplateRepository {
  String? clonedId;
  String? cloneName;
  String? cloneDiverId;
  String? deletedId;

  @override
  Future<PreDiveChecklistTemplate> cloneTemplate(
    String templateId, {
    String? diverId,
    required String newName,
  }) async {
    clonedId = templateId;
    cloneName = newName;
    cloneDiverId = diverId;
    return PreDiveChecklistTemplate(
      id: 'clone',
      name: newName,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Future<void> deleteTemplate(String id) async {
    deletedId = id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveChecklistTemplate template(
    String name, {
    bool builtIn = false,
    bool strict = false,
  }) => PreDiveChecklistTemplate(
    id: name,
    name: name,
    isBuiltIn: builtIn,
    builtinKey: builtIn ? name : null,
    strictOrder: strict,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpPage(
    WidgetTester tester,
    List<PreDiveChecklistTemplate> templates,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveTemplatesProvider.overrideWith((ref) async => templates),
        ],
        child: const PreDiveTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps the page with a fake repository + a validated diver id so the
  /// clone/delete flows can run to completion.
  Future<void> pumpPageWithRepo(
    WidgetTester tester,
    List<PreDiveChecklistTemplate> templates,
    _FakeTemplateRepo repo,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveTemplateRepositoryProvider.overrideWithValue(repo),
          preDiveTemplatesProvider.overrideWith((ref) async => templates),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver1'),
        ],
        child: const PreDiveTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders built-in badge and user templates', (tester) async {
    await pumpPage(tester, [
      template('BWRAF Buddy Check', builtIn: true),
      template('My CCR List', strict: true),
    ]);

    expect(find.text('BWRAF Buddy Check'), findsOneWidget);
    expect(find.text('My CCR List'), findsOneWidget);
    expect(find.text('Built-in'), findsOneWidget);
    expect(find.text('Strict order'), findsOneWidget);
  });

  testWidgets('built-in menu offers Clone but not Delete', (tester) async {
    await pumpPage(tester, [template('BWRAF Buddy Check', builtIn: true)]);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Clone'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('user template menu offers Delete', (tester) async {
    await pumpPage(tester, [template('My CCR List')]);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Clone'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('empty state renders', (tester) async {
    await pumpPage(tester, []);
    expect(find.text('No pre-dive checklists yet'), findsOneWidget);
  });

  testWidgets('error state renders the error text', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveTemplatesProvider.overrideWith(
            (ref) async => throw Exception('boom'),
          ),
        ],
        child: const PreDiveTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('choosing Clone routes through cloneTemplate', (tester) async {
    final repo = _FakeTemplateRepo();
    await pumpPageWithRepo(tester, [template('My CCR List')], repo);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clone'));
    await tester.pumpAndSettle();

    expect(repo.clonedId, 'My CCR List');
    expect(repo.cloneName, 'My CCR List (copy)');
    expect(repo.cloneDiverId, 'diver1');
    expect(repo.deletedId, isNull);
  });

  testWidgets('confirming Delete routes through deleteTemplate', (
    tester,
  ) async {
    final repo = _FakeTemplateRepo();
    await pumpPageWithRepo(tester, [template('My CCR List')], repo);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirmation dialog is shown.
    expect(find.text('Delete this checklist template?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deletedId, 'My CCR List');
  });

  testWidgets('cancelling the delete dialog does not delete', (tester) async {
    final repo = _FakeTemplateRepo();
    await pumpPageWithRepo(tester, [template('My CCR List')], repo);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this checklist template?'), findsNothing);
    expect(repo.deletedId, isNull);
  });

  testWidgets('FAB navigates to the new-template route', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PreDiveTemplatesPage()),
        GoRoute(
          path: '/pre-dive-checklists/new',
          builder: (_, _) => const Scaffold(body: Text('NEW PAGE')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          preDiveTemplatesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Template'));
    await tester.pumpAndSettle();

    expect(find.text('NEW PAGE'), findsOneWidget);
  });

  testWidgets('tapping a user template navigates to its edit route', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PreDiveTemplatesPage()),
        GoRoute(
          path: '/pre-dive-checklists/:id/edit',
          builder: (_, state) =>
              Scaffold(body: Text('EDIT ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          preDiveTemplatesProvider.overrideWith(
            (ref) async => [template('My CCR List')],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My CCR List'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT My CCR List'), findsOneWidget);
  });

  testWidgets('tapping a built-in template does not navigate', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PreDiveTemplatesPage()),
        GoRoute(
          path: '/pre-dive-checklists/:id/edit',
          builder: (_, state) =>
              Scaffold(body: Text('EDIT ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          preDiveTemplatesProvider.overrideWith(
            (ref) async => [template('BWRAF Buddy Check', builtIn: true)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BWRAF Buddy Check'));
    await tester.pumpAndSettle();

    // onTap is null for built-ins, so we stay on the list.
    expect(find.text('BWRAF Buddy Check'), findsOneWidget);
    expect(find.textContaining('EDIT'), findsNothing);
  });
}
