import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';

/// A saved target mix, e.g. 10/70. Pressure is deliberately not part of a
/// template: blenders reuse a mix across cylinders and fill pressures.
class MixTemplate {
  const MixTemplate({required this.o2, required this.he});

  final double o2;
  final double he;

  bool get isValid => o2 >= 0 && he >= 0 && o2 + he <= 100;

  /// "10/70", trimming a trailing ".0" so whole percentages read cleanly.
  String get label => '${_trim(o2)}/${_trim(he)}';

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Map<String, dynamic> toJson() => {'o2': o2, 'he': he};

  static MixTemplate? fromJson(Object? json) {
    if (json is! Map) return null;
    final o2 = _toDouble(json['o2']);
    final he = _toDouble(json['he']);
    if (o2 == null || he == null) return null;
    final t = MixTemplate(o2: o2, he: he);
    return t.isValid ? t : null;
  }

  @override
  bool operator ==(Object other) =>
      other is MixTemplate && other.o2 == o2 && other.he == he;

  @override
  int get hashCode => Object.hash(o2, he);

  @override
  String toString() => 'MixTemplate($label)';
}

/// Why a target mix cannot be saved as a template.
///
/// Decided here rather than at each call site: the menu and the manage dialog
/// both add templates, and they were disagreeing about whether to explain
/// themselves (PR #1215 review).
enum MixTemplateRejection {
  /// O2 + He over 100%, or a negative fraction.
  invalid,

  /// The same mix is already saved.
  duplicate,

  /// [BlenderPreferences.maxTemplates] reached.
  limitReached,
}

/// Why [candidate] cannot join [existing], or null when it can.
MixTemplateRejection? rejectionFor(
  List<MixTemplate> existing,
  MixTemplate candidate,
) {
  if (!candidate.isValid) return MixTemplateRejection.invalid;
  if (existing.contains(candidate)) return MixTemplateRejection.duplicate;
  if (existing.length >= BlenderPreferences.maxTemplates) {
    return MixTemplateRejection.limitReached;
  }
  return null;
}

/// Everything the blender remembers between sessions.
///
/// Stored as one JSON object in the `settings` key-value table rather than as
/// columns, so it costs no schema version and still syncs across devices
/// through the existing pending-record path.
class BlenderPreferences {
  const BlenderPreferences({
    required this.templates,
    required this.gasPrices,
    required this.fillTempC,
    required this.settledTempC,
    required this.cylinderWaterLiters,
    required this.model,
    required this.billedFills,
    required this.billedTo,
    required this.startPressureBar,
    required this.startMix,
    required this.targetPressureBar,
    required this.targetMix,
    required this.topupO2Percent,
    this.fillOrder = kDefaultBlenderFillOrder,
    this.flushFeeEnabled = false,
    this.flushFeeMode = FlushFeeMode.perInvoice,
    this.flushFeeGases = defaultFlushFeeGases,
    this.billedDate,
    this.archivedInvoices = const [],
  });

  /// Enough to keep a synced blob small. Nobody blends 50 distinct mixes.
  static const int maxTemplates = 50;

  /// The mixes named in issue #1100, seeded on first use only. A user who
  /// deletes all of them keeps an empty list, because seeding keys on the
  /// absence of the whole blob rather than on an empty list.
  static const List<MixTemplate> seedTemplates = [
    MixTemplate(o2: 7, he: 75),
    MixTemplate(o2: 10, he: 70),
    MixTemplate(o2: 12, he: 60),
    MixTemplate(o2: 15, he: 55),
    MixTemplate(o2: 18, he: 35),
  ];

  final List<MixTemplate> templates;

  /// Price per 100 litres of free gas, one entry per [BlenderGasRole] in
  /// that enum's order (issue #42). Null means the diver has not priced that
  /// role. Keyed by role rather than by fill position so a price stays
  /// attached to "the oxygen bank" however [fillOrder] is arranged, and so
  /// the flush fee ([flushFeeGases]) can share this same price rather than
  /// keeping its own.
  final List<double?> gasPrices;

  final double fillTempC;
  final double settledTempC;
  final double cylinderWaterLiters;
  final BlendGasModel model;

  /// Cylinders finished and put on the bill, oldest first. A blending session
  /// outlives any one blend, and a fill station doing four cylinders needs the
  /// first three to survive the fourth (issue #1100).
  final List<BilledFill> billedFills;

  /// Who the bill is for. Seeded from the logbook's diver but free text, since
  /// a fill station fills other people's cylinders.
  final String billedTo;

  /// Whether a hose-purge flat fee is charged at all.
  final bool flushFeeEnabled;

  /// How often [flushFeeEnabled] adds its lines to the bill.
  final FlushFeeMode flushFeeMode;

  /// One entry per [BlenderGasRole], in that enum's order. Each role's price
  /// comes from [gasPrices], not from here.
  final List<FlushFeeGasSetting> flushFeeGases;

  /// When the running bill started. Null means "not set yet", which the
  /// invoice card reads as today: the date is editable from the moment a
  /// bill is open, not only once it is paid.
  final DateTime? billedDate;

