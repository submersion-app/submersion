import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';

/// Serves canned data so each provider body runs its real logic (watch +
/// diver-id resolution + repository fetch) instead of being replaced wholesale.
class _FakeTemplateRepo implements PreDiveTemplateRepository {
  final List<PreDiveChecklistTemplate> templates;
  final PreDiveChecklistTemplate? template;
  final List<PreDiveChecklistTemplateItem> items;

  _FakeTemplateRepo({
    this.templates = const [],
    this.template,
    this.items = const [],
  });

  @override
  Stream<void> watchTemplatesChanges() => const Stream<void>.empty();

  @override
  Future<List<PreDiveChecklistTemplate>> getAllTemplates({
    String? diverId,
  }) async => templates;

  @override
  Future<PreDiveChecklistTemplate?> getTemplateById(String id) async =>
      template;

  @override
  Future<List<PreDiveChecklistTemplateItem>> getItemsForTemplate(
    String templateId,
  ) async => items;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionRepo implements PreDiveSessionRepository {
  final List<PreDiveSession> sessions;
  final PreDiveSession? active;
  final PreDiveSession? byId;
  final List<PreDiveSessionItem> items;
  final PreDiveSession? forDive;

  _FakeSessionRepo({
    this.sessions = const [],
    this.active,
    this.byId,
    this.items = const [],
    this.forDive,
  });

  @override
  Stream<void> watchSessionsChanges() => const Stream<void>.empty();

  @override
  Future<List<PreDiveSession>> getAllSessions({String? diverId}) async =>
      sessions;

  @override
  Future<PreDiveSession?> getActiveSession({String? diverId}) async => active;

  @override
  Future<PreDiveSession?> getSessionById(String id) async => byId;

  @override
  Future<List<PreDiveSessionItem>> getItemsForSession(String sessionId) async =>
      items;

  @override
  Future<PreDiveSession?> getSessionForDive(String diveId) async => forDive;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveChecklistTemplate template(String id) => PreDiveChecklistTemplate(
    id: id,
    name: id,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveChecklistTemplateItem tItem(String id) => PreDiveChecklistTemplateItem(
    id: id,
    templateId: 't1',
    title: id,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveSession session(String id) => PreDiveSession(
    id: id,
    templateName: 'BWRAF',
    startedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveSessionItem sItem(String id) => PreDiveSessionItem(
    id: id,
    sessionId: 's1',
    title: id,
    createdAt: now,
    updatedAt: now,
  );

  ProviderContainer makeContainer({
    _FakeTemplateRepo? templateRepo,
    _FakeSessionRepo? sessionRepo,
    String? diverId = 'diver1',
  }) {
    final container = ProviderContainer(
      overrides: [
        preDiveTemplateRepositoryProvider.overrideWithValue(
          templateRepo ?? _FakeTemplateRepo(),
        ),
        preDiveSessionRepositoryProvider.overrideWithValue(
          sessionRepo ?? _FakeSessionRepo(),
        ),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('template repository providers default to real instances', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(preDiveTemplateRepositoryProvider),
      isA<PreDiveTemplateRepository>(),
    );
    expect(
      container.read(preDiveSessionRepositoryProvider),
      isA<PreDiveSessionRepository>(),
    );
  });

  test('preDiveTemplatesProvider resolves diver id then fetches all', () async {
    final container = makeContainer(
      templateRepo: _FakeTemplateRepo(templates: [template('t1')]),
    );
    final out = await container.read(preDiveTemplatesProvider.future);
    expect(out.single.id, 't1');
  });

  test('preDiveTemplateProvider fetches one by id', () async {
    final container = makeContainer(
      templateRepo: _FakeTemplateRepo(template: template('t9')),
    );
    final out = await container.read(preDiveTemplateProvider('t9').future);
    expect(out?.id, 't9');
  });

  test('preDiveTemplateItemsProvider fetches items for a template', () async {
    final container = makeContainer(
      templateRepo: _FakeTemplateRepo(items: [tItem('ti1'), tItem('ti2')]),
    );
    final out = await container.read(preDiveTemplateItemsProvider('t1').future);
    expect(out.map((i) => i.id), ['ti1', 'ti2']);
  });

  test('preDiveSessionsProvider resolves diver id then fetches all', () async {
    final container = makeContainer(
      sessionRepo: _FakeSessionRepo(sessions: [session('s1')]),
    );
    final out = await container.read(preDiveSessionsProvider.future);
    expect(out.single.id, 's1');
  });

  test('preDiveActiveSessionProvider returns the active session', () async {
    final container = makeContainer(
      sessionRepo: _FakeSessionRepo(active: session('active')),
    );
    final out = await container.read(preDiveActiveSessionProvider.future);
    expect(out?.id, 'active');
  });

  test('preDiveActiveSessionProvider returns null when none active', () async {
    final container = makeContainer(sessionRepo: _FakeSessionRepo());
    expect(await container.read(preDiveActiveSessionProvider.future), isNull);
  });

  test('preDiveSessionProvider fetches one by id', () async {
    final container = makeContainer(
      sessionRepo: _FakeSessionRepo(byId: session('s5')),
    );
    final out = await container.read(preDiveSessionProvider('s5').future);
    expect(out?.id, 's5');
  });

  test('preDiveSessionItemsProvider fetches items for a session', () async {
    final container = makeContainer(
      sessionRepo: _FakeSessionRepo(items: [sItem('a'), sItem('b')]),
    );
    final out = await container.read(preDiveSessionItemsProvider('s1').future);
    expect(out.map((i) => i.id), ['a', 'b']);
  });

  test('preDiveSessionForDiveProvider fetches the linked session', () async {
    final container = makeContainer(
      sessionRepo: _FakeSessionRepo(forDive: session('linked')),
    );
    final out = await container.read(
      preDiveSessionForDiveProvider('d1').future,
    );
    expect(out?.id, 'linked');
  });
}
