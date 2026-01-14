/// Predefined gas mix templates for quick selection
class GasTemplate {
  final String name;
  final String displayName;
  final double o2;
  final double he;
  final String? description;
  final double? maxOperatingDepth; // at ppO2 1.4

  const GasTemplate({
    required this.name,
    required this.displayName,
    required this.o2,
    this.he = 0.0,
    this.description,
    this.maxOperatingDepth,
  });
}

/// Built-in gas mix templates
class GasTemplates {
  GasTemplates._();

  // Standard breathing gases
  static const air = GasTemplate(
    name: 'air',
    displayName: 'Air',
    o2: 21.0,
    description: 'Standard air (21% O2)',
    maxOperatingDepth: 56.7, // at ppO2 1.4
  );

  // Common nitrox blends
  static const ean32 = GasTemplate(
    name: 'ean32',
    displayName: 'EAN32',
    o2: 32.0,
    description: 'Enriched Air Nitrox 32%',
    maxOperatingDepth: 33.8,
  );

  static const ean36 = GasTemplate(
    name: 'ean36',
    displayName: 'EAN36',
    o2: 36.0,
    description: 'Enriched Air Nitrox 36%',
    maxOperatingDepth: 28.9,
  );

  static const ean40 = GasTemplate(
    name: 'ean40',
    displayName: 'EAN40',
    o2: 40.0,
    description: 'Enriched Air Nitrox 40%',
    maxOperatingDepth: 25.0,
  );

  // Deco gases
  static const ean50 = GasTemplate(
    name: 'ean50',
    displayName: 'EAN50',
    o2: 50.0,
    description: 'Deco gas - 50% O2',
    maxOperatingDepth: 18.0,
  );

  static const oxygen = GasTemplate(
    name: 'oxygen',
    displayName: 'Oxygen',
    o2: 100.0,
    description: 'Pure oxygen (6m deco only)',
    maxOperatingDepth: 4.0,
  );

  // Common trimix blends
  static const tmx2135 = GasTemplate(
    name: 'tmx2135',
    displayName: 'Tx 21/35',
    o2: 21.0,
    he: 35.0,
    description: 'Normoxic trimix 21/35',
    maxOperatingDepth: 56.7,
  );

  static const tmx1845 = GasTemplate(
    name: 'tmx1845',
    displayName: 'Tx 18/45',
    o2: 18.0,
    he: 45.0,
    description: 'Trimix 18/45 (deep diving)',
    maxOperatingDepth: 67.8,
  );

  static const tmx1555 = GasTemplate(
    name: 'tmx1555',
    displayName: 'Tx 15/55',
    o2: 15.0,
    he: 55.0,
    description: 'Hypoxic trimix 15/55 (very deep)',
    maxOperatingDepth: 83.3,
  );

  static const helitrox2525 = GasTemplate(
    name: 'helitrox2525',
    displayName: 'Helitrox 25/25',
    o2: 25.0,
    he: 25.0,
    description: 'Helitrox 25/25 (recreational tech)',
    maxOperatingDepth: 46.0,
  );

  // CCR Diluent mixes (normoxic and hypoxic trimix for deep CCR)
  static const diluentAir = GasTemplate(
    name: 'diluent_air',
    displayName: 'Air Diluent',
    o2: 21.0,
    description: 'Standard air diluent for shallow CCR',
    maxOperatingDepth: 56.7,
  );

  static const diluentTx1260 = GasTemplate(
    name: 'diluent_tx1260',
    displayName: 'Tx 12/60',
    o2: 12.0,
    he: 60.0,
    description: 'Hypoxic diluent for deep CCR',
    maxOperatingDepth: 106.7,
  );

  static const diluentTx1070 = GasTemplate(
    name: 'diluent_tx1070',
    displayName: 'Tx 10/70',
    o2: 10.0,
    he: 70.0,
    description: 'Hypoxic diluent for very deep CCR',
    maxOperatingDepth: 130.0,
  );

  // SCR Supply gases (enriched nitrox for injection)
  static const scrEan40 = GasTemplate(
    name: 'scr_ean40',
    displayName: 'SCR EAN40',
    o2: 40.0,
    description: 'SCR supply gas - 40% O2',
    maxOperatingDepth: 25.0,
  );

  static const scrEan50 = GasTemplate(
    name: 'scr_ean50',
    displayName: 'SCR EAN50',
    o2: 50.0,
    description: 'SCR supply gas - 50% O2',
    maxOperatingDepth: 18.0,
  );

  static const scrEan60 = GasTemplate(
    name: 'scr_ean60',
    displayName: 'SCR EAN60',
    o2: 60.0,
    description: 'SCR supply gas - 60% O2',
    maxOperatingDepth: 13.3,
  );

  /// Templates organized by category
  static const List<GasTemplate> recreational = [air, ean32, ean36];
  static const List<GasTemplate> nitrox = [ean32, ean36, ean40];
  static const List<GasTemplate> deco = [ean50, oxygen];
  static const List<GasTemplate> technical = [
    tmx2135,
    helitrox2525,
    tmx1845,
    tmx1555,
  ];

  /// CCR diluent gas presets
  static const List<GasTemplate> diluents = [
    diluentAir,
    tmx2135,
    tmx1845,
    tmx1555,
    diluentTx1260,
    diluentTx1070,
  ];

  /// SCR supply gas presets (enriched nitrox)
  static const List<GasTemplate> scrSupply = [
    scrEan40,
    scrEan50,
    scrEan60,
    oxygen,
  ];

  /// All templates
  static const List<GasTemplate> all = [
    air,
    ean32,
    ean36,
    ean40,
    ean50,
    oxygen,
    tmx2135,
    helitrox2525,
    tmx1845,
    tmx1555,
    diluentAir,
    diluentTx1260,
    diluentTx1070,
    scrEan40,
    scrEan50,
    scrEan60,
  ];

  /// Get template by name
  static GasTemplate? byName(String name) {
    try {
      return all.firstWhere((t) => t.name == name);
    } catch (_) {
      return null;
    }
  }
}
