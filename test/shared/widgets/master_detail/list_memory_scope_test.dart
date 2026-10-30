import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/shared/widgets/master_detail/list_memory_scope.dart';
import 'package:submersion/shared/widgets/master_detail/remembered_selection.dart';

import '../../../helpers/mock_providers.dart';

/// A record id from one diver's log means nothing in another's, and a shared
/// site or trip would otherwise bring the last diver's place back (#3301).
void main() {
  late ProviderContainer container;

  final highlights = [
    highlightedDiveIdProvider,
    highlightedSiteIdProvider,
    highlightedEquipmentIdProvider,
    highlightedBuddyIdProvider,
    highlightedTripIdProvider,
    highlightedDiveCenterIdProvider,
    highlightedCertificationIdProvider,
    highlightedCourseIdProvider,
  ];

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ListMemoryScope(child: SizedBox()),
      ),
    );
  }

  void rememberEverything() {
    for (final highlight in highlights) {
      container.read(highlight.notifier).state = 'kept';
    }
    container.read(closedPaneRecordProvider.notifier).state = const {
      'sites': 'kept',
    };
  }

  testWidgets('switching diver forgets every list\'s place', (tester) async {
    await pump(tester);
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('diver-a');
    rememberEverything();

    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('diver-b');
    await tester.pump();

    for (final highlight in highlights) {
      expect(container.read(highlight), isNull);
    }
    expect(container.read(closedPaneRecordProvider), isEmpty);
  });

  testWidgets('the diver loading at startup forgets nothing', (tester) async {
    await pump(tester);
    rememberEverything();

    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('diver-a');
    await tester.pump();

    expect(container.read(highlightedSiteIdProvider), 'kept');
    expect(container.read(closedPaneRecordProvider), {'sites': 'kept'});
  });

  // However a list's record is opened (a row, the keyboard, the detail
  // page's previous and next, the table, the map), the pane is no longer
  // one the diver emptied (#3301).
  testWidgets('opening another record forgets that list\'s emptied pane', (
    tester,
  ) async {
    await pump(tester);
    container.read(closedPaneRecordProvider.notifier).state = const {
      'dives': 'd1',
      'dive-centers': 'c1',
      'sites': 's1',
    };

    container.read(highlightedDiveIdProvider.notifier).state = 'd2';
    container.read(highlightedDiveCenterIdProvider.notifier).state = 'c2';
    await tester.pump();

    expect(container.read(closedPaneRecordProvider), {'sites': 's1'});
  });

  testWidgets('clearing a highlight keeps the emptied pane', (tester) async {
    await pump(tester);
    container.read(highlightedSiteIdProvider.notifier).state = 's1';
    container.read(closedPaneRecordProvider.notifier).state = const {
      'sites': 's1',
    };

    container.read(highlightedSiteIdProvider.notifier).state = null;
    await tester.pump();

    expect(container.read(closedPaneRecordProvider), {'sites': 's1'});
  });

  // A pushed dive list puts back the tab's highlight and then its emptied
  // pane; the highlight coming back must not clear the pane it restores.
  testWidgets('a pushed list going away keeps the tab\'s emptied pane', (
    tester,
  ) async {
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
    late VoidCallback restore;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ListMemoryScope(
          child: Consumer(
            builder: (context, ref, _) {
              restore = const DiveListReturn(
                filter: DiveFilterState(),
                highlightedDiveId: 'd0',
                closedPaneDiveId: 'd0',
              ).bindRestore(ref);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    // In the pushed list the diver picked another dive.
    container.read(highlightedDiveIdProvider.notifier).state = 'd5';
    container.read(closedPaneRecordProvider.notifier).state = const {};
    await tester.pump();

    restore();
    await tester.pump();

    expect(container.read(highlightedDiveIdProvider), 'd0');
    expect(container.read(closedPaneRecordProvider), {'dives': 'd0'});
  });
}
