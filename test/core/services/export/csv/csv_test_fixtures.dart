import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Fixtures that touch every column of the three CSV exports. Values are
/// fixed (no clock, no time zone dependence) so the goldens are stable on
/// every machine: dates are wall-clock values formatted by field, and the
/// one epoch-millisecond attribute is a literal.
const goldenSite = DiveSite(
  id: 'site-1',
  name: 'Blue Hole',
  description: 'Sinkhole with an arch',
  location: GeoPoint(17.316, -87.535),
  maxDepth: 40.5,
  country: 'Belize',
  region: 'Lighthouse Reef',
  city: 'San Pedro',
  rating: 4.5,
  notes: 'Line 1\nLine 2',
  waterType: WaterType.salt,
  entryMethod: EntryMethod.boat,
);

List<DiveSite> goldenSites() => const [
  goldenSite,
  DiveSite(id: 'site-2', name: 'House Reef'),
];

List<Dive> goldenDives() => [
  Dive(
    id: 'dive-1',
    diveNumber: 12,
    name: 'Morning dive',
    dateTime: DateTime.utc(2025, 3, 15, 9, 5),
    bottomTime: const Duration(minutes: 41),
    runtime: const Duration(minutes: 47),
    maxDepth: 30.48,
    avgDepth: 18.25,
    waterTemp: 26.4,
    airTemp: 29.6,
    visibilityMeters: 21.3,
    diveTypeIds: const ['boat', 'deep_wreck'],
    buddy: 'Ana Reyes',
    diveMaster: 'Tom Lee',
    rating: 4,
    site: goldenSite,
    tanks: const [
      DiveTank(
        id: 't1',
        volume: 11.1,
        workingPressure: 206.843,
        startPressure: 206.843,
        endPressure: 50.5,
        gasMix: GasMix(o2: 32),
      ),
    ],
    diveComputerModel: 'Perdix AI',
    diveComputerSerial: 'SN-001',
    diveComputerFirmware: '93',
    notes: 'Great viz\nsaw turtles',
    windSpeed: 4.2,
    windDirection: CurrentDirection.northEast,
    cloudCover: CloudCover.partlyCloudy,
    precipitation: Precipitation.none,
    humidity: 71,
    weatherDescription: 'Sunny',
    customFields: const [
      DiveCustomField(id: 'c1', key: 'Boat', value: 'Sea Dog'),
      DiveCustomField(id: 'c2', key: 'Formula', value: '=1+1'),
    ],
  ),
  Dive(
    id: 'dive-2',
    diveNumber: 13,
    dateTime: DateTime.utc(2025, 3, 15, 14, 30),
    bottomTime: const Duration(minutes: 35),
    maxDepth: 12.0,
    visibility: Visibility.good,
  ),
];

EquipmentAttribute _curated(String id, String key, {String? t, double? n}) =>
    EquipmentAttribute.curated(
      equipmentId: id,
      key: key,
      valueText: t,
      valueNum: n,
    );

List<EquipmentItem> goldenEquipment() => [
  EquipmentItem(
    id: 'e-hose',
    name: 'Long hose',
    type: EquipmentType.hose,
    attributes: [_curated('e-hose', 'hose_length_m', n: 0.5588)],
  ),
  EquipmentItem(
    id: 'e-suit',
    name: 'Suit',
    type: EquipmentType.wetsuit,
    brand: 'Fourth Element',
    model: 'Proteus',
    attributes: [
      _curated('e-suit', 'size', t: 'L'),
      _curated('e-suit', 'thickness_mm', t: '5/4', n: 5),
      _curated('e-suit', 'buoyancy_kg', n: 2.5),
      _curated('e-suit', 'dry_weight_kg', n: 3.25),
      _curated('e-suit', 'suit_style', t: 'full'),
    ],
  ),
  EquipmentItem(
    id: 'e-tank',
    name: 'AL80',
    type: EquipmentType.tank,
    serialNumber: '00123',
    attributes: [
      _curated('e-tank', 'volume_l', n: 11.1),
      _curated('e-tank', 'working_pressure_bar', n: 206.843),
      _curated('e-tank', 'tank_material', t: 'aluminum'),
    ],
  ),
  EquipmentItem(
    id: 'e-dpv',
    name: 'Scooter',
    type: EquipmentType.dpv,
    attributes: [
      _curated('e-dpv', 'speed_mps', n: 0.5),
      _curated('e-dpv', 'burn_time_h', n: 1.5),
    ],
  ),
  EquipmentItem(
    id: 'e-cell',
    name: 'Cell A',
    type: EquipmentType.o2Cell,
    attributes: [
      _curated('e-cell', 'cell_slot', n: 2),
      _curated('e-cell', 'installed_date', n: 1741996800000),
      const EquipmentAttribute(
        id: 'custom-1',
        equipmentId: 'e-cell',
        key: 'Batch',
        isCustom: true,
        valueText: 'B-77',
      ),
    ],
  ),
  EquipmentItem(
    id: 'e-first',
    name: 'Mk25',
    type: EquipmentType.firstStage,
    purchaseDate: DateTime(2023, 6, 1),
    lastServiceDate: DateTime(2025, 1, 10),
    serviceIntervalDays: 365,
    isActive: false,
    notes: 'DIN\nserviced',
  ),
  const EquipmentItem(
    id: 'e-reg',
    name: 'Primary reg',
    type: EquipmentType.regulator,
  ),
];

Map<String, List<String>> goldenComponentNames() => {
  'e-reg': ['Mk25', 'Long hose'],
};

/// [goldenEquipment] with the installed date stored the way the date picker
/// stores it (local midnight). The golden keeps a literal UTC epoch so its
/// bytes are the same everywhere, but My units writes a date attribute as a
/// calendar date, and that epoch is the previous day west of Greenwich.
List<EquipmentItem> roundTripEquipment() => [
  for (final item in goldenEquipment())
    item.id == 'e-cell'
        ? item.copyWith(
            attributes: [
              for (final a in item.attributes)
                a.key == 'installed_date'
                    ? a.copyWith(
                        valueNum: DateTime(
                          2025,
                          3,
                          15,
                        ).millisecondsSinceEpoch.toDouble(),
                      )
                    : a,
            ],
          )
        : item,
];