  /// Bills already paid and archived, oldest first. See [ArchivedInvoice].
  final List<ArchivedInvoice> archivedInvoices;

  /// Lives beside [BilledFill] itself; re-exposed here because the JSON read
  /// path enforces it.
  static const int maxBilledFills = kMaxBilledFills;

  /// The starting cylinder pressure and mix, and the target fill -- the
  /// last-entered values issue #1335 asks to remember across sessions.
  /// Matches the hard-coded defaults the state providers in
  /// `gas_blender_providers.dart` used before persistence existed, so a first
  /// run behaves exactly as it always has.
  final double startPressureBar;
  final GasMix startMix;
  final double targetPressureBar;
  final GasMix targetMix;

  /// The topup role's oxygen fraction (issue #42). The oxygen and helium
  /// roles are fixed at 100% purity and have no equivalent field; only the
  /// topup role's mix is configurable, since a fill station's third bank is
  /// air on most days but not always.
  final double topupO2Percent;

  /// The order the three roles are filled in, e.g. oxygen, then helium, then
  /// topup. A display/fill-sequence preference, independent of [gasPrices]
  /// and [flushFeeGases], which stay keyed by role identity regardless of
  /// how this is arranged.
  final List<BlenderGasRole> fillOrder;

  /// Lives beside [ArchivedInvoice] itself; re-exposed here for the same
  /// reason as [maxBilledFills].
  static const int maxArchivedInvoices = kMaxArchivedInvoices;

  factory BlenderPreferences.defaults({required double cylinderWaterLiters}) =>
      BlenderPreferences(
        templates: seedTemplates,
        gasPrices: const [null, null, null],
        fillTempC: kReferenceTempC,
        settledTempC: kReferenceTempC,
        cylinderWaterLiters: cylinderWaterLiters,
        model: BlendGasModel.zFactor,
        billedFills: const [],
        billedTo: '',
        startPressureBar: 0.0,
        startMix: const GasMix(o2: 21),
        targetPressureBar: 200.0,
        targetMix: const GasMix(o2: 32),
        topupO2Percent: 21.0,
        fillOrder: kDefaultBlenderFillOrder,
        billedDate: null,
        archivedInvoices: const [],
      );

  BlenderPreferences copyWith({
    List<MixTemplate>? templates,
    List<double?>? gasPrices,
    double? fillTempC,
    double? settledTempC,
    double? cylinderWaterLiters,
    BlendGasModel? model,
    List<BilledFill>? billedFills,
    String? billedTo,
    double? startPressureBar,
    GasMix? startMix,
    double? targetPressureBar,
    GasMix? targetMix,
    double? topupO2Percent,
    List<BlenderGasRole>? fillOrder,
    bool? flushFeeEnabled,
    FlushFeeMode? flushFeeMode,
    List<FlushFeeGasSetting>? flushFeeGases,
    DateTime? billedDate,
    List<ArchivedInvoice>? archivedInvoices,
  }) => BlenderPreferences(
    templates: (templates ?? this.templates).take(maxTemplates).toList(),
    gasPrices: gasPrices ?? this.gasPrices,
    fillTempC: fillTempC ?? this.fillTempC,
    settledTempC: settledTempC ?? this.settledTempC,
    cylinderWaterLiters: cylinderWaterLiters ?? this.cylinderWaterLiters,
    model: model ?? this.model,
    billedFills: (billedFills ?? this.billedFills)
        .take(maxBilledFills)
        .toList(),
    billedTo: billedTo ?? this.billedTo,
    startPressureBar: startPressureBar ?? this.startPressureBar,
    startMix: startMix ?? this.startMix,
    targetPressureBar: targetPressureBar ?? this.targetPressureBar,
    targetMix: targetMix ?? this.targetMix,
    topupO2Percent: topupO2Percent ?? this.topupO2Percent,
    fillOrder: normalizeBlenderFillOrder(fillOrder ?? this.fillOrder),
    flushFeeEnabled: flushFeeEnabled ?? this.flushFeeEnabled,
    flushFeeMode: flushFeeMode ?? this.flushFeeMode,
    flushFeeGases: flushFeeGases ?? this.flushFeeGases,
    billedDate: billedDate ?? this.billedDate,
    archivedInvoices: (archivedInvoices ?? this.archivedInvoices)
        .take(maxArchivedInvoices)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'templates': templates.map((t) => t.toJson()).toList(),
    'gasPrices': gasPrices,
    'fillTempC': fillTempC,
    'settledTempC': settledTempC,
    'cylinderWaterLiters': cylinderWaterLiters,
    'model': model.name,
    'billedFills': billedFills.map((f) => f.toJson()).toList(),
    'billedTo': billedTo,
    'startPressureBar': startPressureBar,
    'startMix': _gasMixToJson(startMix),
    'targetPressureBar': targetPressureBar,
    'targetMix': _gasMixToJson(targetMix),
    'topupO2Percent': topupO2Percent,
    'fillOrder': [for (final role in fillOrder) role.name],
    'flushFeeEnabled': flushFeeEnabled,
    'flushFeeMode': flushFeeMode.name,
    'flushFeeGases': flushFeeGases.map((g) => g.toJson()).toList(),
    if (billedDate != null) 'billedDate': billedDate!.toIso8601String(),
    'archivedInvoices': archivedInvoices.map((a) => a.toJson()).toList(),
  };

