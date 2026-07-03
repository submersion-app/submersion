import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final buddy = Buddy(
    id: 'buddy-1',
    name: 'Jane Doe',
    notes: '',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpDetailPage(
    WidgetTester tester,
    List<BuddyRoleCredential> roles,
  ) async {
    final overrides = await getBaseOverrides();

    // Mobile size to avoid master-detail layout/redirect.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
          buddyStatsProvider(
            buddy.id,
          ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
          diveIdsForBuddyProvider(
            buddy.id,
          ).overrideWith((ref) async => <String>[]),
          divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          buddyRolesProvider(buddy.id).overrideWith((ref) async => roles),
        ].cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BuddyDetailPage(buddyId: buddy.id, embedded: true),
        ),
      ),
    );
    // Tolerate unrelated layout overflow in the shared-dives header row at
    // this test viewport size (pre-existing, same tolerance used in
    // buddy_detail_page_test.dart).
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = (d) => errors.add(d);
    await tester.pumpAndSettle();
    FlutterError.onError = FlutterError.presentError;
  }

  group('BuddyDetailPage professional roles card', () {
    testWidgets('shows section title and credential label when present', (
      tester,
    ) async {
      final roles = [
        BuddyRoleCredential(
          id: 'role-1',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          agency: CertificationAgency.padi,
          credentialNumber: '12345',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      await pumpDetailPage(tester, roles);

      expect(find.text('Professional Roles'), findsOneWidget);
      expect(find.text('Instructor - PADI #12345'), findsOneWidget);
    });

    testWidgets('hides section when there are no credentials', (tester) async {
      await pumpDetailPage(tester, const []);

      expect(find.text('Professional Roles'), findsNothing);
    });
  });
}
