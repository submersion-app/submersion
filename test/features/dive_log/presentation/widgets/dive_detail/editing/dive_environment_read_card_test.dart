import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_environment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The Environment card as the dive page shows it while reading, and
/// with its pencil once the page is unlocked (issue #4527).
void main() {
  final bare = Dive(id: 'dive', dateTime: DateTime(2024, 6, 1, 10));
  final full = bare.copyWith(
    airTemp: 21,
    windSpeed: 4,
    windDirection: CurrentDirection.east,
    cloudCover: CloudCover.clear,
    precipitation: Precipitation.none,
    humidity: 60,
    weatherDescription: 'Fine',
    weatherSource: WeatherSource.manual,
    weatherFetchedAt: DateTime(2024, 6, 2),
    currentDirection: CurrentDirection.north,
    currentStrength: CurrentStrength.light,
    swellHeight: 1.5,
    surfaceConditions: 'Calm',
    entryMethod: EntryMethod.shore,
    exitMethod: EntryMethod.boat,
  );

  group('the read card', () {
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    Future<void> pumpCard(
      WidgetTester tester, {
      RecordEditController<Dive>? controller,
    }) async {
      final card = DiveEnvironmentSection(dive: full);
      await tester.pumpWidget(
        ProviderScope(
          overrides: await getBaseOverrides(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: controller == null
                    ? card
                    : RecordEditScope<Dive>(
                        controller: controller,
                        child: RecordCardFrame<Dive>(
                          card: diveEditCards[DiveDetailSectionId.environment]!,
                          child: card,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('its title is the shared header', (tester) async {
      await pumpCard(tester);

      final header = find.byType(RecordCardHeader);
      expect(header, findsOneWidget);
      final title = tester.widget<Text>(
        find.descendant(of: header, matching: find.text('Environment')),
      );
      expect(
        title.style,
        Theme.of(tester.element(header)).textTheme.titleMedium,
      );
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('unlocked, it gains the pencil', (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(full);
      addTearDown(controller.dispose);

      await pumpCard(tester, controller: controller);

      expect(find.byTooltip('Edit Environment'), findsOneWidget);
    });
  });
}
