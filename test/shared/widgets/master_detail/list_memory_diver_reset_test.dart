import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/shared/widgets/master_detail/list_memory_diver_reset.dart';
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
        child: const ListMemoryDiverReset(child: SizedBox()),
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
}
