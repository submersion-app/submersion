import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

/// Library of known dive computer models.
///
/// This catalog enables auto-detection during Bluetooth/USB scanning
/// and provides user-friendly names for devices.
///
/// Data sourced from libdivecomputer and manufacturer documentation.
class DeviceLibrary {
  DeviceLibrary._();

  static final DeviceLibrary _instance = DeviceLibrary._();
  static DeviceLibrary get instance => _instance;

  /// All known device models
  List<DeviceModel> get allModels => _models;

  /// Get models by manufacturer
  List<DeviceModel> getByManufacturer(String manufacturer) {
    return _models
        .where(
          (m) => m.manufacturer.toLowerCase() == manufacturer.toLowerCase(),
        )
        .toList();
  }

  /// Get models that support a specific connection type
  List<DeviceModel> getByConnectionType(DeviceConnectionType type) {
    return _models.where((m) => m.connectionTypes.contains(type)).toList();
  }

  /// Find a model by BLE service UUID.
  ///
  /// Handles both short (16-bit) and full (128-bit) UUID formats.
  /// For example, `ffe0` and `0000ffe0-0000-1000-8000-00805f9b34fb`
  /// are treated as equivalent.
  DeviceModel? findByBleServiceUuid(String uuid) {
    final normalizedInput = _normalizeBleUuid(uuid);
    return _models.cast<DeviceModel?>().firstWhere((m) {
      if (m?.bleServiceUuid == null) return false;
      return _normalizeBleUuid(m!.bleServiceUuid!) == normalizedInput;
    }, orElse: () => null);
  }

  /// Normalize a BLE UUID to a canonical short form for comparison.
  ///
  /// Standard BLE UUIDs use the base `00000000-0000-1000-8000-00805f9b34fb`.
  /// A 16-bit UUID like `ffe0` expands to `0000ffe0-0000-1000-8000-00805f9b34fb`.
  /// This method extracts the significant 16-bit portion when possible.
  static String _normalizeBleUuid(String uuid) {
    final lower = uuid.toLowerCase().trim();

    // Already short form (4 hex chars)
    if (lower.length <= 8 && !lower.contains('-')) {
      return lower;
    }

    // Full 128-bit form: extract 16-bit portion if it's a standard base UUID
    const baseSuffix = '-0000-1000-8000-00805f9b34fb';
    if (lower.endsWith(baseSuffix) && lower.startsWith('0000')) {
      // Extract the 16-bit part (chars 4-8)
      return lower.substring(4, 8);
    }

    // Non-standard 128-bit UUID, return as-is
    return lower;
  }

  /// Find a model by Bluetooth Classic service UUID
  DeviceModel? findByBtServiceUuid(String uuid) {
    final normalizedUuid = uuid.toLowerCase();
    return _models.cast<DeviceModel?>().firstWhere(
      (m) => m?.btServiceUuid?.toLowerCase() == normalizedUuid,
      orElse: () => null,
    );
  }

  /// Find a model by USB VID/PID
  DeviceModel? findByUsbIds(String vendorId, String productId) {
    final normalizedVid = vendorId.toLowerCase();
    final normalizedPid = productId.toLowerCase();
    return _models.cast<DeviceModel?>().firstWhere(
      (m) =>
          m?.usbVendorId?.toLowerCase() == normalizedVid &&
          m?.usbProductId?.toLowerCase() == normalizedPid,
      orElse: () => null,
    );
  }

  /// Find a model by device name (fuzzy match)
  DeviceModel? findByName(String name) {
    final normalizedName = name.toLowerCase();

    // First try exact match
    final exact = _models.cast<DeviceModel?>().firstWhere(
      (m) => m?.fullName.toLowerCase() == normalizedName,
      orElse: () => null,
    );
    if (exact != null) return exact;

    // Then try partial match on model name
    final partial = _models.cast<DeviceModel?>().firstWhere(
      (m) =>
          normalizedName.contains(m?.model.toLowerCase() ?? '') ||
          normalizedName.contains(m?.manufacturer.toLowerCase() ?? ''),
      orElse: () => null,
    );
    if (partial != null) return partial;

    // Try manufacturer aliases (e.g., "Pelagic" for Aqualung/Sherwood devices)
    final aliasedName = _resolveManufacturerAlias(normalizedName);
    if (aliasedName != null) return aliasedName;

    // Try Pelagic serial number prefix (e.g., "FH025918" -> Aqualung i300C)
    final serialMatch = _matchPelagicSerial(normalizedName);
    if (serialMatch != null) return serialMatch;

    return null;
  }

