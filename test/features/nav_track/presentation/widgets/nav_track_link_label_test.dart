import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_link_label.dart';

void main() {
  testWidgets('an unlinked label is not tappable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NavTrackLinkLabel(label: 'unlinked')),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    expect(find.byKey(const ValueKey('nav-track-link-label')), findsOneWidget);
  });

  testWidgets('a linked label opens the dive on tap', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: NavTrackLinkLabel(label: 'Dive #412', diveId: 'dive-1'),
          ),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (_, state) =>
              Text('dive page ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('Dive #412'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-track-link-label')));
    await tester.pumpAndSettle();

    expect(find.text('dive page dive-1'), findsOneWidget);
  });
}
