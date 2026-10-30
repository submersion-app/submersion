import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/media_people_chips_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

MediaPersonTag tag(
  String id, {
  String? buddyId,
  String? diverId,
  Duration? at,
}) => MediaPersonTag(
  id: id,
  mediaId: 'm1',
  buddyId: buddyId,
  diverId: diverId,
  videoPosition: at,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

void main() {
  Future<GoRouter> pump(
    WidgetTester tester,
    List<MediaPersonChip> chips, {
    ValueChanged<MediaPersonTag>? onMomentTap,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: MediaPeopleChipsRow(mediaId: 'm1', onMomentTap: onMomentTap),
          ),
        ),
        GoRoute(
          path: '/buddies/:id',
          builder: (_, s) => Text('BUDDY ${s.pathParameters['id']}'),
        ),
        GoRoute(path: '/media', builder: (_, _) => const Text('LIBRARY')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaPeopleChipsProvider('m1').overrideWith((ref) async => chips),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('renders nothing when nobody is tagged', (tester) async {
    await pump(tester, const []);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('Me comes first, then buddies, with a moment label', (
    tester,
  ) async {
    await pump(tester, [
      MediaPersonChip(tag: tag('t0', diverId: 'A')),
      MediaPersonChip(
        tag: tag('t1', buddyId: 'alex', at: const Duration(seconds: 42)),
        buddyName: 'Alex',
      ),
    ]);
    final labels = tester
        .widgetList<ActionChip>(find.byType(ActionChip))
        .map((c) => (c.label as Text).data)
        .toList();
    expect(labels, ['Me', 'Alex · 0:42']);
  });

  testWidgets('tapping a buddy chip opens the buddy', (tester) async {
    await pump(tester, [
      MediaPersonChip(
        tag: tag('t1', buddyId: 'alex'),
        buddyName: 'Alex',
      ),
    ]);
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.text('BUDDY alex'), findsOneWidget);
  });

  testWidgets('a buddy chip over a pushed viewer opens the buddy on top', (
    tester,
  ) async {
    final router = await pump(tester, const []);
    // The viewer is pushed imperatively, above the router's page.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ProviderScope(
            overrides: [
              mediaPeopleChipsProvider('m1').overrideWith(
                (ref) async => [
                  MediaPersonChip(
                    tag: tag('t1', buddyId: 'alex'),
                    buddyName: 'Alex',
                  ),
                ],
              ),
            ],
            child: const Scaffold(body: MediaPeopleChipsRow(mediaId: 'm1')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();

    expect(find.text('BUDDY alex'), findsOneWidget);
    expect(router.state.uri.path, '/buddies/alex');
  });

  testWidgets('tapping a moment chip reports the moment', (tester) async {
    MediaPersonTag? tapped;
    final moment = tag('t1', buddyId: 'alex', at: const Duration(seconds: 42));
    await pump(tester, [
      MediaPersonChip(tag: moment, buddyName: 'Alex'),
    ], onMomentTap: (t) => tapped = t);
    await tester.tap(find.text('Alex · 0:42'));
    await tester.pumpAndSettle();
    expect(tapped, moment);
  });

  testWidgets('tapping Me opens the library filtered to Me', (tester) async {
    await pump(tester, [MediaPersonChip(tag: tag('t0', diverId: 'A'))]);
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('LIBRARY'), findsOneWidget);
  });
}
