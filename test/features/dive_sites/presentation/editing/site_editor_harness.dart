import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/mock_providers.dart';

/// A site card's editor over an unlocked sitting, in the page's scope, so
/// its rows can report unreadable input.
class SiteEditorHarness {
  SiteEditorHarness(this.controller);

  final RecordEditController<DiveSite> controller;
  EditSession<DiveSite> get session => controller.session!;
}

Future<SiteEditorHarness> pumpSiteEditor(
  WidgetTester tester,
  DiveSite site,
  Widget Function(EditSession<DiveSite> session) editor, {
  List<Override> overrides = const [],
  List<DiveSite> allSites = const [],
  AppSettings settings = const AppSettings(),
  void Function(EditSession<DiveSite> session)? onStart,
}) async {
  final controller = RecordEditController<DiveSite>(
    onSave: (_) async {},
    onStart: onStart,
  )..unlock(site);
  addTearDown(controller.dispose);
  final harness = SiteEditorHarness(controller);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await getBaseOverrides(
          settingsNotifier: MockSettingsNotifier(settings),
        ),
        sitesProvider.overrideWith((_) async => allSites),
        ...overrides,
      ].cast<Override>(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecordEditScope<DiveSite>(
              controller: controller,
              child: editor(harness.session),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}
