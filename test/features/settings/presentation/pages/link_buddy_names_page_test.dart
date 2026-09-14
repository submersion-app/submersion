import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/settings/presentation/pages/link_buddy_names_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../buddies/helpers/fake_legacy_buddy_conversion_service.dart';

/// Mock SettingsNotifier that does not access the database.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _epoch = DateTime.utc(2026);
final _l10n = lookupAppLocalizations(const Locale('en'));

final _roles = [
  DiveRole(
    id: DiveRole.buddyId,
    name: 'Buddy',
    isBuiltIn: true,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
  DiveRole(
    id: DiveRole.diveMasterId,
    name: 'Dive Master',
    isBuiltIn: true,
    sortOrder: 4,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
];

final _matcher = BuddyNameMatcher([
  MatchCandidate(
    id: 'jim',
    name: 'Jim Dunfield',
    diverId: 'me',
    createdAt: _epoch,
  ),
], diverId: 'me');

LinkBuddyNamesData _data() => LinkBuddyNamesData(
  diverId: 'me',
  matcher: _matcher,
  dives: [
    CandidateDive(
      plan: planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Jim Dunfield, Ann',
        matcher: _matcher,
      ),
      diveNumber: 12,
      dateTime: DateTime.utc(2026, 3, 15, 10),
      siteName: 'Blue Hole',
    ),
    CandidateDive(
      plan: planLegacyConversion(
        diveId: 'd2',
        buddyText: 'Ann',
        diveMasterText: 'Ana',
        matcher: _matcher,
      ),
      diveNumber: 13,
      dateTime: DateTime.utc(2026, 3, 16, 10),
    ),
  ],
);

String _summary(int dives, int newBuddies, int existing) => [
  _l10n.buddies_linkText_page_summaryDives(dives),
  _l10n.buddies_linkText_page_summaryNew(newBuddies),
  _l10n.buddies_linkText_page_summaryExisting(existing),
].join(' · ');

Future<void> _pump(
  WidgetTester tester,
  FakeLegacyBuddyConversionService service,
  LinkBuddyNamesData? data,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        linkBuddyNamesDataProvider.overrideWith((ref) async => data),
        legacyBuddyConversionServiceProvider.overrideWithValue(service),
        settingsProvider.overrideWith(
          (ref) => _MockSettingsNotifier(const AppSettings()),
        ),
        allDiveRolesProvider.overrideWith((ref) async => _roles),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LinkBuddyNamesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists each dive with its parsed names and a summary', (
    tester,
  ) async {
    await _pump(tester, FakeLegacyBuddyConversionService(), _data());

    expect(find.text(_summary(2, 2, 1)), findsOneWidget);
    expect(find.textContaining('#12 · Blue Hole · '), findsOneWidget);
    expect(find.textContaining('#13 · '), findsOneWidget);
    expect(find.text('Jim Dunfield'), findsOneWidget);
    expect(find.text('Ann'), findsNWidgets(2));
    expect(
      find.text(
        _l10n.buddies_linkText_chipWithRole(
          'Ana',
          _l10n.diveRole_builtin_diveMaster,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(_l10n.buddies_linkText_page_linkDives(2)), findsOneWidget);
  });

  testWidgets('unchecking a dive updates the summary and the button', (
    tester,
  ) async {
    await _pump(tester, FakeLegacyBuddyConversionService(), _data());

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();

    expect(find.text(_summary(1, 1, 1)), findsOneWidget);
    expect(find.text(_l10n.buddies_linkText_page_linkDives(1)), findsOneWidget);
  });

  testWidgets('Link applies the checked dives and offers Undo', (tester) async {
    final service = FakeLegacyBuddyConversionService();
    await _pump(tester, service, _data());

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    await tester.tap(find.text(_l10n.buddies_linkText_page_linkDives(1)));
    await tester.pumpAndSettle();

    expect(service.applied.single.map((p) => p.diveId), ['d1']);
    expect(
      find.text(_l10n.buddies_linkText_page_linkedSnackbar(1)),
      findsOneWidget,
    );

    await tester.tap(find.text(_l10n.diveLog_bulkDelete_undo));
    await tester.pumpAndSettle();

    expect(service.undone, hasLength(1));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('tapping a dive opens its review sheet', (tester) async {
    await _pump(tester, FakeLegacyBuddyConversionService(), _data());

    await tester.tap(find.textContaining('#13 · '));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.buddies_linkText_sheetTitle), findsOneWidget);
  });

  testWidgets('shows the empty state when every name is linked', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeLegacyBuddyConversionService(),
      LinkBuddyNamesData(diverId: 'me', matcher: _matcher, dives: const []),
    );

    expect(find.text(_l10n.buddies_linkText_page_empty), findsOneWidget);
  });
}
