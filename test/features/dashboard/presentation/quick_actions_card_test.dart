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
        path: '/gps-log',
        builder: (context, state) => const Scaffold(body: Text('GPS-LOG-PAGE')),
      ),
    ],
  );
  return testAppRouter(router: router);
}

void main() {
  testWidgets('GPS Logger quick action navigates to /gps-log', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('GPS Logger'));
    await tester.pumpAndSettle();
    expect(find.text('GPS-LOG-PAGE'), findsOneWidget);
  });
}
