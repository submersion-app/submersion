import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_crop_sheet.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../media/presentation/support/media_widget_harness.dart';
import '../../domain/identification_rules_fixtures.dart';

/// A species tag's crops on a locked photo or video (issue #5024).
class _Identifications extends MediaIdentificationRepository {
  _Identifications(this.rows);

  final List<MediaIdentification> rows;

  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) async => rows;
}

const grunt = SpeciesTagChip(
  speciesId: 'sp_grunt',
  storedName: 'French Grunt',
  category: SpeciesCategory.fish,
  isBuiltIn: false,
);

MediaIdentification gruntAt(String id, double x) => ruleId(
  id,
  decision: IdentificationDecision.accepted,
  decidedSpeciesId: 'sp_grunt',
  box: IdentificationBox(x: x, y: 0.2, width: 0.1, height: 0.1),
);

/// Pumps a viewer whose "open" button opens [grunt]'s crops on photo p1,
/// with [rows] as its identifications.
Future<void> pumpOpener(
  WidgetTester tester, {
  required List<MediaIdentification> rows,
  MediaType type = MediaType.photo,
  List<dynamic> extra = const [],
}) async {
  final overrides = await getBaseOverrides();
  final item = testMediaItem(id: 'p1', diveId: 'd1', mediaType: type);
  final router = GoRouter(
    initialLocation: '/viewer',
    routes: [
      GoRoute(
        path: '/viewer',
        builder: (_, _) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () =>
                  openSpeciesCrops(context, ref, item: item, chip: grunt),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/species/:id',
        builder: (_, state) =>
            Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    testAppRouter(
      router: router,
      locale: const Locale('en'),
      overrides: [
        ...overrides,
        mediaIdentificationRepositoryProvider.overrideWithValue(
          _Identifications(rows),
        ),
        identificationCropProvider.overrideWith((ref, key) async => null),
        ...extra,
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
  });

  group('opening', () {
    testWidgets('with no crop the tag opens the species page', (tester) async {
      await pumpOpener(tester, rows: const []);
      expect(find.text('DETAIL sp_grunt'), findsOneWidget);
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsNothing);
    });

    testWidgets('with labels off the tag opens the species page', (
      tester,
    ) async {
      marineLifeIdEnabled = false;
      await pumpOpener(tester, rows: [gruntAt('a', 0.1)]);
      expect(find.text('DETAIL sp_grunt'), findsOneWidget);
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsNothing);
    });

    testWidgets('with a crop the sheet opens', (tester) async {
      await pumpOpener(tester, rows: [gruntAt('a', 0.1)]);
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsOneWidget);
      expect(find.text('DETAIL sp_grunt'), findsNothing);
    });
  });
}
