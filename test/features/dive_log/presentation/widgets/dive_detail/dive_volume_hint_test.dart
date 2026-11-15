import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_volume_hint.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// The note that SAC is per pressure unit for want of a cylinder volume, and
/// where it leads (issue #4527, plan 5).
void main() {
  final dive = Dive(id: 'dive', dateTime: DateTime.utc(2026, 3, 9));

  Future<GoRouter> pump(
    WidgetTester tester, {
    RecordEditController<Dive>? controller,
  }) async {
    final hint = DiveVolumeHint(diveId: dive.id, volumeSymbol: 'L');
    final router = GoRouter(
      initialLocation: '/dive',
      routes: [
        GoRoute(
          path: '/dive',
          builder: (context, state) => Scaffold(
            body: controller == null
                ? hint
                : RecordEditScope<Dive>(controller: controller, child: hint),
          ),
        ),
        GoRoute(
          path: '/dives/:id/edit',
          builder: (context, state) => const Scaffold(body: Text('EDIT FORM')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('with no editing offered it leads to the dive form', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byType(DiveVolumeHint));
    await tester.pumpAndSettle();
    expect(find.text('EDIT FORM'), findsOneWidget);
  });

  testWidgets('locked, it leads where it did', (tester) async {
    final controller = RecordEditController<Dive>(onSave: (_) async {});
    addTearDown(controller.dispose);
    await pump(tester, controller: controller);
    await tester.tap(find.byType(DiveVolumeHint));
    await tester.pumpAndSettle();
    expect(find.text('EDIT FORM'), findsOneWidget);
  });

  testWidgets('in a sitting it opens the Cylinders card, and asks for it to '
      'be shown', (tester) async {
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(dive);
    addTearDown(controller.dispose);
    await pump(tester, controller: controller);

    await tester.tap(find.byType(DiveVolumeHint));
    await tester.pumpAndSettle();

    expect(find.text('EDIT FORM'), findsNothing);
    expect(controller.openCardIds, contains('tanks'));
    expect(controller.revealRequest?.cardId, 'tanks');
  });
}
