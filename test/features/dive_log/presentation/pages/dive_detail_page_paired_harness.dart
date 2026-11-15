import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/map_style.dart';
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

/// The dive detail page as the paired-card tests pump it: a dive, the
/// diver's section setup, and every read a paired card makes answered
/// without a database. Shared by dive_detail_page_paired_sections_test (which
/// sections pair) and dive_detail_page_card_layout_test (how a pair lays out).

typedef Override = riverpod.Override;

/// Settings that never touch the database; the map style can be changed.
class PairedSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  PairedSettingsNotifier(super.initial);

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Settings showing only [visible], in the default order.
AppSettings settingsWithVisibleSections(List<DiveDetailSectionId> visible) =>
    AppSettings(
      diveDetailSections: [
        for (final id in DiveDetailSectionId.values)
          DiveDetailSectionConfig(id: id, visible: visible.contains(id)),
      ],
    );

/// The detail page for [dive], with [settings] and [extraOverrides].
Widget pairedDetailPage({
  required Dive dive,
  required AppSettings settings,
  List<Override> extraOverrides = const [],
}) => ProviderScope(
  overrides: [
    diveProvider(dive.id).overrideWith((ref) async => dive),
    diveDataSourcesProvider(
      dive.id,
    ).overrideWith((ref) async => <DiveDataSource>[]),
    settingsProvider.overrideWith((ref) => PairedSettingsNotifier(settings)),
    ...extraOverrides,
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DiveDetailPage(diveId: dive.id),
  ),
);

/// Bumped to make the buddies read reload, as a dependency changing does.
class ReloadTrigger extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final reloadTrigger = NotifierProvider<ReloadTrigger, int>(ReloadTrigger.new);

/// The reads the page's cards make for [diveId]. Once [reloadTrigger] has
/// been bumped, the buddies read waits on [reloadGate] before answering.
List<Override> pairedRenderOverrides(
  String diveId,
  SharedPreferences prefs, {
  List<BuddyWithRole> buddies = const [],
  Future<void> Function()? reloadGate,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  buddiesForDiveProvider(diveId).overrideWith((ref) async {
    if (ref.watch(reloadTrigger) > 0) await reloadGate?.call();
    return buddies;
  }),
  diveSightingsProvider(diveId).overrideWith((ref) async => <Sighting>[]),
  buddySignaturesForDiveProvider(
    diveId,
  ).overrideWith((ref) async => <Signature>[]),
  surfaceIntervalProvider(diveId).overrideWith((ref) async => null),
  tankPressuresProvider(
    diveId,
  ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
];

/// A buddy on the dive, so Buddies + Signatures can pair.
final pairedBuddy = BuddyWithRole(
  buddy: Buddy(
    id: 'b1',
    name: 'Alice',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  roles: [DiveRole.builtInBuddy()],
);
