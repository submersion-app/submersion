import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _buddy = Buddy(
  id: 'buddy-1',
  name: 'Jane Doe',
  notes: '',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Certification _makeCert({
  required String name,
  CertificationLevel? level,
  CertificationAgency agency = CertificationAgency.padi,
}) {
  return Certification(
    id: 'c1',
    name: name,
    agency: agency,
    level: level,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pump(WidgetTester tester, Certification cert) async {
  final overrides = await getBaseOverrides();

  final router = GoRouter(
    initialLocation: '/buddies/buddy-1',
    routes: [
      GoRoute(
        path: '/buddies/:id',
        builder: (context, state) =>
            BuddyDetailPage(buddyId: state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        buddyByIdProvider(_buddy.id).overrideWith((ref) async => _buddy),
        buddyCertificationsProvider(
          _buddy.id,
        ).overrideWith((ref) async => [cert]),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The certification tile's subtitle, read off the [ListTile] so it cannot be
/// confused with the identically-worded text elsewhere on the page.
String _certSubtitle(WidgetTester tester) {
  final tile = tester.widget<ListTile>(
    find.ancestor(
      of: find.byIcon(Icons.card_membership),
      matching: find.byType(ListTile),
    ),
  );
  return (tile.subtitle! as Text).data!;
}

void main() {
  group('buddy certification list', () {
    testWidgets('a custom name keeps the certification in the subtitle', (
      tester,
    ) async {
      // Issue #1265: the title is the custom name, so the subtitle is the only
      // place left for the level.
      await _pump(
        tester,
        _makeCert(name: 'Bill Ansell', level: CertificationLevel.diveMaster),
      );

      expect(find.text('Bill Ansell'), findsOneWidget);
      expect(_certSubtitle(tester), 'PADI - Divemaster');
    });

    testWidgets('a derived title does not repeat the level in the subtitle', (
      tester,
    ) async {
      await _pump(
        tester,
        _makeCert(name: '', level: CertificationLevel.diveMaster),
      );

      expect(find.text('Divemaster'), findsOneWidget);
      expect(_certSubtitle(tester), 'PADI');
    });
  });
}
