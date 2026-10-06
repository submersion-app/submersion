import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Certification;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_currency_section.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The certification detail Currency section (issue #2267).
void main() {
  late AppDatabase db;
  late CertificationCurrencyRepository currency;
  late Certification ow;
  late Certification aow;
  final t0 = DateTime(2020);

  Future<Certification> addCert(
    String name,
    CertificationAgency agency,
    CertificationLevel? level, {
    DateTime? expires,
  }) => CertificationRepository().createCertification(
    Certification(
      id: '',
      diverId: 'me',
      name: name,
      agency: agency.name,
      level: level?.name,
      expiryDate: expires,
      createdAt: t0,
      updatedAt: t0,
    ),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    currency = CertificationCurrencyRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'Me',
            isDefault: const Value(true),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final lastDive = DateTime.utc(2024, 3, 4, 10).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diverId: const Value('me'),
            diveDateTime: lastDive,
            entryTime: Value(lastDive),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    ow = await addCert(
      'Open Water Diver',
      CertificationAgency.padi,
      CertificationLevel.openWater,
    );
    aow = await addCert(
      'Advanced Open Water',
      CertificationAgency.padi,
      CertificationLevel.advancedOpenWater,
    );
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, Certification cert) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier()..state = 'me',
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CertificationCurrencySection(certification: cert),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<CurrencyRowAction>).first);
    await settle(tester);
  }

  testWidgets('a lapsed refresher shows severity, anchor and advisory', (
    tester,
  ) async {
    await pump(tester, aow);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('PADI refresher (ReActivate)'), findsOneWidget);
    expect(find.textContaining('Lapsed'), findsOneWidget);
    expect(find.textContaining('Last dive'), findsOneWidget);
    expect(find.textContaining('ReActivate refresher after'), findsOneWidget);
    expect(find.textContaining('Also covers Open Water Diver'), findsOneWidget);
  });

  testWidgets('logging a refresher flips the row to current', (tester) async {
    await pump(tester, aow);
    await openMenu(tester);
    await tester.tap(find.text('Log refresher').last);
    await settle(tester);
    expect(find.text('Log refresher or renewal'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final events = await currency.getEvents(aow.id);
    expect(events.single.eventType, CurrencyEventType.refresher);
    expect(events.single.ruleId, 'padi_reactivate');
    expect(find.textContaining('Lapsed'), findsNothing);
    expect(find.textContaining('Due'), findsOneWidget);
    expect(find.textContaining('Refresher logged'), findsOneWidget);
  });

  testWidgets('muting a collapsed row mutes every member', (tester) async {
    await pump(tester, aow);
    await openMenu(tester);
    await tester.tap(find.text('Mute').last);
    await settle(tester);

    for (final c in [ow, aow]) {
      final prefs = await currency.getPrefs(c.id);
      expect(prefs.single.muted, isTrue, reason: c.name);
      expect(prefs.single.ruleId, 'padi_reactivate');
    }
    expect(find.text('Muted'), findsOneWidget);
    expect(find.text('Unmute'), findsOneWidget);

    await tester.tap(find.text('Unmute'));
    await settle(tester);
    for (final c in [ow, aow]) {
      expect((await currency.getPrefs(c.id)).single.muted, isFalse);
    }
  });

  testWidgets('an interval override applies to every member', (tester) async {
    await pump(tester, aow);
    await openMenu(tester);
    await tester.tap(find.text('Edit interval').last);
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.tap(find.text('Save'));
    await settle(tester);

    for (final c in [ow, aow]) {
      final pref = (await currency.getPrefs(c.id)).single;
      expect(pref.lapseDaysOverride, 5000, reason: c.name);
      expect(pref.leadDaysOverride, isNull);
    }
    expect(find.textContaining('Lapsed'), findsNothing);
  });

  testWidgets('a lead longer than the interval is rejected', (tester) async {
    await pump(tester, aow);
    await openMenu(tester);
    await tester.tap(find.text('Edit interval').last);
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '30');
    await tester.enterText(find.byType(TextFormField).at(1), '60');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(
      find.text('The warning cannot start before the interval does'),
      findsOneWidget,
    );
    expect(await currency.getPrefs(aow.id), isEmpty);
  });

  testWidgets('a lapse shorter than the inherited lead is rejected', (
    tester,
  ) async {
    // The PADI refresher warns 185 days out; a 30-day lapse with the lead
    // left blank would leave the row due soon forever.
    await pump(tester, aow);
    await openMenu(tester);
    await tester.tap(find.text('Edit interval').last);
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '30');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(
      find.text('The warning cannot start before the interval does'),
      findsOneWidget,
    );
    expect(await currency.getPrefs(aow.id), isEmpty);
  });

  testWidgets('which dives count: any dive, back to default, a selection', (
    tester,
  ) async {
    Future<void> openMapping() async {
      await openMenu(tester);
      await tester.tap(find.text('Which dives count').last);
      await settle(tester);
    }

    await pump(tester, aow);

    // Cancel writes nothing.
    await openMapping();
    expect(find.text('Nothing selected means any dive counts'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await currency.getPrefs(aow.id), isEmpty);

    // Saving with nothing selected is "any dive counts" ([]), not inherit.
    await openMapping();
    await tester.tap(find.text('Save'));
    await settle(tester);
    for (final c in [ow, aow]) {
      final pref = (await currency.getPrefs(c.id)).single;
      expect(pref.countedDiveModes, isNotNull, reason: c.name);
      expect(pref.countedDiveModes, isEmpty, reason: c.name);
      expect(pref.countedDiveTypeIds, isEmpty, reason: c.name);
    }

    // "Use the rule's default" goes back to inheriting (null).
    await openMapping();
    await tester.tap(find.text("Use the rule's default"));
    await settle(tester);
    for (final c in [ow, aow]) {
      final pref = (await currency.getPrefs(c.id)).single;
      expect(pref.countedDiveModes, isNull, reason: c.name);
      expect(pref.countedDiveTypeIds, isNull, reason: c.name);
    }

    // A selection is written for every member of the row.
    await openMapping();
    await tester.tap(
      find.widgetWithText(FilterChip, 'Closed Circuit Rebreather'),
    );
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    for (final c in [ow, aow]) {
      final pref = (await currency.getPrefs(c.id)).single;
      expect(pref.countedDiveModes, [DiveMode.ccr], reason: c.name);
    }

    // No CCR dive is logged, so nothing starts the clock. The row stays,
    // says so, warns nothing, and the mapping can still be changed back.
    expect(find.text('No counted dive logged yet'), findsOneWidget);
    expect(find.textContaining('Lapsed'), findsNothing);
    await openMapping();
    await tester.tap(find.text("Use the rule's default"));
    await settle(tester);
    expect((await currency.getPrefs(aow.id)).single.countedDiveModes, isNull);
    expect(find.textContaining('Lapsed'), findsOneWidget);
  });

  testWidgets('the mapping action appears only for activity clocks', (
    tester,
  ) async {
    await pump(tester, aow);
    await openMenu(tester);
    expect(find.text('Which dives count'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await settle(tester);

    final efr = await addCert(
      'EFR',
      CertificationAgency.padi,
      CertificationLevel.firstAid,
      expires: DateTime.now().add(const Duration(days: 400)),
    );
    await pump(tester, efr);
    await openMenu(tester);
    expect(find.text('Which dives count'), findsNothing);
    expect(find.text('Edit interval'), findsOneWidget);
  });

  testWidgets('history lists events newest first and deletes one', (
    tester,
  ) async {
    for (final d in [DateTime(2023, 1, 1), DateTime(2023, 6, 1)]) {
      await currency.createEvent(
        CurrencyEvent(
          id: '',
          certificationId: aow.id,
          ruleId: 'padi_reactivate',
          eventType: CurrencyEventType.refresher,
          eventDate: d,
          createdAt: t0,
          updatedAt: t0,
        ),
      );
    }
    await pump(tester, aow);
    expect(find.text('Currency history'), findsOneWidget);
    final tiles = find.byKey(const ValueKey('currencyEventTile'));
    expect(tiles, findsNWidgets(2));
    final first = tester.getTopLeft(find.textContaining('Jun 1, 2023'));
    final second = tester.getTopLeft(find.textContaining('Jan 1, 2023'));
    expect(first.dy, lessThan(second.dy));

    await tester.tap(find.byTooltip('Delete').first);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect((await currency.getEvents(aow.id)).length, 1);
  });

  testWidgets(
    'a card expiry row offers no log action and edits only the lead',
    (tester) async {
      // A renewed card is a new expiry date on the card; the ledger cannot
      // move a printed date, and the lapse is the date itself.
      final nitrox = await addCert(
        'Nitrox',
        CertificationAgency.padi,
        CertificationLevel.nitrox,
        expires: DateTime.now().add(const Duration(days: 30)),
      );
      await pump(tester, nitrox);
      expect(find.text('Card expiry'), findsOneWidget);
      await openMenu(tester);
      expect(find.text('Log refresher'), findsNothing);
      await tester.tap(find.text('Edit interval').last);
      await settle(tester);
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '10');
      await tester.tap(find.text('Save'));
      await settle(tester);
      final pref = (await currency.getPrefs(nitrox.id)).single;
      expect(pref.ruleId, 'card_expiry');
      expect(pref.leadDaysOverride, 10);
      expect(pref.lapseDaysOverride, isNull);
    },
  );

  testWidgets("editing a superseding rule keeps the built-in's mute", (
    tester,
  ) async {
    await currency.createRule(
      CurrencyRule(
        id: 'mine',
        diverId: 'me',
        name: 'My refresher',
        clockKind: CurrencyClockKind.activity,
        agencies: const [CertificationAgency.padi],
        lapseDays: 200,
        leadDays: 30,
        supersedesRuleId: 'padi_reactivate',
        createdAt: t0,
        updatedAt: t0,
      ),
    );
    for (final c in [ow, aow]) {
      await currency.upsertPref(
        CurrencyPref(
          id: '',
          certificationId: c.id,
          ruleId: 'padi_reactivate',
          muted: true,
          createdAt: t0,
          updatedAt: t0,
        ),
      );
    }
    await pump(tester, aow);
    expect(find.text('Muted'), findsOneWidget);
    await openMenu(tester);
    await tester.tap(find.text('Edit interval').last);
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, '300');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final mine = (await currency.getPrefs(
      aow.id,
    )).singleWhere((p) => p.ruleId == 'mine');
    expect(mine.lapseDaysOverride, 300);
    expect(mine.muted, isTrue, reason: 'the inherited mute is carried over');
    expect(find.text('Muted'), findsOneWidget);
  });

  testWidgets('the section is absent when nothing applies or is logged', (
    tester,
  ) async {
    final bare = await addCert('Club card', CertificationAgency.other, null);
    await pump(tester, bare);
    expect(find.text('Currency'), findsNothing);
  });
}

/// Pumps until the database futures and provider rebuilds have landed.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}
