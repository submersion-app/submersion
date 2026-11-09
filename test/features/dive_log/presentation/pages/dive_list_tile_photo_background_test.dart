import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/card_photo_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_card_photo_background.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier(CardViewConfig config)
    : super.withMode(ListViewMode.detailed) {
    state = config;
  }
}

const _photo = CardPhoto(mediaId: 'm1');

void main() {
  Future<List<dynamic>> overrides({
    required bool photoOn,
    bool mapOn = false,
    CardPhoto? photo = _photo,
  }) async => [
    ...await getBaseOverrides(),
    detailedCardConfigProvider.overrideWith(
      (ref) => _TestCardConfigNotifier(CardViewConfig.defaultDetailed()),
    ),
    showPhotoBackgroundOnDiveCardsProvider.overrideWithValue(photoOn),
    showMapBackgroundOnDiveCardsProvider.overrideWithValue(mapOn),
    cardPhotoForDiveProvider.overrideWith((ref, id) => photo),
    // No media row: the background stays on the card's own fill, so the
    // test never resolves an image.
    mediaByIdProvider.overrideWith((ref, id) async => null),
  ];

  Widget tile({bool highlighted = false}) => DiveListTile(
    diveId: 'd1',
    diveNumber: 7,
    dateTime: DateTime(2026, 3, 15),
    siteName: 'Blue Hole',
    maxDepth: 30.0,
    duration: const Duration(minutes: 40),
    siteLatitude: 17.3,
    siteLongitude: -87.5,
    isHighlighted: highlighted,
  );

  Color? titleColor(WidgetTester tester) =>
      tester.widget<Text>(find.text('Blue Hole')).style?.color;

  /// The secondary colour: the chevron is drawn in it, as the location,
  /// date line and extra-field labels are.
  Color? detailColor(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(Icons.chevron_right)).color;

  testWidgets('draws the photo background when the setting is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(photoOn: true, mapOn: true),
        child: tile(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiveCardPhotoBackground), findsOneWidget);
    // The photo wins over the map.
    expect(find.byType(CachedNetworkImage), findsNothing);
    // Light theme: the overlay is light, so the text is dark.
    expect(titleColor(tester), Colors.black87);
  });

  testWidgets('falls back to the map when the dive has no photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(photoOn: true, mapOn: true, photo: null),
        child: tile(),
      ),
    );
    await tester.pump();
    expect(find.byType(DiveCardPhotoBackground), findsNothing);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('on the light theme a photo card draws its details as dark as '
      'its title', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(photoOn: true),
        child: tile(),
      ),
    );
    await tester.pumpAndSettle();
    expect(detailColor(tester), Colors.black87);
    expect(detailColor(tester), titleColor(tester));
  });

  testWidgets('a card without a photo keeps its lighter details', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(photoOn: true, photo: null),
        child: tile(),
      ),
    );
    await tester.pumpAndSettle();
    expect(detailColor(tester), Colors.black54);
  });

  testWidgets('draws no photo when the setting is off', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(photoOn: false),
        child: tile(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiveCardPhotoBackground), findsNothing);
  });

  testWidgets('the selection fill replaces the photo', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(photoOn: true),
        child: tile(highlighted: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiveCardPhotoBackground), findsNothing);
  });

  test('the overlay matches the theme', () {
    expect(
      DiveCardPhotoScrim.textBase(Brightness.dark).computeLuminance(),
      lessThan(0.5),
    );
    expect(
      DiveCardPhotoScrim.textBase(Brightness.light).computeLuminance(),
      greaterThan(0.5),
    );
    final dark = DiveCardPhotoScrim.gradient(Brightness.dark, 0.6);
    final light = DiveCardPhotoScrim.gradient(Brightness.light, 0.6);
    expect(dark.colors.every((c) => c.r == 0), isTrue);
    expect(light.colors.every((c) => c.r == 1), isTrue);
  });

  test('the overlay follows the chosen opacity', () {
    final faint = DiveCardPhotoScrim.gradient(Brightness.light, 0.3);
    final heavy = DiveCardPhotoScrim.gradient(Brightness.light, 0.9);
    for (var i = 0; i < faint.colors.length; i++) {
      expect(faint.colors[i].a, lessThan(heavy.colors[i].a));
    }
    // Lighter at the top than at the bottom, never past fully opaque.
    expect(heavy.colors.first.a, lessThan(heavy.colors.last.a));
    expect(heavy.colors.last.a, lessThanOrEqualTo(1));
  });
}
