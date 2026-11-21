import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/presentation/editing/buddy_certification_dialog.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A buddy's certification is edited in a dialog made of the certification
/// page's card editors (issue #4527, phase 3).
void main() {
  final l = AppLocalizationsEn();
  final nitrox = Certification(
    id: 'c1',
    buddyId: 'b1',
    name: 'Nitrox',
    agency: 'padi',
    cardNumber: '1',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  Future<List<Certification?>> open(
    WidgetTester tester,
    Certification initial,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <Certification?>[];
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showBuddyCertificationDialog(context, initial: initial),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('Done returns the edited certification', (tester) async {
    final results = await open(tester, nitrox);
    await tester.enterText(
      find.byKey(const ValueKey('cert-edit-card-number')),
      '42',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('buddy-cert-dialog-done')));
    await tester.pumpAndSettle();

    expect(results.single!.cardNumber, '42');
    expect(results.single!.id, 'c1');
    expect(results.single!.name, 'Nitrox');
    expect(results.single!.buddyId, 'b1');
  });

  // An unchanged certification must not read as edited: a new updatedAt
  // would send it to sync for nothing (issue #553).
  testWidgets('Done with nothing changed returns it as it was', (tester) async {
    final results = await open(tester, nitrox);

    await tester.tap(find.byKey(const ValueKey('buddy-cert-dialog-done')));
    await tester.pumpAndSettle();

    expect(results.single, nitrox);
    expect(results.single!.updatedAt, DateTime(2020));
  });

  testWidgets('Cancel returns null', (tester) async {
    final results = await open(tester, nitrox);
    await tester.enterText(
      find.byKey(const ValueKey('cert-edit-card-number')),
      '42',
    );
    await tester.tap(find.byKey(const ValueKey('buddy-cert-dialog-cancel')));
    await tester.pumpAndSettle();

    expect(results.single, isNull);
  });

  testWidgets('neither title nor level keeps it open', (tester) async {
    final results = await open(tester, nitrox);
    await tester.enterText(find.byKey(const ValueKey('cert-edit-title')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('buddy-cert-dialog-done')));
    await tester.pumpAndSettle();

    expect(results, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(l.certifications_edit_validation_certificationOrTitleRequired),
      findsOneWidget,
    );
  });

  testWidgets('opening it focuses no field', (tester) async {
    await open(tester, nitrox);

    final focused = [
      for (final e in tester.widgetList<EditableText>(
        find.byType(EditableText),
      ))
        if (e.focusNode.hasFocus) e,
    ];
    expect(focused, isEmpty);
  });
}
