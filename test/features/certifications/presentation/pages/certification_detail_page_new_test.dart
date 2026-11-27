import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/certifications/presentation/widgets/certification_currency_section.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'certification_detail_page_unlock_harness.dart';

/// A new certification opens on its page, already unlocked (issue #4527,
/// phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Finder titleField() => find.byKey(const ValueKey('cert-edit-title'));

  Future<void> typeTitle(WidgetTester tester, String title) async {
    await tester.enterText(titleField(), title);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  testWidgets('a new certification opens unlocked with Details and Dates '
      'open', (tester) async {
    await pumpNewCertificationPage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.certifications_edit_appBar_add), findsOneWidget);
    expect(titleField(), findsOneWidget);
    expect(find.byKey(const ValueKey('cert-edit-issue-date')), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byType(CertificationCurrencySection), findsNothing);
  });

  testWidgets('Save waits for the first entry, then pops the id', (
    tester,
  ) async {
    final harness = await pumpNewCertificationPage(tester);

    await tapSave(tester);
    expect(harness.save.creates, isEmpty);

    await typeTitle(tester, 'Ice Diver');
    await tapSave(tester);
    final created = harness.save.creates.single.certification;
    expect(created.name, 'Ice Diver');
    expect(created.diverId, 'd1');
    expect(created.buddyId, isNull);
    expect(harness.popped, created.id);
  });

  testWidgets('in the pane, Save hands the id to the pane', (tester) async {
    final harness = await pumpNewCertificationPage(tester, embedded: true);
    await typeTitle(tester, 'Ice Diver');

    await tester.tap(find.text(l.forms_save));
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.createdIds, [harness.save.creates.single.certification.id]);
  });

  testWidgets('an entry asks before leaving, and nothing is written', (
    tester,
  ) async {
    final harness = await pumpNewCertificationPage(tester);
    await typeTitle(tester, 'Ice Diver');

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.poppedAtAll, isTrue);
    expect(harness.save.creates, isEmpty);
    expect(harness.save.calls, isEmpty);
  });

  testWidgets('an untouched new certification leaves without asking', (
    tester,
  ) async {
    final harness = await pumpNewCertificationPage(tester);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(harness.poppedAtAll, isTrue);
  });

  testWidgets('a Save that fails keeps everything', (tester) async {
    final harness = await pumpNewCertificationPage(tester);
    await typeTitle(tester, 'Ice Diver');
    harness.save.fail = true;

    await tapSave(tester);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);

    harness.save.fail = false;
    await tapSave(tester);
    expect(harness.save.creates, hasLength(2));
    expect(
      harness.save.creates.last.certification.id,
      harness.save.creates.first.certification.id,
    );
  });
}
