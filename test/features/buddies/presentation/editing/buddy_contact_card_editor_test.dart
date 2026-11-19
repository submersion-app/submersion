import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_contact_card_editor.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_country_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_profile_link_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Refuses every link as taken by Sam, as the repository does for a
/// profile another buddy of the list holds.
class _TakenLinks implements BuddyProfileLinkRepository {
  _TakenLinks({this.fail = false});

  /// Fails the check outright instead of refusing.
  final bool fail;
  final asked = <String>[];

  @override
  Future<void> assertLinkAllowed({
    required String? ownerDiverId,
    required String linkedDiverId,
    String? buddyId,
  }) async {
    asked.add(linkedDiverId);
    if (fail) throw StateError('database busy');
    throw BuddyLinkRefused(
      BuddyLinkRefusal.taken,
      existingBuddy: Buddy(
        id: 'b2',
        name: 'Sam',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The buddy Contact card's editor (issue #4527, phase 3).
void main() {
  final l = AppLocalizationsEn();
  final profile = Diver(
    id: 'p1',
    name: 'Alex Diver',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  Future<_TakenLinks> pump(
    WidgetTester tester,
    EditSession<Buddy> s, {
    bool fail = false,
  }) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final links = _TakenLinks(fail: fail);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          buddyProfileLinkRepositoryProvider.overrideWithValue(links),
          linkedProfileSuggestionProvider.overrideWith(
            (ref, args) async => profile,
          ),
          allDiversProvider.overrideWith((ref) async => [profile]),
          buddyCountrySuggestionsProvider.overrideWith((ref) async => []),
        ],
        child: Scaffold(
          body: SingleChildScrollView(
            child: BuddyContactCardEditor(session: s),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return links;
  }

  Buddy alex() => Buddy(
    id: 'b1',
    diverId: 'd1',
    name: 'Alex',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  testWidgets('a profile taken by another buddy is refused when picked', (
    tester,
  ) async {
    final session = EditSession(alex());
    addTearDown(session.dispose);
    final links = await pump(tester, session);

    await tester.tap(find.text(l.buddies_linkedProfile_link));
    await tester.pumpAndSettle();

    expect(links.asked, ['p1']);
    expect(
      find.text(l.buddies_linkedProfile_refusedTaken('Sam')),
      findsOneWidget,
    );
    expect(session.working.linkedDiverId, isNull);
    expect(session.isDirty, isFalse);
  });

  testWidgets('a bad email is flagged', (tester) async {
    final session = EditSession(alex());
    addTearDown(session.dispose);
    await pump(tester, session);

    await tester.enterText(
      find.byKey(const ValueKey('buddy-edit-email')),
      'not an email',
    );
    await tester.pumpAndSettle();

    expect(find.text(l.buddies_validation_emailInvalid), findsOneWidget);
    expect(session.changedCardIds, {'contact'});
  });

  testWidgets('a check that cannot be made says to try again', (tester) async {
    final session = EditSession(alex());
    addTearDown(session.dispose);
    await pump(tester, session, fail: true);

    await tester.tap(find.text(l.buddies_linkedProfile_link));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(l.common_error_tryAgain), findsOneWidget);
    expect(session.working.linkedDiverId, isNull);
  });
}
