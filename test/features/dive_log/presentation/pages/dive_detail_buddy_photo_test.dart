import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

typedef Override = riverpod.Override;

/// Mock SettingsNotifier that does not access the database.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(10, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

/// Only the Buddies section visible, so the tile is on screen without
/// scrolling past the profile chart.
AppSettings _buddiesOnly() => AppSettings(
  diveDetailSections: DiveDetailSectionId.values
      .map(
        (id) => DiveDetailSectionConfig(
          id: id,
          visible: id == DiveDetailSectionId.buddies,
        ),
      )
      .toList(),
);

BuddyWithRole _buddy({Uint8List? photo}) => BuddyWithRole(
  buddy: Buddy(
    id: 'b1',
    name: 'Alice Adams',
    photo: photo,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  role: DiveRole.builtInBuddy(),
);

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences prefs,
  BuddyWithRole buddy,
) async {
  final dive = Dive(id: 'd1', dateTime: DateTime(2026, 3, 15, 10, 0));

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        diveProvider(dive.id).overrideWith((ref) async => dive),
        diveDataSourcesProvider(
          dive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
        settingsProvider.overrideWith(
          (ref) => _MockSettingsNotifier(_buddiesOnly()),
        ),
        buddiesForDiveProvider(dive.id).overrideWith((ref) async => [buddy]),
        diveSightingsProvider(
          dive.id,
        ).overrideWith((ref) async => <Sighting>[]),
        buddySignaturesForDiveProvider(
          dive.id,
        ).overrideWith((ref) async => <Signature>[]),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: dive.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('a buddy with a stored photo shows it on the dive', (
    tester,
  ) async {
    await _pump(tester, prefs, _buddy(photo: _jpeg()));

    expect(find.text('Alice Adams'), findsOneWidget);
    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(
      avatar.photo,
      isNotNull,
      reason:
          'the dive buddy tile must render the stored photo, not just '
          'initials',
    );
  });

  testWidgets('a buddy with no photo still falls back to initials', (
    tester,
  ) async {
    await _pump(tester, prefs, _buddy());

    expect(find.text('Alice Adams'), findsOneWidget);
    expect(find.text('AA'), findsOneWidget);
  });
}
