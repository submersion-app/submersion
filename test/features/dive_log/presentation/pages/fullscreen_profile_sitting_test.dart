import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Every annotation read fails.
class _FailingAnnotations extends AnnotationRepository {
  @override
  Future<List<ProfileEvent>> annotationsForDive(String diveId) async =>
      throw StateError('database closed');
}

/// The fullscreen profile obeys the dive's lock: it edits a sitting only
/// when opened from the open Profile card (issue #4527, plan 6).
void main() {
  late DiveRepository repository;
  late String? previousLocale;
  const diveId = 'dive-full';

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
    repository = DiveRepository();
    await repository.createDive(
      Dive(
        id: diveId,
        dateTime: DateTime.utc(2026, 5, 3, 10),
        runtime: const Duration(seconds: 1200),
        maxDepth: 30,
        profile: List.generate(
          41,
          (i) => DiveProfilePoint(timestamp: i * 30, depth: i < 20 ? 30 : 10),
        ),
        notes: 'First.\n\n[felt sick](annotation:a1)',
      ),
    );
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO dive_profile_events '
      '(id, dive_id, timestamp, event_type, source, description, depth, '
      'created_at) '
      "VALUES ('a1', '$diveId', 300, 'annotation', 'user', 'felt sick', 30, 1)",
    );
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<ProviderContainer> pumpPage(
    WidgetTester tester, {
    EditSession<Dive>? session,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(const AppSettings()),
          ),
          diveRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FullscreenProfilePage(diveId: diveId, session: session),
                  ),
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    return container;
  }

  Finder pin() => find.byTooltip('Add annotation');

  /// Taps the one annotation's dot, opening its popup.
  Future<void> tapDot(WidgetTester tester) async {
    final layerFinder = find.byType(AnnotationMarkerLayer);
    final layer = tester.widget<AnnotationMarkerLayer>(layerFinder);
    final center = annotationDotCenters(
      annotations: layer.annotations,
      size: tester.getSize(layerFinder),
      insets: layer.insets,
      visibleMinSeconds: layer.visibleMinSeconds,
      visibleMaxSeconds: layer.visibleMaxSeconds,
      visibleMinDepth: layer.visibleMinDepth,
      visibleMaxDepth: layer.visibleMaxDepth,
      depthAt: layer.depthAt,
    ).single!;
    await tester.tapAt(tester.getTopLeft(layerFinder) + center);
    await settle(tester, frames: 4);
  }

  // Annotations are placed only in a sitting (issue #4527).
  testWidgets('without a sitting: read only, no pin', (tester) async {
    await pumpPage(tester);
    expect(find.byType(AnnotationMarkerLayer), findsOneWidget);
    expect(pin(), findsNothing);
  });

  testWidgets("with a sitting: its pin, and the sitting's annotations are "
      'drawn', (tester) async {
    final dive = (await tester.runAsync(() => repository.getDiveById(diveId)))!;
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    loadDiveAnnotations(session, container.read);
    await tester.runAsync(session.settled);
    moveSittingAnnotation(session, 'a1', seconds: 900, depth: 10);

    await pumpPage(tester, session: session);
    expect(pin(), findsOneWidget);
    final layer = tester.widget<AnnotationMarkerLayer>(
      find.byType(AnnotationMarkerLayer),
    );
    expect(layer.annotations.single.timestamp, 900);

    // A change made meanwhile is drawn too.
    placeAnnotation(session, seconds: 600, words: 'manta');
    await settle(tester, frames: 3);
    expect(
      tester
          .widget<AnnotationMarkerLayer>(find.byType(AnnotationMarkerLayer))
          .annotations,
      hasLength(2),
    );
  });

  testWidgets('with a sitting whose annotations could not be read: no pin, '
      'as a pin would go nowhere', (tester) async {
    final dive = (await tester.runAsync(() => repository.getDiveById(diveId)))!;
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    final container = ProviderContainer(
      overrides: [
        annotationRepositoryProvider.overrideWithValue(_FailingAnnotations()),
      ],
    );
    addTearDown(container.dispose);
    loadDiveAnnotations(session, container.read);
    await tester.runAsync(session.settled);
    expect(annotationsLoadFailed(session), isTrue);

    await pumpPage(tester, session: session);
    expect(pin(), findsNothing);

    // Nor can a stored marker be moved or removed: it would go nowhere.
    await tapDot(tester);
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('with a sitting that has ended: writes nothing, rather than '
      'straight to the database', (tester) async {
    final dive = (await tester.runAsync(() => repository.getDiveById(diveId)))!;
    final session = EditSession<Dive>(dive);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    loadDiveAnnotations(session, container.read);
    await tester.runAsync(session.settled);
    await pumpPage(tester, session: session);
    expect(pin(), findsOneWidget);

    // The sitting ends underneath the page, which then draws again.
    session.dispose();
    tester.element(find.byType(FullscreenProfilePage)).markNeedsBuild();
    await settle(tester, frames: 2);

    expect(pin(), findsNothing);
    await tapDot(tester);
    expect(find.text('Remove'), findsNothing);
  });
}
