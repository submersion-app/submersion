import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/data/repositories/diver_weight_entry_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/settings/presentation/pages/body_weight_edit_page.dart';
import 'package:submersion/features/settings/presentation/pages/prior_experience_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/visibility_scale_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';
import 'pages/diver_profile_harness.dart';

/// Locale-aware numeric input for the settings, weight, checklist and pre-dive
/// editors (#1091).
///
/// Two behaviours are pinned here:
///
/// 1. A comma-decimal locale can type a comma. `double.tryParse` only ever
///    accepted '.', so "82,5" used to read back as null and the save was
///    silently dropped.
/// 2. Reopening a record under a grouping-dot locale and saving it untouched
///    changes nothing. This is the x10 guard: under de/es/it, '.' groups, so a
///    field seeded "12.5" and read by a locale-aware parser would store 125.
void main() {
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  group('body weight editor', () {
    const diverId = 'test-diver-id';

    setUp(() async {
      await setUpTestDatabase();
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('$diverId', 'Eric', 1000, 1000)",
      );
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    Future<void> pumpPage(WidgetTester tester) async {
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...base,
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => diverId,
            ),
          ],
          child: const BodyWeightEditPage(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('accepts a comma decimal for weight and height under fr', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';
      await pumpPage(tester);

      await tester.tap(find.text('Add measurement'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Weight (kg)'),
        '82,5',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Height (cm)'),
        '180,5',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final entries = await DiverWeightEntryRepository().getEntriesForDiver(
        diverId,
      );
      expect(entries.single.weightKg, 82.5);
      expect(entries.single.heightCm, 180.5);
    });

    testWidgets('body fat accepts a comma decimal under de (issue #4525)', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';
      await pumpPage(tester);

      await tester.tap(find.text('Add measurement'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Weight (kg)'),
        '80',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Body fat (%)'),
        '18,5',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final entries = await DiverWeightEntryRepository().getEntriesForDiver(
        diverId,
      );
      expect(entries.single.bodyFatPercent, 18.5);
    });

    testWidgets('a dot decimal is not read as grouping under de', (
      tester,
    ) async {
      // "82,5" is what a German diver types; the app must not turn the tenths
      // into hundreds the way a dot-grouping read of "82.5" would.
      Intl.defaultLocale = 'de';
      await pumpPage(tester);

      await tester.tap(find.text('Add measurement'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Weight (kg)'),
        '82,5',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final entries = await DiverWeightEntryRepository().getEntriesForDiver(
        diverId,
      );
      expect(entries.single.weightKg, 82.5);
    });
  });

  group('pre-dive template value bounds', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    // Save runs in one transaction and change log operation, so it needs a
    // database even with the fake repository.
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    PreDiveChecklistTemplateItem valueItem({
      double? valueMin,
      double? valueMax,
    }) => PreDiveChecklistTemplateItem(
      id: 'i1',
      templateId: 'tpl-1',
      title: 'Start pressure',
      itemType: PreDiveItemType.value,
      valueLabel: 'Pressure',
      valueUnit: 'bar',
      valueMin: valueMin,
      valueMax: valueMax,
      createdAt: now,
      updatedAt: now,
    );

    PreDiveChecklistTemplate template() => PreDiveChecklistTemplate(
      id: 'tpl-1',
      diverId: 'diver-1',
      name: 'Backmount Setup',
      createdAt: now,
      updatedAt: now,
    );

    Future<void> pumpPage(WidgetTester tester, _FakeTemplateRepo repo) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            preDiveTemplateRepositoryProvider.overrideWithValue(repo),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-1',
            ),
          ],
          child: const PreDiveTemplateEditPage(templateId: 'tpl-1'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an untouched reopen and save leaves 12.5 alone under de', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';
      final repo = _FakeTemplateRepo(
        template: template(),
        items: [valueItem(valueMin: 12.5, valueMax: 220.5)],
      );
      await pumpPage(tester, repo);

      // Open the item, change nothing, accept: the template is unchanged,
      // so Save stays disabled and nothing rewrites 12.5.
      await tester.tap(find.text('Start pressure'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '12,5'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.savedItems, isNull);
      expect(find.byType(PreDiveTemplateEditPage), findsOneWidget);
    });

    testWidgets('a comma decimal typed under fr reaches the item', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';
      final repo = _FakeTemplateRepo(
        template: template(),
        items: [valueItem()],
      );
      await pumpPage(tester, repo);

      await tester.tap(find.text('Start pressure'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Min (warning)'),
        '12,5',
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.savedItems!.single.valueMin, 12.5);
    });
  });

  group('custom visibility thresholds', () {
    const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));

    Widget host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    testWidgets('an untouched submit keeps the seeded thresholds under de', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.tropical,
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted!.excellentAtOrAboveM, 30);
      expect(submitted!.goodAtOrAboveM, 15);
      expect(submitted!.moderateAtOrAboveM, 5);
    });

    testWidgets('a comma decimal is accepted under fr', (tester) async {
      Intl.defaultLocale = 'fr';
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.tropical,
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(2), '2,5');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted!.moderateAtOrAboveM, 2.5);
    });
  });

  group('prior experience', () {
    setUp(() async {
      await setUpTestDatabase();
    });
    tearDown(tearDownTestDatabase);

    Future<void> pumpPage(WidgetTester tester, Diver diver) async {
      await seedDiver(diver);
      await pumpProfilePage(
        tester,
        path: 'prior',
        page: const PriorExperienceEditPage(),
      );
    }

    Future<Diver> saved() async => (await storedDiver('diver-1'))!;

    // The page writes only the fields that changed (issue #4527, phase 4),
    // so an untouched count is never read back from its grouped text; a
    // change elsewhere must still leave it as stored.
    testWidgets(
      'an untouched four-digit dive count under de survives another change',
      (tester) async {
        Intl.defaultLocale = 'de';
        await pumpPage(
          tester,
          profileDiver(
            priorDiveCount: 1250,
            priorDiveTimeSeconds: 2 * 3600 + 30 * 60,
          ),
        );
        expect(barAction(tester, 'Save').onPressed, isNull);

        await typeInto(tester, 'Minutes', '45');
        await tapBar(tester, 'Save');

        final diver = await saved();
        expect(diver.priorDiveCount, 1250);
        expect(diver.priorDiveTimeSeconds, 2 * 3600 + 45 * 60);
      },
    );

    testWidgets('a grouped dive count is accepted under de', (tester) async {
      Intl.defaultLocale = 'de';
      await pumpPage(tester, profileDiver());

      await typeInto(tester, 'Prior dives', '1.250');
      await tapBar(tester, 'Save');

      expect((await saved()).priorDiveCount, 1250);
    });
  });
}

/// Stubs the reads the pre-dive template editor performs and captures the
/// items it saves, so no database is needed.
class _FakeTemplateRepo implements PreDiveTemplateRepository {
  _FakeTemplateRepo({this.template, this.items = const []});

  final PreDiveChecklistTemplate? template;
  final List<PreDiveChecklistTemplateItem> items;

  List<PreDiveChecklistTemplateItem>? savedItems;

  @override
  Future<PreDiveChecklistTemplate?> getTemplateById(String id) async =>
      template;

  @override
  Future<List<PreDiveChecklistTemplateItem>> getItemsForTemplate(
    String templateId,
  ) async => items;

  @override
  Future<List<PreDiveChecklistTemplateSection>> getSectionsForTemplate(
    String templateId,
  ) async => const [];

  @override
  Future<void> updateTemplate(PreDiveChecklistTemplate template) async {}

  @override
  Future<void> saveItems(
    String templateId,
    List<PreDiveChecklistTemplateItem> items,
  ) async {
    savedItems = items;
  }

  @override
  Future<void> saveSections(
    String templateId,
    List<PreDiveChecklistTemplateSection> sections,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
