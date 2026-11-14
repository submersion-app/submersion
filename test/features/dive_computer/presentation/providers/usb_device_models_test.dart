import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

/// Which descriptors reach the USB tab of the dive computer wizard.
///
/// The tab is a static catalog picker, not a scan, so this filter is the only
/// thing standing between a supported computer and the user being unable to
/// select it at all. Issue #1271 was exactly that: the Scubapro G2 TEK is a USB
/// HID device, the native layer suppressed the USB HID transport bit, and the
/// model was therefore absent from the list with no error to explain it.
///
/// USB HID arrives here as [pigeon.TransportType.usb]. There is no separate HID
/// value on the wire: the app has one USB transfer mode, which is the cable the
/// user is holding, and the native download path works out from the descriptor
/// whether that cable speaks HID or serial.
void main() {
  Future<List<String>> usbProductsFor(
    List<pigeon.DeviceDescriptor> descriptors,
  ) async {
    final container = ProviderContainer(
      overrides: [
        deviceDescriptorsProvider.overrideWith((ref) async => descriptors),
      ],
    );
    addTearDown(container.dispose);
    final models = await container.read(usbDeviceModelsProvider.future);
    return models.map((m) => m.model).toList();
  }

  pigeon.DeviceDescriptor descriptor(
    String vendor,
    String product,
    int model,
    List<pigeon.TransportType> transports,
  ) => pigeon.DeviceDescriptor(
    vendor: vendor,
    product: product,
    model: model,
    transports: transports,
  );

  group('usbDeviceModelsProvider', () {
    test('lists a USB HID computer, which arrives as a USB transport', () async {
      final products = await usbProductsFor([
        // The shape a Scubapro G2 TEK now has: libdivecomputer declares
        // DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, and the native layer reports
        // the HID bit as usb.
        descriptor('Scubapro', 'G2 TEK', 0x31, [
          pigeon.TransportType.usb,
          pigeon.TransportType.ble,
        ]),
      ]);

      expect(products, ['G2 TEK']);
    });

    test('lists a USB HID only computer', () async {
      // The Scubapro Aladin Square declares USB HID and nothing else, so
      // before #1271 it was unreachable in the app by any route.
      final products = await usbProductsFor([
        descriptor('Scubapro', 'Aladin Square', 0x22, [
          pigeon.TransportType.usb,
        ]),
      ]);

      expect(products, ['Aladin Square']);
    });

    test('lists a serial computer, which the app shows as USB', () async {
      final products = await usbProductsFor([
        descriptor('Cressi', 'Leonardo', 18, [pigeon.TransportType.serial]),
      ]);

      expect(products, ['Leonardo']);
    });

    test('drops a computer that is only reachable over Bluetooth', () async {
      final products = await usbProductsFor([
        descriptor('Shearwater', 'Perdix 2', 11, [pigeon.TransportType.ble]),
      ]);

      expect(products, isEmpty);
    });

    test('drops an infrared-only computer', () async {
      final products = await usbProductsFor([
        descriptor('Uwatec', 'Smart Pro', 0x10, [
          pigeon.TransportType.infrared,
        ]),
      ]);

      expect(products, isEmpty);
    });
  });

  /// The order the USB tab shows. libdivecomputer's descriptor table is
  /// grouped by download protocol, not by brand (issue #4480), so the
  /// providers sort it themselves.
  group('USB device order', () {
    const usb = [pigeon.TransportType.usb];

    Future<Map<String, List<String>>> groupedFor(
      List<pigeon.DeviceDescriptor> descriptors,
    ) async {
      final container = ProviderContainer(
        overrides: [
          deviceDescriptorsProvider.overrideWith((ref) async => descriptors),
        ],
      );
      addTearDown(container.dispose);
      final grouped = await container.read(
        usbDevicesByManufacturerProvider.future,
      );
      return grouped.map(
        (brand, models) => MapEntry(brand, models.map((m) => m.model).toList()),
      );
    }

    test('sorts brands alphabetically, ignoring case', () async {
      final grouped = await groupedFor([
        descriptor('Suunto', 'Vyper', 1, usb),
        descriptor('Scubapro', 'G2', 2, usb),
        descriptor('Oceanic', 'VT3', 3, usb),
        descriptor('DiveSystem', 'iX3M', 4, usb),
        descriptor('Dive Rite', 'NiTek Q', 5, usb),
        descriptor('Deepblu', 'Cosmiq+', 6, usb),
        descriptor('Deep Six', 'Excursion', 7, usb),
        descriptor('Aeris', 'Atmos 2', 8, usb),
      ]);

      expect(grouped.keys.toList(), [
        'Aeris',
        'Deep Six',
        'Deepblu',
        'Dive Rite',
        'DiveSystem',
        'Oceanic',
        'Scubapro',
        'Suunto',
      ]);
    });

    test('sorts models alphabetically, numbers by value', () async {
      final grouped = await groupedFor([
        descriptor('Scubapro', 'Aladin Sport Matrix', 1, usb),
        descriptor('Scubapro', 'Mantis 2', 2, usb),
        descriptor('Scubapro', 'aladin A2', 3, usb),
        descriptor('Scubapro', 'Mantis', 4, usb),
        descriptor('Scubapro', 'Aladin A1', 5, usb),
        descriptor('Scubapro', 'G2 TEK', 6, usb),
        descriptor('Scubapro', 'G2', 7, usb),
        descriptor('Oceanic', 'Veo 250', 8, usb),
        descriptor('Oceanic', 'Veo 1000', 9, usb),
        descriptor('Oceanic', 'Veo 180', 10, usb),
        descriptor('Oceanic', 'Veo 200', 11, usb),
      ]);

      expect(grouped['Scubapro'], [
        'Aladin A1',
        'aladin A2',
        'Aladin Sport Matrix',
        'G2',
        'G2 TEK',
        'Mantis',
        'Mantis 2',
      ]);
      expect(grouped['Oceanic'], ['Veo 180', 'Veo 200', 'Veo 250', 'Veo 1000']);
    });

    test('merges a brand split across the table into one group', () async {
      final grouped = await groupedFor([
        descriptor('Oceanic', 'Versa Pro', 1, usb),
        descriptor('Aeris', 'Atmos 2', 2, usb),
        descriptor('Oceanic', 'Atom 1.0', 3, usb),
        descriptor('Sherwood', 'Wisdom', 4, usb),
        descriptor('Oceanic', 'Pro Plus 2', 5, usb),
      ]);

      expect(grouped.keys.toList(), ['Aeris', 'Oceanic', 'Sherwood']);
      expect(grouped['Oceanic'], ['Atom 1.0', 'Pro Plus 2', 'Versa Pro']);
    });

    test('orders models with the same name by model code', () async {
      final container = ProviderContainer(
        overrides: [
          deviceDescriptorsProvider.overrideWith(
            (ref) async => [
              descriptor('Mares', 'Puck Pro', 0x18, usb),
              descriptor('Mares', 'Puck Pro', 0x12, usb),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      final models = await container.read(usbDeviceModelsProvider.future);

      expect(models.map((m) => m.dcModel).toList(), [0x12, 0x18]);
    });
  });
}
