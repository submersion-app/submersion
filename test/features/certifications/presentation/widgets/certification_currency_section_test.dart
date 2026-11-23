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
import 'package:submersion/features/certifications/presentation/editing/certification_currency_sitting.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_edit_fields.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

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

  Future<void> pump(
    WidgetTester tester,
    Certification cert, {
    EditSession<Certification>? editing,
    EditSession<Certification>? shown,
  }) async {
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
              child: CertificationCurrencySection(
                certification: cert,
                editing: editing,
                shown: shown,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// Opens [cert]'s Currency card in a sitting whose events are read.
  Future<EditSession<Certification>> pumpEditing(
    WidgetTester tester,
    Certification cert,
  ) async {
    final session = EditSession(cert);
    addTearDown(session.dispose);
    await tester.runAsync(() => certificationEventsList.load(session));
    await pump(tester, cert, editing: session);
    return session;
  }

  /// The sitting's Save, as far as this card's held writes go.
  Future<void> save(
    WidgetTester tester,
    EditSession<Certification> session,
  ) async {
    await tester.runAsync(session.runHeldWrites);
    await settle(tester);
  }

  /// The preference [session] holds for [cert] under [ruleId].
  CurrencyPref? held(
    EditSession<Certification> session,
    Certification cert, [
    String ruleId = 'padi_reactivate',
  ]) => currencyPrefsInSitting(
    session,
  )[(certificationId: cert.id, ruleId: ruleId)];

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

  testWidgets('a covered card with no custom title is named by its level', (
    tester,
  ) async {
    // An empty stored name means "use the level" (#3436).
    await CertificationRepository().updateCertification(ow.copyWith(name: ''));
    await pump(tester, aow);
    expect(find.textContaining('Also covers Open Water'), findsOneWidget);
  });

  testWidgets('logging a refresher saves it against the row\'s rule', (
    tester,
  ) async {
    final session = await pumpEditing(tester, aow);
    await openMenu(tester);
    await tester.tap(find.text('Log refresher').last);
    await settle(tester);
    expect(find.text('Log refresher or renewal'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);
    await save(tester, session);

    final events = await currency.getEvents(aow.id);
    expect(events.single.eventType, CurrencyEventType.refresher);
    expect(events.single.ruleId, 'padi_reactivate');
  });

  testWidgets('a muted row offers Unmute, which holds every member '
      'unmuted', (tester) async {
    final session = await pumpEditing(tester, aow);
    await openMenu(tester);
    await tester.tap(find.text('Mute').last);
    await settle(tester);
    for (final c in [ow, aow]) {
      expect(held(session, c)?.muted, isTrue, reason: c.name);
    }
    expect(find.text('Muted'), findsOneWidget);
    expect(find.text('Unmute'), findsOneWidget);

    await tester.tap(find.text('Unmute'));
    await settle(tester);
    for (final c in [ow, aow]) {
      expect(held(session, c)?.muted ?? false, isFalse, reason: c.name);
    }
    expect(find.text('Muted'), findsNothing);
  });

  testWidgets('an interval override applies to every member', (tester) async {
    final session = await pumpEditing(tester, aow);
    await openMenu(tester);
    await tester.tap(find.text('Edit interval').last);
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.tap(find.text('Save'));
    await settle(tester);
    await save(tester, session);

    for (final c in [ow, aow]) {
      final pref = (await currency.getPrefs(c.id)).single;
      expect(pref.lapseDaysOverride, 5000, reason: c.name);
      expect(pref.leadDaysOverride, isNull);
    }
  });

  testWidgets('a lead longer than the interval is rejected', (tester) async {
    final session = await pumpEditing(tester, aow);
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
    expect(held(session, aow), isNull);
  });

  testWidgets('a lapse shorter than the inherited lead is rejected', (
    tester,
  ) async {
    // The PADI refresher warns 185 days out; a 30-day lapse with the lead
    // left blank would leave the row due soon forever.
    final session = await pumpEditing(tester, aow);
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
    expect(held(session, aow), isNull);
  });

  testWidgets('which dives count: any dive, back to default, a selection', (
    tester,
  ) async {
    Future<void> openMapping() async {
      await openMenu(tester);
      await tester.tap(find.text('Which dives count').last);
      await settle(tester);
    }

    final session = await pumpEditing(tester, aow);

    // Cancel holds nothing.
    await openMapping();
    expect(find.text('Nothing selected means any dive counts'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(held(session, aow), isNull);

    // Saving with nothing selected is "any dive counts" ([]), not inherit.
    await openMapping();
    await tester.tap(find.text('Save'));
    await settle(tester);
    for (final c in [ow, aow]) {
      final pref = held(session, c)!;
      expect(pref.countedDiveModes, isNotNull, reason: c.name);
      expect(pref.countedDiveModes, isEmpty, reason: c.name);
      expect(pref.countedDiveTypeIds, isEmpty, reason: c.name);
    }

    // "Use the rule's default" goes back to inheriting (null).
    await openMapping();
    await tester.tap(find.text("Use the rule's default"));
    await settle(tester);
    for (final c in [ow, aow]) {
      final pref = held(session, c);
      expect(pref?.countedDiveModes, isNull, reason: c.name);
      expect(pref?.countedDiveTypeIds, isNull, reason: c.name);
    }

    // A selection is written for every member of the row.
    await openMapping();
    await tester.tap(
      find.widgetWithText(FilterChip, 'Closed Circuit Rebreather'),
    );
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    await save(tester, session);
    for (final c in [ow, aow]) {
      final pref = (await currency.getPrefs(c.id)).single;
      expect(pref.countedDiveModes, [DiveMode.ccr], reason: c.name);
    }
  });

  // Issue #4942: a card mapping this build cannot read decodes to "any
  // dive". The dialog starts from the rule's mapping, which is what the
  // engine applies in its place, and a mute leaves the stored value alone.
  testWidgets('an unreadable card mapping starts from the rule\'s', (
    tester,
  ) async {
    final ccr = await addCert(
      'Rebreather Diver',
      CertificationAgency.padi,
      CertificationLevel.rebreather,
    );
    await db
        .into(db.certificationCurrencyPrefs)
        .insert(
          CertificationCurrencyPrefsCompanion.insert(
            id: 'p1',
            certificationId: ccr.id,
            ruleId: 'rebreather_currency',
            countedDiveModes: const Value('["modeFromTheFuture"]'),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final session = await pumpEditing(tester, ccr);

    await openMenu(tester);
    await tester.tap(find.text('Which dives count').last);
    await settle(tester);
    for (final mode in [
      'Closed Circuit Rebreather',
      'Semi-Closed Rebreather',
    ]) {
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, mode),
      );
      expect(chip.selected, isTrue, reason: mode);
    }
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    await openMenu(tester);
    await tester.tap(find.text('Mute').last);
    await settle(tester);
    await save(tester, session);
    final row = await (db.select(
      db.certificationCurrencyPrefs,
    )..where((p) => p.id.equals('p1'))).getSingle();
    expect(row.muted, isTrue);
    expect(row.countedDiveModes, '["modeFromTheFuture"]');
  });

  testWidgets('any dive chosen over an unreadable mapping is written', (
    tester,
  ) async {
    final ccr = await addCert(
      'Rebreather Diver',
      CertificationAgency.padi,
      CertificationLevel.rebreather,
    );
    await db
        .into(db.certificationCurrencyPrefs)
        .insert(
          CertificationCurrencyPrefsCompanion.insert(
            id: 'p1',
            certificationId: ccr.id,
            ruleId: 'rebreather_currency',
            countedDiveTypeIds: const Value('[]'),
            countedDiveModes: const Value('["modeFromTheFuture"]'),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final session = await pumpEditing(tester, ccr);

    // The dialog starts from the rule's CCR and SCR; clearing both is the
    // diver saying any dive counts, which decodes the same as the stored
    // mapping but is their choice.
    await openMenu(tester);
    await tester.tap(find.text('Which dives count').last);
    await settle(tester);
    for (final mode in [
      'Closed Circuit Rebreather',
      'Semi-Closed Rebreather',
    ]) {
      await tester.tap(find.widgetWithText(FilterChip, mode));
      await settle(tester);
    }
    await tester.tap(find.text('Save'));
    await settle(tester);
    await save(tester, session);

    final row = await (db.select(
      db.certificationCurrencyPrefs,
    )..where((p) => p.id.equals('p1'))).getSingle();
    expect(row.countedDiveTypeIds, '[]');
    expect(row.countedDiveModes, '[]');
  });

  testWidgets('the mapping action appears only for activity clocks', (
    tester,
  ) async {
    await pumpEditing(tester, aow);
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
    await pumpEditing(tester, efr);
    await openMenu(tester);
    expect(find.text('Which dives count'), findsNothing);
    expect(find.text('Edit interval'), findsOneWidget);
  });

  testWidgets('history lists events newest first', (tester) async {
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
      final session = await pumpEditing(tester, nitrox);
      expect(find.text('Card expiry'), findsOneWidget);
      await openMenu(tester);
      expect(find.text('Log refresher'), findsNothing);
      await tester.tap(find.text('Edit interval').last);
      await settle(tester);
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '10');
      await tester.tap(find.text('Save'));
      await settle(tester);
      await save(tester, session);
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
    final session = await pumpEditing(tester, aow);
    expect(find.text('Muted'), findsOneWidget);
    await openMenu(tester);
    await tester.tap(find.text('Edit interval').last);
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, '300');
    await tester.tap(find.text('Save'));
    await settle(tester);
    await save(tester, session);

    final mine = (await currency.getPrefs(
      aow.id,
    )).singleWhere((p) => p.ruleId == 'mine');
    expect(mine.lapseDaysOverride, 300);
    expect(mine.muted, isTrue, reason: 'the inherited mute is carried over');
    expect(find.text('Muted'), findsOneWidget);
  });

  testWidgets('locked, no action is offered', (tester) async {
    await currency.createEvent(
      CurrencyEvent(
        id: '',
        certificationId: aow.id,
        ruleId: 'padi_reactivate',
        eventType: CurrencyEventType.refresher,
        eventDate: DateTime(2024),
        createdAt: t0,
        updatedAt: t0,
      ),
    );
    await pump(tester, aow);

    expect(find.text('PADI refresher (ReActivate)'), findsOneWidget);
    expect(find.byType(PopupMenuButton<CurrencyRowAction>), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('in a sitting, logging writes nothing until Save', (
    tester,
  ) async {
    final session = EditSession(aow);
    addTearDown(session.dispose);
    await tester.runAsync(() => certificationEventsList.load(session));
    await pump(tester, aow, editing: session);
    await openMenu(tester);
    await tester.tap(find.text('Log refresher').last);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(await currency.getEvents(aow.id), isEmpty);
    expect(certificationEventsList.current(session), hasLength(1));
    expect(session.changedCardIds, {'currency'});
    await tester.runAsync(session.runHeldWrites);
    expect(await currency.getEvents(aow.id), hasLength(1));
  });

  testWidgets('in a sitting, a delete asks nothing and waits for Save', (
    tester,
  ) async {
    await currency.createEvent(
      CurrencyEvent(
        id: '',
        certificationId: aow.id,
        ruleId: 'padi_reactivate',
        eventType: CurrencyEventType.refresher,
        eventDate: DateTime(2024),
        createdAt: t0,
        updatedAt: t0,
      ),
    );
    final session = EditSession(aow);
    addTearDown(session.dispose);
    await tester.runAsync(() => certificationEventsList.load(session));
    await pump(tester, aow, editing: session);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(certificationEventsList.current(session), isEmpty);
    expect(await currency.getEvents(aow.id), hasLength(1));
  });

  testWidgets('before the sitting has read the events, none is marked '
      'changed', (tester) async {
    await currency.createEvent(
      CurrencyEvent(
        id: '',
        certificationId: aow.id,
        ruleId: 'padi_reactivate',
        eventType: CurrencyEventType.refresher,
        eventDate: DateTime(2024),
        createdAt: t0,
        updatedAt: t0,
      ),
    );
    final session = EditSession(aow);
    addTearDown(session.dispose);
    // No read yet: the stored events are shown, as stored.
    await pump(tester, aow, shown: session);

    expect(find.byKey(const ValueKey('currencyEventTile')), findsOneWidget);
    expect(find.byType(RecordChangedDot), findsNothing);
  });

  testWidgets('while the sitting changes the credential, no action is '
      'offered', (tester) async {
    final session = EditSession(aow)
      ..set(certificationCredentialsField, [
        const CertificationCredential(agency: 'ssi', level: 'openWater'),
      ]);
    addTearDown(session.dispose);
    await pump(tester, aow, editing: session);

    expect(
      find.byKey(const ValueKey('currency-credential-held')),
      findsOneWidget,
    );
    expect(find.byType(PopupMenuButton<CurrencyRowAction>), findsNothing);
  });

  testWidgets('in a sitting, muting holds every member until Save', (
    tester,
  ) async {
    final session = EditSession(aow);
    addTearDown(session.dispose);
    await pump(tester, aow, editing: session);
    await openMenu(tester);
    await tester.tap(find.text('Mute').last);
    await settle(tester);

    expect(find.text('Muted'), findsOneWidget);
    for (final c in [ow, aow]) {
      expect(await currency.getPrefs(c.id), isEmpty);
    }
    await tester.runAsync(session.runHeldWrites);
    for (final c in [ow, aow]) {
      expect((await currency.getPrefs(c.id)).single.muted, isTrue);
    }
  });

  testWidgets('closed, the card shows what the sitting holds', (tester) async {
    final session = EditSession(aow);
    addTearDown(session.dispose);
    await tester.runAsync(() => certificationEventsList.load(session));
    certificationEventsList.set(session, [
      newCurrencyEvent(
        certificationId: aow.id,
        ruleId: 'padi_reactivate',
        type: CurrencyEventType.refresher,
        date: DateTime(2024, 5, 1),
      ),
    ]);
    final g = (await tester.runAsync(
      () => CertificationCurrencyRepository().getRules(),
    ))!;
    expect(g, isNotEmpty);

    await pump(tester, aow, shown: session);

    expect(find.byKey(const ValueKey('currencyEventTile')), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
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
