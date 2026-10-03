import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';

import '../../../helpers/test_app.dart';

Widget app() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: SizedBox(height: 400, child: QuickActionsCard()),
        ),
      ),
      GoRoute(
        path: '/tracks',
        builder: (context, state) => const Scaffold(body: Text('TRACKS-PAGE')),
      ),
    ],
  );
  return testAppRouter(router: router);
}

void main() {
  testWidgets('GPS Logger quick action navigates to /tracks', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('GPS Logger'));
    await tester.pumpAndSettle();
    expect(find.text('TRACKS-PAGE'), findsOneWidget);
  });

  testWidgets('there is no Underwater Routes quick action', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.route), findsNothing);
  });

  testWidgets('offers no Underwater Routes quick action', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Underwater Routes'), findsNothing);
    expect(find.byIcon(Icons.route), findsNothing);
  });
}
