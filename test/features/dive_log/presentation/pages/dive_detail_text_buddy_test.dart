import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Mock SettingsNotifier that does not access the database.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Only the Buddies section visible, so the Details section's own "Buddy"
/// row cannot satisfy a text assertion meant for the Buddies card.
AppSettings _buddiesOnly() => AppSettings(
  diveDetailSections: DiveDetailSectionId.values
      .map(
        (id) => DiveDetailSectionConfig(
          id: id,
          visible: id == DiveDetailSectionId.buddies,
        ),
      )
      .toList(),
);

/// The generated English strings, read so a wording change cannot break
/// these tests or silently turn a "findsNothing" into an always-green check.
final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

/// The Buddies card's solo copy.
final String _soloDive = _en.diveLog_detail_soloDive;

/// The label on the diver's own role tile.
final String _me = _en.buddies_picker_me;

BuddyWithRole _linkedBuddy() => BuddyWithRole(
  buddy: Buddy(
    id: 'b1',
    name: 'Alice Adams',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  role: DiveRole.builtInBuddy(),
);

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences prefs, {
  String? textBuddy,
  String? diverRoleId,
  List<BuddyWithRole> linked = const [],
}) async {
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime(2026, 3, 15, 10, 0),
    buddy: textBuddy,
    diverRoleId: diverRoleId,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        diveProvider(dive.id).overrideWith((ref) async => dive),
        diveDataSourcesProvider(
          dive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
        settingsProvider.overrideWith(
          (ref) => _MockSettingsNotifier(_buddiesOnly()),
        ),
        buddiesForDiveProvider(dive.id).overrideWith((ref) async => linked),
        diveSightingsProvider(
          dive.id,
        ).overrideWith((ref) async => <Sighting>[]),
        buddySignaturesForDiveProvider(
          dive.id,
        ).overrideWith((ref) async => <Signature>[]),
        allDiveRolesProvider.overrideWith((ref) async => <DiveRole>[]),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: dive.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Buddies card with a free-text buddy (#1831)', () {
    testWidgets('linked buddy records are listed and the dive is not solo', (
      tester,
    ) async {
      await _pump(tester, prefs, linked: [_linkedBuddy()]);

      expect(find.text('Alice Adams'), findsOneWidget);
      expect(find.text(_soloDive), findsNothing);
    });

    testWidgets('linked buddy records win over stale free-text buddy', (
      tester,
    ) async {
      await _pump(
        tester,
        prefs,
        textBuddy: 'Legacy Text',
        linked: [_linkedBuddy()],
      );

      expect(find.text('Alice Adams'), findsOneWidget);
      expect(
        find.text('Legacy Text'),
        findsNothing,
        reason:
            'the dive_buddies junction is authoritative once it holds anyone; '
            'the frozen free-text column must not duplicate it',
      );
    });

    testWidgets('a text-only buddy is shown instead of "Solo dive"', (
      tester,
    ) async {
      await _pump(tester, prefs, textBuddy: 'Bob Brown');

      expect(find.text('Bob Brown'), findsOneWidget);
      expect(
        find.text(_soloDive),
        findsNothing,
        reason: 'a dive with a buddy stored as text is not a solo dive',
      );
    });

    testWidgets("a text-only buddy is shown below the diver's own role", (
      tester,
    ) async {
      await _pump(
        tester,
        prefs,
        textBuddy: 'Bob Brown',
        diverRoleId: 'mysterySlug',
      );

      expect(find.text(_me), findsOneWidget);
      expect(find.text('Bob Brown'), findsOneWidget);
      final meY = tester.getCenter(find.text(_me)).dy;
      final bobY = tester.getCenter(find.text('Bob Brown')).dy;
      expect(meY, lessThan(bobY));
    });

    testWidgets('no linked and no text buddy still reads "Solo dive"', (
      tester,
    ) async {
      await _pump(tester, prefs);

      expect(find.text(_soloDive), findsOneWidget);
    });

    testWidgets('a whitespace-only text buddy still reads "Solo dive"', (
      tester,
    ) async {
      await _pump(tester, prefs, textBuddy: '   ');

      expect(find.text(_soloDive), findsOneWidget);
    });
  });
}