  /// Resolve manufacturer aliases used in BLE advertising names.
  ///
  /// Some devices advertise under their OEM/chipset manufacturer name
  /// rather than the retail brand. For example, Aqualung dive computers
  /// use Pelagic hardware and may advertise as "Pelagic i300C".
  DeviceModel? _resolveManufacturerAlias(String normalizedName) {
    const aliases = {
      'pelagic': ['Aqualung', 'Sherwood'],
      'aqlng': ['Aqualung'],
    };

    for (final entry in aliases.entries) {
      if (!normalizedName.contains(entry.key)) continue;

      // Found an alias match - search for a model within those manufacturers
      for (final manufacturer in entry.value) {
        final models = getByManufacturer(manufacturer);
        for (final model in models) {
          if (normalizedName.contains(model.model.toLowerCase())) {
            return model;
          }
        }
      }

      // If alias matched but no specific model found, return the first
      // BLE-capable model from the primary manufacturer
      final primaryModels = getByManufacturer(entry.value.first);
      final bleModel = primaryModels.cast<DeviceModel?>().firstWhere(
        (m) => m?.supportsBle == true,
        orElse: () => null,
      );
      if (bleModel != null) return bleModel;
    }

    return null;
  }

  /// Match a BLE advertising name that is a Pelagic serial number.
  ///
  /// Pelagic dive computers (Aqualung, Sherwood, Apeks) often broadcast
  /// only their serial number as the BLE name (e.g., "FH025918").
  /// The 2-letter prefix identifies the model family.
  DeviceModel? _matchPelagicSerial(String normalizedName) {
    // Pelagic serials: 2 uppercase letters + 6 digits (8 chars total)
    if (normalizedName.length != 8) return null;

    final serialPattern = RegExp(r'^[a-z]{2}\d{6}$');
    if (!serialPattern.hasMatch(normalizedName)) return null;

    final prefix = normalizedName.substring(0, 2);

    // Serial prefix -> model ID mapping for Pelagic devices
    const prefixToModelId = {
      // Aqualung i300C
      'fh': 'aqualung_i300c',
      'fj': 'aqualung_i300c',
      'fk': 'aqualung_i300c',
      // Aqualung i330R
      'fl': 'aqualung_i330r',
      'fm': 'aqualung_i330r',
      // Aqualung i550
      'fn': 'aqualung_i550',
      'fp': 'aqualung_i550',
      // Aqualung i770R
      'fr': 'aqualung_i770r',
      'fs': 'aqualung_i770r',
    };

    final modelId = prefixToModelId[prefix];
    if (modelId == null) return null;

    return _models.cast<DeviceModel?>().firstWhere(
      (m) => m?.id == modelId,
      orElse: () => null,
    );
  }

  /// Match a discovered device against the library
  DeviceModel? matchDevice(DiscoveredDevice device) {
    // Try BLE service UUID first
    for (final uuid in device.serviceUuids) {
      final model = findByBleServiceUuid(uuid);
      if (model != null) return model;
    }

    // Try name matching
    return findByName(device.name);
  }

  /// List of all unique manufacturers
  List<String> get manufacturers {
    final set = <String>{};
    for (final model in _models) {
      set.add(model.manufacturer);
    }
    final list = set.toList()..sort();
    return list;
  }

  // ============================================================================
  // Device Model Catalog
  // ============================================================================

