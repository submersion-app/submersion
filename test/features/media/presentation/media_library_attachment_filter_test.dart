import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_attachment_filter_section.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Attached to facet in the library UI (issue #4224): the filter sheet
/// section and the active-filter chip.
void main() {
  Widget app(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  group('MediaLibraryAttachmentFilterSection', () {
    testWidgets('lists the four kinds under its title', (tester) async {
      await tester.pumpWidget(
        app(
          MediaLibraryAttachmentFilterSection(
            selected: const {MediaAttachmentKind.dive},
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Attached to'), findsOneWidget);
      for (final label in ['Dive', 'Site', 'Equipment', 'Unlinked']) {
        expect(find.widgetWithText(FilterChip, label), findsOneWidget);
      }
      final dive = tester.widget<FilterChip>(
        find.byKey(const ValueKey('media_filter_attached_dive')),
      );
      expect(dive.selected, isTrue);
      final site = tester.widget<FilterChip>(
        find.byKey(const ValueKey('media_filter_attached_site')),
      );
      expect(site.selected, isFalse);
    });

    testWidgets('a tap adds a kind, a second tap removes it', (tester) async {
      var selected = <MediaAttachmentKind>{};
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => app(
            MediaLibraryAttachmentFilterSection(
              selected: selected,
              onChanged: (next) => setState(() => selected = next),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Site'));
      await tester.pump();
      expect(selected, {MediaAttachmentKind.site});

      await tester.tap(find.text('Equipment'));
      await tester.pump();
      expect(selected, {
        MediaAttachmentKind.site,
        MediaAttachmentKind.equipment,
      });

      await tester.tap(find.text('Site'));
      await tester.pump();
      expect(selected, {MediaAttachmentKind.equipment});
    });
  });

  group('active filter chip', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          sitesProvider.overrideWith((ref) async => const []),
          allTripsProvider.overrideWith((ref) async => const []),
          allSpeciesProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<void> pump(WidgetTester tester, MediaLibraryFilter filter) async {
      tester.view.physicalSize = const Size(1600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      container.read(mediaLibraryFilterProvider.notifier).state = filter;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(const MediaLibraryActiveFilterChips()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('names the picked kinds in one chip, in sheet order', (
      tester,
    ) async {
      await pump(
        tester,
        const MediaLibraryFilter(
          attachedTo: {MediaAttachmentKind.equipment, MediaAttachmentKind.site},
        ),
      );

      expect(find.byType(InputChip), findsOneWidget);
      expect(find.text('Attached to: Site, Equipment'), findsOneWidget);
    });

    testWidgets('deleting the chip clears the whole facet', (tester) async {
      await pump(
        tester,
        const MediaLibraryFilter(
          attachedTo: {MediaAttachmentKind.dive, MediaAttachmentKind.unlinked},
        ),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(InputChip),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pumpAndSettle();

      final filter = container.read(mediaLibraryFilterProvider);
      expect(filter.attachedTo, isEmpty);
      expect(filter.isEmpty, isTrue);
      expect(find.byType(InputChip), findsNothing);
    });
  });
}
