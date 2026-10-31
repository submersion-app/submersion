import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_text_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_hero_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

import '../../../../helpers/mock_providers.dart';

/// Rebuild scope of the dive detail page (#3816).
///
/// Flutter skips a subtree when its parent hands back the identical widget
/// instance, so a widget instance that survives a provider change is proof
/// that nothing above it rebuilt into it. These tests compare instances, which
/// needs no hook in production code and cannot pass by accident: the tank edit
/// test below is the control that shows the chart's instance does change when
/// the chart's own inputs do.
void main() {
  late Dive current;
  late List<BuddyWithRole> buddies;
  late List<Sighting> sightings;
  late Duration? surfaceInterval;
  late Signature? signature;
  late MockSettingsNotifier settings;
  var failDive = false;

  // The same instance each read, so a refresh ends where it began.
  const dataSources = <DiveDataSource>[];

  Dive testDive() => createTestDiveWithBottomTime().copyWith(
    notes: 'First note',
    profile: List.generate(
      6,
      (i) => DiveProfilePoint(
        timestamp: i * 60,
        depth: (i < 3 ? i * 8.0 : (5 - i) * 8.0),
      ),
    ),
    tanks: const [
      DiveTank(id: 'tank-1', volume: 11.1, startPressure: 200, endPressure: 60),
    ],
    gear: looseGear(const [
      EquipmentItem(
        id: 'eq-1',
        name: 'Regulator',
        type: EquipmentType.regulator,
      ),
    ]),
  );

  BuddyWithRole samRivers() => BuddyWithRole(
    buddy: Buddy(
      id: 'buddy-1',
      name: 'Sam Rivers',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    roles: [DiveRole.builtInBuddy()],
  );

  Future<ProviderContainer> pumpDetail(
    WidgetTester tester, {
    AppSettings? initialSettings,
  }) async {
    current = testDive();
    failDive = false;
    buddies = const [];
    sightings = const [];
    surfaceInterval = null;
    signature = null;
    settings = MockSettingsNotifier(
      initialSettings ?? const AppSettings(hasAcceptedPlanningDisclaimer: true),
    );
    final base = await getBaseOverrides(settingsNotifier: settings);
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final id = current.id;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          // Read from the variable, so an invalidate is the same refresh the
          // detail change tick causes.
          diveProvider(id).overrideWith((ref) async {
            if (failDive) throw StateError('the read failed');
            return current;
          }),
          profileAnalysisProvider(
            id,
          ).overrideWith((ref) async => ProfileAnalysis.empty()),
          diveDataSourcesProvider(id).overrideWith((ref) async => dataSources),
          gasSwitchesProvider(
            id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(
            id,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          sourceProfilesProvider(
            id,
          ).overrideWith((ref) async => <String, SourceProfile>{}),
          weeklyOtuProvider(id).overrideWith((ref) async => 0.0),
          buddiesForDiveProvider(id).overrideWith((ref) async => buddies),
          diveSightingsProvider(id).overrideWith((ref) async => sightings),
          surfaceIntervalProvider(
            id,
          ).overrideWith((ref) async => surfaceInterval),
          signatureForDiveProvider(id).overrideWith((ref) async => signature),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveDetailPage(diveId: id, embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  DiveProfileChart chart(WidgetTester tester) =>
      tester.widget<DiveProfileChart>(find.byType(DiveProfileChart));

  DiveProfileChartHost host(WidgetTester tester) =>
      tester.widget<DiveProfileChartHost>(find.byType(DiveProfileChartHost));

  MarkdownNotesView notes(WidgetTester tester) =>
      tester.widget<MarkdownNotesView>(find.byType(MarkdownNotesView));

  group('the chart keeps its widget instance through', () {
    testWidgets('a refresh that leaves the dive unchanged', (tester) async {
      final container = await pumpDetail(tester);
      final before = chart(tester);

      container.invalidate(diveProvider(current.id));
      await settle(tester);

      expect(identical(chart(tester), before), isTrue);
    });

    testWidgets('a notes edit, which still reaches the notes card', (
      tester,
    ) async {
      final container = await pumpDetail(tester);
      final before = chart(tester);

      current = current.copyWith(notes: 'Second note');
      container.invalidate(diveProvider(current.id));
      await settle(tester);

      expect(find.textContaining('Second note'), findsOneWidget);
      expect(identical(chart(tester), before), isTrue);
    });

    testWidgets('marking the dive a favorite', (tester) async {
      final container = await pumpDetail(tester);
      final before = chart(tester);

      current = current.copyWith(isFavorite: true);
      container.invalidate(diveProvider(current.id));
      await settle(tester);

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(identical(chart(tester), before), isTrue);
    });

    testWidgets('buddies arriving', (tester) async {
      final container = await pumpDetail(tester);
      final before = chart(tester);

      buddies = [samRivers()];
      container.invalidate(buddiesForDiveProvider(current.id));
      await settle(tester);

      expect(find.text('Sam Rivers'), findsOneWidget);
      expect(identical(chart(tester), before), isTrue);
    });

    testWidgets('a sighting arriving', (tester) async {
      final container = await pumpDetail(tester);
      final before = chart(tester);

      sightings = const [
        Sighting(
          id: 's-1',
          diveId: 'test-dive-1',
          speciesId: 'sp-1',
          speciesName: 'Manta',
        ),
      ];
      container.invalidate(diveSightingsProvider(current.id));
      await settle(tester);

      expect(find.textContaining('Manta'), findsOneWidget);
      expect(identical(chart(tester), before), isTrue);
    });

    testWidgets('the surface interval resolving', (tester) async {
      final container = await pumpDetail(tester);
      final before = chart(tester);

      surfaceInterval = const Duration(hours: 2);
      container.invalidate(surfaceIntervalProvider(current.id));
      await settle(tester);

      expect(identical(chart(tester), before), isTrue);
    });

    testWidgets('the card around it rebuilding for a source refresh', (
      tester,
    ) async {
      final container = await pumpDetail(tester);
      final before = host(tester);

      container.invalidate(sourceProfilesProvider(current.id));
      container.invalidate(diveDataSourcesProvider(current.id));
      await settle(tester);

      expect(identical(host(tester), before), isTrue);
    });

    testWidgets('folding the Equipment card', (tester) async {
      final container = await pumpDetail(tester);
      final before = chart(tester);

      await container
          .read(collapsibleSectionProvider.notifier)
          .setEquipmentExpanded(false);
      await settle(tester);

      expect(identical(chart(tester), before), isTrue);
    });

    testWidgets('a setting the chart does not read', (tester) async {
      final container = await pumpDetail(tester);
      final before = chart(tester);

      await container.read(settingsProvider.notifier).setShowDiveFigure(true);
      await settle(tester);

      expect(identical(chart(tester), before), isTrue);
    });

    testWidgets('unfolding a section in the list layout', (tester) async {
      final container = await pumpDetail(
        tester,
        initialSettings: const AppSettings(
          hasAcceptedPlanningDisclaimer: true,
          diveDetailLayout: DiveDetailLayout.list,
        ),
      );
      await settings.setDiveDetailSectionExpanded(
        DiveDetailSectionId.profile,
        true,
      );
      await settle(tester);
      final before = chart(tester);

      await container
          .read(settingsProvider.notifier)
          .setDiveDetailSectionExpanded(DiveDetailSectionId.notes, true);
      await settle(tester);

      expect(identical(chart(tester), before), isTrue);
    });
  });

  // A change to anything else about the dive leaves the chart as it was, so a
  // field the chart reads and DiveChartInputs does not compare would show its
  // old value until something else changes.
  test('DiveChartInputs compares every dive field the chart reads', () {
    final widgets = p.join(
      'lib',
      'features',
      'dive_log',
      'presentation',
      'widgets',
    );
    final section = File(
      p.join(widgets, 'dive_detail', 'dive_detail_profile_section.dart'),
    ).readAsStringSync();
    final host = File(
      p.join(widgets, 'dive_profile_chart_host.dart'),
    ).readAsStringSync();
    final inputs = RegExp(
      r'get props => \[(.*?)\];',
      dotAll: true,
    ).firstMatch(section)!.group(1)!;
    Set<String> fieldsReadIn(String source) => {
      for (final match in RegExp(r"(?<![/'])\bdive\.(\w+)").allMatches(source))
        match.group(1)!,
    };

    expect(fieldsReadIn(inputs), isNotEmpty);
    expect(
      fieldsReadIn(section + host).difference(fieldsReadIn(inputs)),
      isEmpty,
    );

    // A helper handed the whole dive reads fields the scan above cannot see.
    // These three read only compared fields; a new one needs the same check.
    expect(
      {
        for (final match in RegExp(
          r'(\w+)\((?:[\w.]+, )*dive\b(?![.:])',
        ).allMatches(section + host))
          match.group(1),
      },
      {
        'DiveChartInputs',
        'calculateSacNormalizationFactor',
        'watchChartProfile',
      },
    );
  });

  testWidgets('a refresh that fails still reaches the error screen', (
    tester,
  ) async {
    final container = await pumpDetail(tester);

    failDive = true;
    container.invalidate(diveProvider(current.id));
    await settle(tester);

    expect(find.textContaining('the read failed'), findsOneWidget);
    expect(find.byType(DiveProfileChart), findsNothing);
  });

  testWidgets('folding the profile card keeps the overlaid sources', (
    tester,
  ) async {
    final container = await pumpDetail(
      tester,
      initialSettings: const AppSettings(
        hasAcceptedPlanningDisclaimer: true,
        diveDetailLayout: DiveDetailLayout.list,
      ),
    );
    await settings.setDiveDetailSectionExpanded(
      DiveDetailSectionId.profile,
      true,
    );
    await settle(tester);
    container.read(overlaySourcesProvider(current.id).notifier).state = {
      'source-2',
    };
    await settle(tester);

    await settings.setDiveDetailSectionExpanded(
      DiveDetailSectionId.profile,
      false,
    );
    await settle(tester);

    expect(find.byType(DiveProfileChart), findsNothing);
    expect(container.read(overlaySourcesProvider(current.id)), {'source-2'});
  });

  testWidgets('a tank edit does rebuild the chart', (tester) async {
    final container = await pumpDetail(tester);
    final before = chart(tester);

    current = current.copyWith(
      tanks: const [
        DiveTank(
          id: 'tank-1',
          volume: 11.1,
          startPressure: 200,
          endPressure: 90,
        ),
      ],
    );
    container.invalidate(diveProvider(current.id));
    await settle(tester);

    expect(identical(chart(tester), before), isFalse);
    expect(chart(tester).tanks?.single.endPressure, 90);
  });

  testWidgets('a sources refresh leaves the header alone', (tester) async {
    final container = await pumpDetail(tester);
    final before = tester.widget(find.byType(DiveHeroHeader));

    container.invalidate(diveDataSourcesProvider(current.id));
    await settle(tester);

    expect(
      identical(tester.widget(find.byType(DiveHeroHeader)), before),
      isTrue,
    );
  });

  testWidgets('sections appearing on both sides of a card leave it mounted', (
    tester,
  ) async {
    // One side alone would pass without the section keys: Flutter matches a
    // list of children from both ends, and only the part between the first
    // and the last difference needs keys to find its way.
    final container = await pumpDetail(tester);
    final before = tester.element(find.byType(DiveNotesSection));

    current = current.copyWith(
      customFields: const [DiveCustomField(id: 'field-1', key: 'Permit')],
      tags: [
        Tag(
          id: 'tag-1',
          name: 'Wreck',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    container.invalidate(diveProvider(current.id));
    await settle(tester);

    expect(find.byType(DiveTagsSection), findsOneWidget);
    expect(find.byType(DiveCustomFieldsSection), findsOneWidget);
    expect(
      identical(tester.element(find.byType(DiveNotesSection)), before),
      isTrue,
      reason: 'a remount would drop any state inside the section',
    );
  });

  group('the notes card keeps its widget instance through', () {
    testWidgets('range mode turning on', (tester) async {
      final container = await pumpDetail(tester);
      final before = notes(tester);

      container
          .read(rangeSelectionProvider(current.id).notifier)
          .enableRangeMode();
      await settle(tester);

      expect(identical(notes(tester), before), isTrue);
    });

    testWidgets('an overlay being toggled', (tester) async {
      final container = await pumpDetail(tester);
      final before = notes(tester);

      container.read(overlaySourcesProvider(current.id).notifier).state = {
        'source-2',
      };
      await settle(tester);

      expect(identical(notes(tester), before), isTrue);
    });

    testWidgets('a sighting arriving', (tester) async {
      final container = await pumpDetail(tester);
      final before = notes(tester);

      sightings = const [
        Sighting(
          id: 's-1',
          diveId: 'test-dive-1',
          speciesId: 'sp-1',
          speciesName: 'Manta',
        ),
      ];
      container.invalidate(diveSightingsProvider(current.id));
      await settle(tester);

      expect(find.textContaining('Manta'), findsOneWidget);
      expect(identical(notes(tester), before), isTrue);
    });

    testWidgets('a refresh that leaves the dive unchanged', (tester) async {
      final container = await pumpDetail(tester);
      final before = notes(tester);

      container.invalidate(diveProvider(current.id));
      await settle(tester);

      expect(identical(notes(tester), before), isTrue);
    });
  });
}