  static const List<DeviceModel> _models = [
    // =========================================================================
    // Shearwater
    // =========================================================================
    DeviceModel(
      id: 'shearwater_perdix',
      manufacturer: 'Shearwater',
      model: 'Perdix',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 3,
    ),
    DeviceModel(
      id: 'shearwater_perdix_ai',
      manufacturer: 'Shearwater',
      model: 'Perdix AI',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 4,
    ),
    DeviceModel(
      id: 'shearwater_perdix_2',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 9,
    ),
    DeviceModel(
      id: 'shearwater_petrel',
      manufacturer: 'Shearwater',
      model: 'Petrel',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 1,
    ),
    DeviceModel(
      id: 'shearwater_petrel_2',
      manufacturer: 'Shearwater',
      model: 'Petrel 2',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 2,
    ),
    DeviceModel(
      id: 'shearwater_petrel_3',
      manufacturer: 'Shearwater',
      model: 'Petrel 3',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 10,
    ),
    DeviceModel(
      id: 'shearwater_teric',
      manufacturer: 'Shearwater',
      model: 'Teric',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 5,
    ),
    DeviceModel(
      id: 'shearwater_peregrine',
      manufacturer: 'Shearwater',
      model: 'Peregrine',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 6,
    ),
    DeviceModel(
      id: 'shearwater_nerd',
      manufacturer: 'Shearwater',
      model: 'NERD',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 7,
    ),
    DeviceModel(
      id: 'shearwater_nerd_2',
      manufacturer: 'Shearwater',
      model: 'NERD 2',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'fe25',
      dcFamily: 'shearwater_petrel',
      dcModel: 8,
    ),

    // =========================================================================
    // Suunto
    // =========================================================================
    DeviceModel(
      id: 'suunto_d5',
      manufacturer: 'Suunto',
      model: 'D5',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '98ae7120-e62e-11e3-badd-0002a5d5c51b',
      usbVendorId: '0x1493',
      usbProductId: '0x0030',
      dcFamily: 'suunto_eonsteel',
      dcModel: 4,
    ),
    DeviceModel(
      id: 'suunto_eon_steel',
      manufacturer: 'Suunto',
      model: 'EON Steel',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '98ae7120-e62e-11e3-badd-0002a5d5c51b',
      usbVendorId: '0x1493',
      usbProductId: '0x0030',
      dcFamily: 'suunto_eonsteel',
      dcModel: 1,
    ),
    DeviceModel(
      id: 'suunto_eon_core',
      manufacturer: 'Suunto',
      model: 'EON Core',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '98ae7120-e62e-11e3-badd-0002a5d5c51b',
      usbVendorId: '0x1493',
      usbProductId: '0x0030',
      dcFamily: 'suunto_eonsteel',
      dcModel: 2,
    ),
    DeviceModel(
      id: 'suunto_vyper_novo',
      manufacturer: 'Suunto',
      model: 'Vyper Novo',
      connectionTypes: [DeviceConnectionType.usb],
      usbVendorId: '0x1493',
      usbProductId: '0x0020',
      dcFamily: 'suunto_d9',
      dcModel: 16,
    ),
    DeviceModel(
      id: 'suunto_zoop_novo',
      manufacturer: 'Suunto',
      model: 'Zoop Novo',
      connectionTypes: [DeviceConnectionType.usb],
      usbVendorId: '0x1493',
      usbProductId: '0x0020',
      dcFamily: 'suunto_d9',
      dcModel: 15,
    ),
    DeviceModel(
      id: 'suunto_d4i_novo',
      manufacturer: 'Suunto',
      model: 'D4i Novo',
      connectionTypes: [DeviceConnectionType.usb],
      usbVendorId: '0x1493',
      usbProductId: '0x0020',
      dcFamily: 'suunto_d9',
      dcModel: 17,
    ),
    DeviceModel(
      id: 'suunto_d6i_novo',
      manufacturer: 'Suunto',
      model: 'D6i Novo',
      connectionTypes: [DeviceConnectionType.usb],
      usbVendorId: '0x1493',
      usbProductId: '0x0020',
      dcFamily: 'suunto_d9',
      dcModel: 18,
    ),

    // =========================================================================
    // Garmin
    // =========================================================================
    DeviceModel(
      id: 'garmin_descent_mk1',
      manufacturer: 'Garmin',
      model: 'Descent Mk1',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '6a4e2401-667b-11e3-949a-0800200c9a66',
      dcFamily: 'garmin_descent',
      dcModel: 1,
    ),
    DeviceModel(
      id: 'garmin_descent_mk2',
      manufacturer: 'Garmin',
      model: 'Descent Mk2',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '6a4e2401-667b-11e3-949a-0800200c9a66',
      dcFamily: 'garmin_descent',
      dcModel: 2,
    ),
    DeviceModel(
      id: 'garmin_descent_mk2i',
      manufacturer: 'Garmin',
      model: 'Descent Mk2i',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '6a4e2401-667b-11e3-949a-0800200c9a66',
      dcFamily: 'garmin_descent',
      dcModel: 3,
    ),
    DeviceModel(
      id: 'garmin_descent_mk2s',
      manufacturer: 'Garmin',
      model: 'Descent Mk2S',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '6a4e2401-667b-11e3-949a-0800200c9a66',
      dcFamily: 'garmin_descent',
      dcModel: 4,
    ),
    DeviceModel(
      id: 'garmin_descent_mk3',
      manufacturer: 'Garmin',
      model: 'Descent Mk3',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '6a4e2401-667b-11e3-949a-0800200c9a66',
      dcFamily: 'garmin_descent',
      dcModel: 5,
    ),
    DeviceModel(
      id: 'garmin_descent_mk3i',
      manufacturer: 'Garmin',
      model: 'Descent Mk3i',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '6a4e2401-667b-11e3-949a-0800200c9a66',
      dcFamily: 'garmin_descent',
      dcModel: 6,
    ),
    DeviceModel(
      id: 'garmin_descent_g1',
      manufacturer: 'Garmin',
      model: 'Descent G1',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '6a4e2401-667b-11e3-949a-0800200c9a66',
      dcFamily: 'garmin_descent',
      dcModel: 7,
    ),

    // =========================================================================
    // Mares
    // =========================================================================
    DeviceModel(
      id: 'mares_genius',
      manufacturer: 'Mares',
      model: 'Genius',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: '0000fefb-0000-1000-8000-00805f9b34fb',
      dcFamily: 'mares_iconhd',
      dcModel: 8,
    ),
    DeviceModel(
      id: 'mares_quad',
      manufacturer: 'Mares',
      model: 'Quad',
      connectionTypes: [DeviceConnectionType.usb],
      usbVendorId: '0x0403',
      usbProductId: '0xf680',
      dcFamily: 'mares_iconhd',
      dcModel: 5,
    ),
    DeviceModel(
      id: 'mares_puck_pro_plus',
      manufacturer: 'Mares',
      model: 'Puck Pro+',
      connectionTypes: [DeviceConnectionType.usb],
      usbVendorId: '0x0403',
      usbProductId: '0xf680',
      dcFamily: 'mares_iconhd',
      dcModel: 4,
    ),
    DeviceModel(
      id: 'mares_smart',
      manufacturer: 'Mares',
      model: 'Smart',
      connectionTypes: [DeviceConnectionType.usb],
      usbVendorId: '0x0403',
      usbProductId: '0xf680',
      dcFamily: 'mares_iconhd',
      dcModel: 6,
    ),

    // =========================================================================
    // Scubapro
    // =========================================================================
    DeviceModel(
      id: 'scubapro_g2',
      manufacturer: 'Scubapro',
      model: 'G2',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '00001623-c5ae-4d06-8fb6-0bb5f720eed8',
      dcFamily: 'uwatec_g2',
      dcModel: 0x22,
    ),
    DeviceModel(
      id: 'scubapro_g3',
      manufacturer: 'Scubapro',
      model: 'G3',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '00001623-c5ae-4d06-8fb6-0bb5f720eed8',
      dcFamily: 'uwatec_g2',
      dcModel: 0x32,
    ),
    DeviceModel(
      id: 'scubapro_aladin_a1',
      manufacturer: 'Scubapro',
      model: 'Aladin A1',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: '00001623-c5ae-4d06-8fb6-0bb5f720eed8',
      dcFamily: 'uwatec_g2',
      dcModel: 0x34,
    ),
    DeviceModel(
      id: 'scubapro_aladin_a2',
      manufacturer: 'Scubapro',
      model: 'Aladin A2',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: '00001623-c5ae-4d06-8fb6-0bb5f720eed8',
      dcFamily: 'uwatec_g2',
      dcModel: 0x36,
    ),

    // =========================================================================
    // Oceanic / Aeris
    // =========================================================================
    DeviceModel(
      id: 'oceanic_geo_4',
      manufacturer: 'Oceanic',
      model: 'Geo 4.0',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      dcFamily: 'oceanic_atom2',
      dcModel: 0x4a,
    ),
    DeviceModel(
      id: 'oceanic_pro_plus_4',
      manufacturer: 'Oceanic',
      model: 'ProPlus 4',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      dcFamily: 'oceanic_atom2',
      dcModel: 0x48,
    ),
    DeviceModel(
      id: 'oceanic_vt4',
      manufacturer: 'Oceanic',
      model: 'VT4',
      connectionTypes: [DeviceConnectionType.usb],
      dcFamily: 'oceanic_atom2',
      dcModel: 0x46,
    ),

    // =========================================================================
    // Heinrichs Weikamp (OSTC)
    // =========================================================================
    DeviceModel(
      id: 'hw_ostc_4',
      manufacturer: 'Heinrichs Weikamp',
      model: 'OSTC 4',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '0000fefb-0000-1000-8000-00805f9b34fb',
      dcFamily: 'hw_ostc3',
      dcModel: 0x05,
    ),
    DeviceModel(
      id: 'hw_ostc_plus',
      manufacturer: 'Heinrichs Weikamp',
      model: 'OSTC Plus',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '0000fefb-0000-1000-8000-00805f9b34fb',
      dcFamily: 'hw_ostc3',
      dcModel: 0x11,
    ),
    DeviceModel(
      id: 'hw_ostc_sport',
      manufacturer: 'Heinrichs Weikamp',
      model: 'OSTC Sport',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: '0000fefb-0000-1000-8000-00805f9b34fb',
      dcFamily: 'hw_ostc3',
      dcModel: 0x12,
    ),

    // =========================================================================
    // Cressi
    // =========================================================================
    DeviceModel(
      id: 'cressi_goa',
      manufacturer: 'Cressi',
      model: 'Goa',
      connectionTypes: [DeviceConnectionType.ble],
      dcFamily: 'cressi_edy',
      dcModel: 10,
    ),
    DeviceModel(
      id: 'cressi_leonardo',
      manufacturer: 'Cressi',
      model: 'Leonardo',
      connectionTypes: [DeviceConnectionType.usb],
      dcFamily: 'cressi_leonardo',
      dcModel: 1,
    ),
    DeviceModel(
      id: 'cressi_giotto',
      manufacturer: 'Cressi',
      model: 'Giotto',
      connectionTypes: [DeviceConnectionType.usb],
      dcFamily: 'cressi_leonardo',
      dcModel: 2,
    ),

    // =========================================================================
    // Aqualung / Apeks
    // =========================================================================
    DeviceModel(
      id: 'aqualung_i300c',
      manufacturer: 'Aqualung',
      model: 'i300C',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'cb3c4555-d670-4670-bc20-b61dbc851e9a',
      dcFamily: 'pelagic_i330r',
      dcModel: 1,
    ),
    DeviceModel(
      id: 'aqualung_i330r',
      manufacturer: 'Aqualung',
      model: 'i330R',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'ca7b0001-f785-4c38-b599-c7c5fbadb034',
      dcFamily: 'pelagic_i330r',
      dcModel: 2,
    ),
    DeviceModel(
      id: 'aqualung_i550',
      manufacturer: 'Aqualung',
      model: 'i550',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'cb3c4555-d670-4670-bc20-b61dbc851e9a',
      dcFamily: 'pelagic_i330r',
      dcModel: 3,
    ),
    DeviceModel(
      id: 'aqualung_i770r',
      manufacturer: 'Aqualung',
      model: 'i770R',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      bleServiceUuid: 'cb3c4555-d670-4670-bc20-b61dbc851e9a',
      dcFamily: 'pelagic_i330r',
      dcModel: 4,
    ),

    // =========================================================================
    // Ratio
    // =========================================================================
    DeviceModel(
      id: 'ratio_ix3m_pro_easy',
      manufacturer: 'Ratio',
      model: 'iX3M Pro Easy',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      dcFamily: 'ratio_ix3m2',
      dcModel: 4,
    ),
    DeviceModel(
      id: 'ratio_ix3m_pro_deep',
      manufacturer: 'Ratio',
      model: 'iX3M Pro Deep',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      dcFamily: 'ratio_ix3m2',
      dcModel: 5,
    ),
    DeviceModel(
      id: 'ratio_ix3m_pro_tech',
      manufacturer: 'Ratio',
      model: 'iX3M Pro Tech+',
      connectionTypes: [DeviceConnectionType.ble, DeviceConnectionType.usb],
      dcFamily: 'ratio_ix3m2',
      dcModel: 6,
    ),

    // =========================================================================
    // Sherwood
    // =========================================================================
    DeviceModel(
      id: 'sherwood_sage',
      manufacturer: 'Sherwood',
      model: 'Sage',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'cb3c4555-d670-4670-bc20-b61dbc851e9a',
      dcFamily: 'pelagic_i330r',
      dcModel: 10,
    ),
    DeviceModel(
      id: 'sherwood_beacon',
      manufacturer: 'Sherwood',
      model: 'Beacon',
      connectionTypes: [DeviceConnectionType.ble],
      bleServiceUuid: 'cb3c4555-d670-4670-bc20-b61dbc851e9a',
      dcFamily: 'pelagic_i330r',
      dcModel: 11,
    ),

    // =========================================================================
    // Tusa / IQ
    // =========================================================================
    DeviceModel(
      id: 'tusa_iq_1204',
      manufacturer: 'Tusa',
      model: 'IQ-1204',
      connectionTypes: [DeviceConnectionType.usb],
      dcFamily: 'tusa_iq700',
      dcModel: 4,
    ),
    DeviceModel(
      id: 'tusa_zen_air',
      manufacturer: 'Tusa',
      model: 'Zen Air',
      connectionTypes: [DeviceConnectionType.usb],
      dcFamily: 'tusa_iq700',
      dcModel: 5,
    ),

    // =========================================================================
    // Deepblu
    // =========================================================================
    DeviceModel(
      id: 'deepblu_cosmiq',
      manufacturer: 'Deepblu',
      model: 'COSMIQ+',
      connectionTypes: [DeviceConnectionType.ble],
      dcFamily: 'deepblu_cosmiq',
      dcModel: 1,
    ),
  ];
}