  /// Every field falls back independently, so one corrupt entry never costs
  /// the diver their whole saved price list.
  factory BlenderPreferences.fromJson(Map<String, dynamic> json) {
    final rawTemplates = json['templates'];
    final templates = rawTemplates is List
        ? rawTemplates
              .map(MixTemplate.fromJson)
              .whereType<MixTemplate>()
              .take(maxTemplates)
              .toList()
        : <MixTemplate>[];

    final rawPrices = json['gasPrices'];
    final prices = <double?>[null, null, null];
    if (rawPrices is List) {
      for (var i = 0; i < 3 && i < rawPrices.length; i++) {
        prices[i] = _toDouble(rawPrices[i]);
      }
    }

    final rawFills = json['billedFills'];
    final fills = rawFills is List
        ? rawFills
              .map(BilledFill.fromJson)
              .whereType<BilledFill>()
              .take(maxBilledFills)
              .toList()
        : <BilledFill>[];

    final billedTo = json['billedTo'];

    final rawFlushGases = json['flushFeeGases'];
    final flushGases = [
      for (var i = 0; i < 3; i++)
        FlushFeeGasSetting.fromJson(
          rawFlushGases is List && i < rawFlushGases.length
              ? rawFlushGases[i]
              : null,
          defaultVolumeLiters: 20,
        ),
    ];

    final billedDateRaw = json['billedDate'];
    final billedDate = billedDateRaw is String
        ? DateTime.tryParse(billedDateRaw)
        : null;

    // Read through an `is` check like every other field rather than an
    // `as List?` cast: a cast throws out of this constructor, the repository
    // catches that and reports "nothing stored", and the first settled edit
    // then writes defaults over the whole blob. One malformed key must not
    // cost the diver their mixes, prices, bill and archive (PR #1359 review).
    final rawFillOrder = json['fillOrder'];
    final fillOrder = normalizeBlenderFillOrder(
      [
        for (final name in rawFillOrder is List ? rawFillOrder : const [])
          if (name is String) BlenderGasRole.fromName(name),
      ].whereType<BlenderGasRole>().toList(),
    );

    final rawArchived = json['archivedInvoices'];
    final archivedInvoices = rawArchived is List
        ? rawArchived
              .map(ArchivedInvoice.fromJson)
              .whereType<ArchivedInvoice>()
              .take(maxArchivedInvoices)
              .toList()
        : <ArchivedInvoice>[];

    return BlenderPreferences(
      templates: templates,
      gasPrices: prices,
      fillTempC: _toDouble(json['fillTempC']) ?? kReferenceTempC,
      settledTempC: _toDouble(json['settledTempC']) ?? kReferenceTempC,
      cylinderWaterLiters: _toDouble(json['cylinderWaterLiters']) ?? 12.0,
      model: BlendGasModel.fromName(
        json['model'] is String ? json['model'] as String : null,
      ),
      billedFills: fills,
      billedTo: billedTo is String ? billedTo : '',
      startPressureBar: _toDouble(json['startPressureBar']) ?? 0.0,
      startMix: _gasMixFromJson(json['startMix']) ?? const GasMix(o2: 21),
      targetPressureBar: _toDouble(json['targetPressureBar']) ?? 200.0,
      targetMix: _gasMixFromJson(json['targetMix']) ?? const GasMix(o2: 32),
      // Falls back to the pre-issue-#42 'fillGas3' bank's O2 fraction: with
      // no reorder feature to have moved it, that bank was always the topup
      // role, so this recovers a diver's custom topup mix (e.g. nitrox
      // rather than air) losslessly. A blob with neither key is a fresh
      // install, which defaults to air.
      topupO2Percent:
          _toDouble(json['topupO2Percent']) ??
          _gasMixFromJson(json['fillGas3'])?.o2 ??
          21.0,
      // Same reasoning: the fill order was always O2, then He, then topup
      // before this field existed, since bank position was the only order
      // there was.
      fillOrder: fillOrder,
      flushFeeEnabled: json['flushFeeEnabled'] == true,
      flushFeeMode: FlushFeeMode.fromName(
        json['flushFeeMode'] is String ? json['flushFeeMode'] as String : null,
      ),
      flushFeeGases: flushGases,
      billedDate: billedDate,
      archivedInvoices: archivedInvoices,
    );
  }
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

Map<String, double> _gasMixToJson(GasMix mix) => {'o2': mix.o2, 'he': mix.he};

/// Falls back per-field like every other read here, so a partly corrupt mix
/// still yields something rather than discarding the whole entry.
GasMix? _gasMixFromJson(Object? json) {
  if (json is! Map) return null;
  final o2 = _toDouble(json['o2']);
  final he = _toDouble(json['he']);
  if (o2 == null || he == null) return null;
  return GasMix(o2: o2, he: he);
}
