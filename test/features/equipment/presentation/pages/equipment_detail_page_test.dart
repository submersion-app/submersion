import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_web_link_launcher.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/equipment_media_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('EquipmentDetailPage desktop redirect', () {
    const equipment = EquipmentItem(
      id: 'equip-1',
      name: 'BCD',
      type: EquipmentType.bcd,
    );

    testWidgets(
      'redirects to master-detail on desktop when not in table mode',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overrides = await getBaseOverrides();

        final router = GoRouter(
          initialLocation: '/equipment/equip-1',
          routes: [
            GoRoute(
              path: '/equipment',
              builder: (context, state) =>
                  const Scaffold(body: Text('EQUIPMENT_LIST_PAGE')),
            ),
            GoRoute(
              path: '/equipment/:id',
              builder: (context, state) =>
                  EquipmentDetailPage(equipmentId: state.pathParameters['id']!),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              equipmentListViewModeProvider.overrideWith(
                (ref) => ListViewMode.detailed,
              ),
              equipmentItemProvider(
                equipment.id,
              ).overrideWith((ref) async => equipment),
              equipmentDiveCountProvider(
                equipment.id,
              ).overrideWith((ref) async => 0),
              equipmentTripCountProvider(
                equipment.id,
              ).overrideWith((ref) async => 0),
              serviceRecordNotifierProvider(
                equipment.id,
              ).overrideWith((ref) => _MockServiceRecordNotifier()),
            ].cast(),
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('EQUIPMENT_LIST_PAGE'), findsOneWidget);
      },
    );

    testWidgets('does not redirect on desktop in table mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/equipment/equip-1',
        routes: [
          GoRoute(
            path: '/equipment',
            builder: (context, state) =>
                const Scaffold(body: Text('EQUIPMENT_LIST_PAGE')),
          ),
          GoRoute(
            path: '/equipment/:id',
            builder: (context, state) =>
                EquipmentDetailPage(equipmentId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            equipmentListViewModeProvider.overrideWith(
              (ref) => ListViewMode.table,
            ),
            equipmentItemProvider(
              equipment.id,
            ).overrideWith((ref) async => equipment),
            equipmentDiveCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            equipmentTripCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            serviceRecordNotifierProvider(
              equipment.id,
            ).overrideWith((ref) => _MockServiceRecordNotifier()),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('EQUIPMENT_LIST_PAGE'), findsNothing);
    });
  });

  group('EquipmentDetailPage attributes card', () {
    testWidgets('shows curated and custom attributes', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(600, 1600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final equipment = EquipmentItem(
        id: 'equip-2',
        name: 'Winter suit',
        type: EquipmentType.wetsuit,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'equip-2',
            key: 'thickness_mm',
            valueText: '7/5',
            valueNum: 7.0,
          ),
          EquipmentAttribute.curated(
            equipmentId: 'equip-2',
            key: 'suit_style',
            valueText: 'semi_dry',
          ),
          const EquipmentAttribute(
            id: 'c1',
            equipmentId: 'equip-2',
            key: 'Repair note',
            isCustom: true,
            valueText: 'patched left knee',
          ),
        ],
      );

      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            equipmentItemProvider(
              equipment.id,
            ).overrideWith((ref) async => equipment),
            equipmentDiveCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            equipmentTripCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            serviceRecordNotifierProvider(
              equipment.id,
            ).overrideWith((ref) => _MockServiceRecordNotifier()),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EquipmentDetailPage(equipmentId: equipment.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('7/5 mm'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('7/5 mm'), findsOneWidget);
      expect(find.text('Semi-dry'), findsOneWidget);
      expect(find.text('Repair note'), findsOneWidget);
      expect(find.text('patched left knee'), findsOneWidget);
    });
  });

  group('EquipmentDetailPage purchase price', () {
    Future<void> pumpWithEquipment(
      WidgetTester tester,
      EquipmentItem equipment,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(600, 1600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            equipmentItemProvider(
              equipment.id,
            ).overrideWith((ref) async => equipment),
            equipmentDiveCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            equipmentTripCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            serviceRecordNotifierProvider(
              equipment.id,
            ).overrideWith((ref) => _MockServiceRecordNotifier()),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EquipmentDetailPage(equipmentId: equipment.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the item currency symbol, not a hardcoded dollar', (
      tester,
    ) async {
      const equipment = EquipmentItem(
        id: 'equip-price-eur',
        name: 'Drysuit',
        type: EquipmentType.drysuit,
        purchasePrice: 1234.5,
        purchaseCurrency: 'EUR',
      );

      await pumpWithEquipment(tester, equipment);

      final expected = formatMoney(1234.5, 'EUR');
      await tester.scrollUntilVisible(
        find.text(expected),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(expected), findsOneWidget);
      expect(expected, contains('€'));
    });

    testWidgets('an unrecognised code falls back to showing the code', (
      tester,
    ) async {
      const equipment = EquipmentItem(
        id: 'equip-price-zzz',
        name: 'Prototype rebreather',
        type: EquipmentType.other,
        purchasePrice: 99.0,
        purchaseCurrency: 'ZZZ',
      );

      await pumpWithEquipment(tester, equipment);

      final expected = formatMoney(99.0, 'ZZZ');
      await tester.scrollUntilVisible(
        find.text(expected),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(expected), findsOneWidget);
      expect(expected, contains('ZZZ'));
    });
  });

  group('ServiceRecordDialog date pickers (#765)', () {
    Future<void> pumpDialog(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            serviceKindsProvider.overrideWith((ref) async => const []),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServiceRecordDialog(
                equipmentId: 'equip-3',
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the service-date field opens the date picker', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // The service dialog has its own Cancel action, so scope to the picker.
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('the next-service-due field opens the date picker', (
      tester,
    ) async {
      await pumpDialog(tester);

      await tester.tap(find.byIcon(Icons.event));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // The service dialog has its own Cancel action, so scope to the picker.
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });

  /// The purchase record (issue #1517): SKU, retailer and the product link,
  /// rendered with the purchase date and price rather than among the specs.
  group('EquipmentDetailPage purchase record', () {
    EquipmentItem itemWith(Map<String, String> purchaseAttrs) => EquipmentItem(
      id: 'equip-9',
      name: 'MK25 EVO',
      type: EquipmentType.regulator,
      attributes: [
        for (final entry in purchaseAttrs.entries)
          EquipmentAttribute.curated(
            equipmentId: 'equip-9',
            key: entry.key,
            valueText: entry.value,
          ),
      ],
    );

    Future<List<Uri>> pump(WidgetTester tester, EquipmentItem equipment) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(600, 2000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final launched = <Uri>[];
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            equipmentItemProvider(
              equipment.id,
            ).overrideWith((ref) async => equipment),
            equipmentDiveCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            equipmentTripCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            serviceRecordNotifierProvider(
              equipment.id,
            ).overrideWith((ref) => _MockServiceRecordNotifier()),
            // The documents card sits on this page now; without the override
            // it reaches the real repository and the database behind it.
            mediaForEquipmentProvider(
              equipment.id,
            ).overrideWith((ref) async => const <MediaItem>[]),
            equipmentWebLinkLaunchProvider.overrideWithValue((uri) async {
              launched.add(uri);
              return true;
            }),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EquipmentDetailPage(equipmentId: equipment.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return launched;
    }

    testWidgets('renders SKU, retailer and the web link', (tester) async {
      await pump(
        tester,
        itemWith({
          'sku': 'SP-MK25-EVO',
          'retailer': 'Dive Shop Ltd',
          'product_url': 'https://shop.example.com/mk25',
        }),
      );

      await tester.scrollUntilVisible(
        find.text('SP-MK25-EVO'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('SKU'), findsOneWidget);
      expect(find.text('SP-MK25-EVO'), findsOneWidget);
      expect(find.text('Retailer'), findsOneWidget);
      expect(find.text('Dive Shop Ltd'), findsOneWidget);
      expect(find.text('Web link'), findsOneWidget);
      expect(find.text('https://shop.example.com/mk25'), findsOneWidget);
    });

    testWidgets('unrecorded purchase fields render no rows at all', (
      tester,
    ) async {
      await pump(tester, itemWith(const {}));

      expect(find.text('SKU'), findsNothing);
      expect(find.text('Retailer'), findsNothing);
      expect(find.text('Web link'), findsNothing);
    });

    testWidgets('tapping the web link launches it', (tester) async {
      final launched = await pump(
        tester,
        itemWith({'product_url': 'https://shop.example.com/mk25'}),
      );

      final link = find.byKey(const ValueKey('equipment-detail-web-link'));
      await tester.scrollUntilVisible(
        link,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(launched, [Uri.parse('https://shop.example.com/mk25')]);
    });

    testWidgets('a bare host is shown as typed and launched as https', (
      tester,
    ) async {
      // parseWebLink only assumes the scheme at launch time, so the row keeps
      // showing exactly what the diver entered.
      final launched = await pump(
        tester,
        itemWith({'product_url': 'shop.example.com/mk25'}),
      );

      final link = find.byKey(const ValueKey('equipment-detail-web-link'));
      await tester.scrollUntilVisible(
        link,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('shop.example.com/mk25'), findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(launched, [Uri.parse('https://shop.example.com/mk25')]);
    });

    testWidgets('a value that is not a link stays plain text', (tester) async {
      // A garbled or non-web value must still be visible and editable rather
      // than silently dropped, and must never become a tappable launch.
      await pump(tester, itemWith({'product_url': 'receipt in the drawer'}));

      await tester.scrollUntilVisible(
        find.text('receipt in the drawer'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('receipt in the drawer'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('equipment-detail-web-link')),
        findsNothing,
      );
    });
  });
}

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
