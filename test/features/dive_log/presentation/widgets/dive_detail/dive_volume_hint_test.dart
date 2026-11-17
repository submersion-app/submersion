import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_volume_hint.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_volume_hint.dart';
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
    const hint = DiveVolumeHint(volumeSymbol: 'L');
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

  // A locked page reads only: the hint no longer leads to the old edit
  // form (issue #4527, plan 11).
  testWidgets('locked, the hint has no tap', (tester) async {
    final controller = RecordEditController<Dive>(onSave: (_) async {});
    addTearDown(controller.dispose);
    await pump(tester, controller: controller);

    expect(
      tester.widget<SacVolumeHint>(find.byType(SacVolumeHint)).onTap,
      isNull,
    );
  });

  testWidgets('outside a dive page it has no tap', (tester) async {
    await pump(tester);

    expect(
      tester.widget<SacVolumeHint>(find.byType(SacVolumeHint)).onTap,
      isNull,
    );
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
