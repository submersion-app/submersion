import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_card_presence.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../../../helpers/mock_providers.dart' show Override;

/// Whether the dive page is showing a card, which the Add strip needs to
/// know before it offers one (issue #4527).
void main() {
  final bare = Dive(id: 'dive', dateTime: DateTime(2023, 9, 1, 10));

  /// Asks [diveCardIsShown] from inside a widget, after its providers have
  /// had a frame to answer.
  Future<bool> shown(
    WidgetTester tester,
    DiveDetailSectionId id,
    Dive dive, {
    List<Override> overrides = const [],
  }) async {
    late bool result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: Consumer(
          builder: (context, ref, _) {
            result = diveCardIsShown(ref, id, dive);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return result;
  }

  testWidgets('notes is always shown', (tester) async {
    expect(await shown(tester, DiveDetailSectionId.notes, bare), isTrue);
  });

  testWidgets('tags follows the dive', (tester) async {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final tagged = bare.copyWith(
      tags: [Tag(id: 't', name: 'Wreck', createdAt: epoch, updatedAt: epoch)],
    );

    expect(await shown(tester, DiveDetailSectionId.tags, bare), isFalse);
    expect(await shown(tester, DiveDetailSectionId.tags, tagged), isTrue);
  });

  testWidgets('environment follows what the dive has logged', (tester) async {
    expect(await shown(tester, DiveDetailSectionId.environment, bare), isFalse);
    expect(
      await shown(
        tester,
        DiveDetailSectionId.environment,
        bare.copyWith(airTemp: 29),
      ),
      isTrue,
    );
    expect(
      await shown(
        tester,
        DiveDetailSectionId.environment,
        bare.copyWith(currentStrength: CurrentStrength.light),
      ),
      isTrue,
    );
  });

  // The Environment card also carries satellite water conditions, which
  // only a provider knows about. A dive with nothing logged still shows it.
  testWidgets('environment is shown for satellite conditions alone', (
    tester,
  ) async {
    final atReef = bare.copyWith(
      site: const DiveSite(
        id: 'site',
        name: 'Coral Garden',
        location: GeoPoint(-16.5, 145.8),
        waterType: WaterType.salt,
      ),
    );
    final health = ReefHealth(
      sst: 30.1,
      sstAnomaly: 0.8,
      degreeHeatingWeeks: 4.2,
      alertLevel: BleachingAlertLevel.watch,
      observedAt: DateTime.utc(2023, 9, 1, 12),
    );

    final result = await shown(
      tester,
      DiveDetailSectionId.environment,
      atReef,
      overrides: [
        reefHealthForDiveProvider.overrideWith(
          (ref, request) async => ReefPart.ok(health),
        ),
        reefHabitatProvider.overrideWith(
          (ref, location) async => const ReefPart.ok(ReefHabitat(onReef: true)),
        ),
      ],
    );

    expect(result, isTrue);
  });

  testWidgets('a section with no card is shown', (tester) async {
    expect(await shown(tester, DiveDetailSectionId.profile, bare), isTrue);
  });
}
