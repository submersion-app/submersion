import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// One removable chip per selected tag in the library's filter strip
/// (issue #1970).
void main() {
  final now = DateTime(2026);
  final wreck = Tag(id: 'wreck', name: 'Wreck', createdAt: now, updatedAt: now);
  final fish = Tag(id: 'fish', name: 'Fish', createdAt: now, updatedAt: now);

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
        allSpeciesProvider.overrideWith((ref) async => []),
        tagsProvider.overrideWith((ref) async => [wreck, fish]),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, Set<String> tagIds) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    container.read(mediaLibraryFilterProvider.notifier).state =
        MediaLibraryFilter(tagIds: tagIds);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MediaLibraryActiveFilterChips()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each tag gets a chip, and removing one keeps the rest', (
    tester,
  ) async {
    await pump(tester, {'wreck', 'fish'});

    expect(find.widgetWithText(InputChip, 'Wreck'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Fish'), findsOneWidget);

    final wreckChip = tester.widget<InputChip>(
      find.widgetWithText(InputChip, 'Wreck'),
    );
    wreckChip.onDeleted!();
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).tagIds, {'fish'});
    expect(find.widgetWithText(InputChip, 'Wreck'), findsNothing);
  });

  testWidgets('a tag that no longer exists is still a clearable chip', (
    tester,
  ) async {
    await pump(tester, {'gone'});

    final chip = find.widgetWithText(InputChip, 'Tags');
    expect(chip, findsOneWidget);
    tester.widget<InputChip>(chip).onDeleted!();
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).isEmpty, isTrue);
  });
}
