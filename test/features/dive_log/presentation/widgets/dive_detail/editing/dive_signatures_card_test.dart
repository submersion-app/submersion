import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_signature_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_signatures_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_signatures_sitting.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_display_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The Signatures card of the dive page, edited in place (issue #4527,
/// plan 6).
void main() {
  late AppDatabase db;
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final ana = Buddy(id: 'b1', name: 'Ana', createdAt: epoch, updatedAt: epoch);
  final png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ]);
  final dive = Dive(id: 'd1', dateTime: epoch, courseIds: const ['c1']);

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Ana', 0, 0)",
    );
    await BuddyRepository().setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ana, roles: [DiveRole.synthetic(DiveRole.buddyId)]),
    ]);
  });
  tearDown(tearDownTestDatabase);

  Future<RecordEditController<Dive>> pump(
    WidgetTester tester, {
    bool unlocked = false,
    bool open = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = RecordEditController<Dive>(
      onSave: (_) async {},
      onStart: (session) => Future.wait([
        diveBuddiesList.load(session),
        diveSignaturesList.load(session),
      ]),
    );
    addTearDown(controller.dispose);
    if (unlocked) controller.unlock(dive);
    if (open) controller.openCard(DiveDetailSectionId.signatures.name);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await getBaseOverrides(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => open
                      ? DiveSignaturesCardEditor(session: controller.session!)
                      : DiveSignaturesSection(dive: dive),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('locked: no capture, no delete, no Request', (tester) async {
    await pump(tester);
    expect(find.text('Not signed'), findsOneWidget);
    expect(find.text('Capture Instructor Signature'), findsNothing);
    expect(find.text('Request').hitTestable(), findsNothing);
  });

  testWidgets('locked with a stored signature: shown, with no delete', (
    tester,
  ) async {
    await SignatureStorageService().saveSignature(
      diveId: 'd1',
      imageBytes: png,
      signerName: 'Ines',
    );
    await pump(tester);
    final display = tester.widget<SignatureDisplayWidget>(
      find.byType(SignatureDisplayWidget),
    );
    expect(display.showDeleteButton, isFalse);
  });

  testWidgets('in the open card: capture and Request are offered, and a '
      'capture shows at once', (tester) async {
    final c = await pump(tester, unlocked: true, open: true);
    expect(find.text('Capture Instructor Signature'), findsOneWidget);
    expect(find.text('Request').hitTestable(), findsOneWidget);

    addCapturedSignature(
      c.session!,
      Signature(
        id: 'held',
        diveId: 'd1',
        imageData: png,
        signerName: 'Ines',
        signedAt: epoch,
        type: SignatureType.instructor,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Capture Instructor Signature'), findsNothing);
    final display = tester.widget<SignatureDisplayWidget>(
      find.byType(SignatureDisplayWidget),
    );
    expect(display.showDeleteButton, isTrue);
    expect(c.session!.changedCardIds, {'signatures'});
  });

  test('with neither a buddy nor a course the card is empty and not '
      'offered', () async {
    await BuddyRepository().setBuddiesForDive('d1', const []);
    final bare = dive.copyWith(courseIds: const []);
    final session = EditSession<Dive>(bare);
    addTearDown(session.dispose);
    await diveBuddiesList.load(session);
    await diveSignaturesList.load(session);

    final card = diveEditCards[DiveDetailSectionId.signatures]!;
    expect(card.isEmptyInSitting!(session), isTrue);
    expect(card.isOfferedWhenEmpty(session), isFalse);
  });
}
