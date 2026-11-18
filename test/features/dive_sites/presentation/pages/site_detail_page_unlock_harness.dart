import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_edit_save_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// One save the page asked for.
typedef SiteSaveCall = ({
  String siteId,
  DiveSite Function(DiveSite stored) apply,
  List<String> cards,
  String? actingDiverId,
  bool hasHeldWrites,
});

/// Stands in for the save service: records what it was asked to write, and
/// fails on demand.
class FakeSiteSave implements SiteEditSaveService {
  FakeSiteSave(this.stored);

  DiveSite stored;
  Object? failWith;
  final calls = <SiteSaveCall>[];

  @override
  Future<({DiveSite before, DiveSite after})?> save({
    required String siteId,
    required DiveSite Function(DiveSite stored) apply,
    required Iterable<String> changedCardIds,
    String? actingDiverId,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    Set<String> Function()? heldLibraryFields,
  }) async {
    calls.add((
      siteId: siteId,
      apply: apply,
      cards: changedCardIds.toList()..sort(),
      actingDiverId: actingDiverId,
      // Not run: the page's held writes reach the database, which this
      // harness has none of.
      hasHeldWrites: writeFirst != null || alsoWrite != null,
    ));
    final failure = failWith;
    if (failure != null) throw failure;
    final after = apply(stored);
    return (before: stored, after: after);
  }
}

/// The site page under test, with its stored site and its save.
class SiteUnlockHarness {
  SiteUnlockHarness(this.save, this.settings);

  final FakeSiteSave save;
  final MockSettingsNotifier settings;
  late ProviderContainer container;
  late DiveSite stored;

  /// Stores [site] as if written elsewhere (a sync), and lets the page
  /// read it again.
  void store(DiveSite site) {
    stored = site;
    save.stored = site;
    container.invalidate(siteProvider(site.id));
  }
}

const harnessSite = DiveSite(
  id: 's1',
  diverId: 'me',
  name: 'Blue Hole',
  description: 'Wall',
  notes: 'Calm',
);

/// Pumps the full site page for [site] at phone width, with editing
/// [unlockEditing], and returns the harness.
Future<SiteUnlockHarness> pumpSitePage(
  WidgetTester tester, {
  DiveSite site = harnessSite,
  AppSettings settings = const AppSettings(),
  bool unlockEditing = true,
  bool embedded = false,
  List<Override> extra = const [],
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 1400);
  addTearDown(tester.view.reset);
  final notifier = MockSettingsNotifier(settings);
  final harness = SiteUnlockHarness(FakeSiteSave(site), notifier)
    ..stored = site;
  final page = SiteDetailPage(
    siteId: site.id,
    embedded: embedded,
    unlockEditing: unlockEditing,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await getBaseOverrides(settingsNotifier: notifier),
        validatedCurrentDiverIdProvider.overrideWith((_) async => 'me'),
        siteProvider(site.id).overrideWith((_) async => harness.stored),
        siteDiveCountProvider(site.id).overrideWith((_) async => 0),
        siteEditSaveServiceProvider.overrideWithValue(harness.save),
        ...extra,
      ].cast<Override>(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: embedded ? Scaffold(body: page) : page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  harness.container = ProviderScope.containerOf(
    tester.element(find.byType(SiteDetailPage)),
  );
  return harness;
}
