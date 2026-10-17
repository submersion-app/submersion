import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_list_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';

import '../../../../helpers/mock_providers.dart';

class _MockListNotifier extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _MockListNotifier() : super(const AsyncValue.data(<Certification>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestTableConfigNotifier
    extends EntityTableConfigNotifier<CertificationField> {
  _TestTableConfigNotifier()
    : super(
        defaultConfig: EntityTableViewConfig<CertificationField>(
          columns: [
            EntityTableColumnConfig(
              field: CertificationField.certName,
              isPinned: true,
            ),
          ],
        ),
        fieldFromName: CertificationFieldAdapter.instance.fieldFromName,
      );
}

/// A header title that names the slot it was asked for, so each layout's
/// test can tell which header it landed in.
final _header = SectionHeaderTitle(
  build: (context, slot, subtitle) => Text('HEADER-${slot.name}'),
  appBarHeight: (context, subtitle) => 72,
);

/// The same header, saying it is narrow enough to share the pane's row.
final _narrowHeader = SectionHeaderTitle(
  build: (context, slot, subtitle) => Text('HEADER-${slot.name}'),
  appBarHeight: (context, subtitle) => 72,
  paneTitleWidth: (context) => 60,
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    ListViewMode viewMode = ListViewMode.detailed,
    SectionHeaderTitle? header,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/certifications',
      routes: [
        GoRoute(
          path: '/certifications',
          builder: (context, state) =>
              CertificationListPage(headerTitle: header ?? _header),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          certificationListNotifierProvider.overrideWith(
            (ref) => _MockListNotifier(),
          ),
          certificationListViewModeProvider.overrideWith((ref) => viewMode),
          certificationTableConfigProvider.overrideWith(
            (ref) => _TestTableConfigNotifier(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CertificationListPage headerTitle', () {
    testWidgets('phone: titles the app bar and moves the actions under it', (
      tester,
    ) async {
      await pumpPage(tester, size: const Size(400, 800));

      expect(find.text('HEADER-appBar'), findsOneWidget);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.toolbarHeight, 72);
      expect(appBar.actions, isNull);
      expect(appBar.bottom, isNotNull);
      expect(
        find.descendant(
          of: find.byWidget(appBar.bottom!),
          matching: find.byIcon(Icons.sort),
        ),
        findsOneWidget,
      );
    });

    testWidgets('desktop: titles the list pane, icons on a row below', (
      tester,
    ) async {
      await pumpPage(tester, size: const Size(1200, 800));

      expect(find.text('HEADER-pane'), findsOneWidget);
      final title = tester.getRect(find.text('HEADER-pane'));
      final sort = tester.getRect(find.byIcon(Icons.sort));
      expect(sort.top, greaterThanOrEqualTo(title.bottom));
    });

    testWidgets('desktop: a title that fits shares one row with the icons', (
      tester,
    ) async {
      await pumpPage(
        tester,
        size: const Size(1200, 800),
        header: _narrowHeader,
      );

      final title = tester.getRect(find.text('HEADER-pane'));
      final sort = tester.getRect(find.byIcon(Icons.sort));
      expect(sort.top, lessThan(title.bottom));
      expect(sort.left, greaterThan(title.right));
    });

    testWidgets('table mode: titles the table header', (tester) async {
      await pumpPage(
        tester,
        size: const Size(1200, 800),
        viewMode: ListViewMode.table,
      );

      expect(find.text('HEADER-table'), findsOneWidget);
      expect(find.byIcon(Icons.sort), findsWidgets);
    });
  });
}
