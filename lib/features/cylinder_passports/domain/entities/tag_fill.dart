import 'package:equatable/equatable.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// The cylinder's newest fill as its NFC tag carries it (spec section 11):
/// written by the diver's own app, unsigned, and shown for what it is.
class TagFill extends Equatable {
  const TagFill({
    required this.id,
    required this.filledAt,
    required this.o2Percent,
    this.hePercent = 0,
    this.pressureBar,
    this.temperatureC,
    this.filledBy,
    this.analyzer,
  });

  static const int maxTextLength = 40;

  /// The fill row's id: reading the tag back never duplicates the fill.
  final String id;
  final DateTime filledAt;
  final double o2Percent;
  final double hePercent;
  final double? pressureBar;
  final double? temperatureC;
  final String? filledBy;
  final String? analyzer;

  GasMix get gasMix => GasMix(o2: o2Percent, he: hePercent);

  /// [text] trimmed and cut to [maxTextLength] whole characters, or null
  /// when blank.
  static String? capText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final runes = text.trim().runes;
    return runes.length <= maxTextLength
        ? text.trim()
        : String.fromCharCodes(runes.take(maxTextLength));
  }

  factory TagFill.fromFill(CylinderFill fill) => TagFill(
    id: fill.id,
    filledAt: fill.filledAt.toUtc(),
    o2Percent: fill.o2Percent,
    hePercent: fill.hePercent,
    pressureBar: fill.pressureBar,
    temperatureC: fill.temperatureC,
    filledBy: capText(fill.stationName),
    analyzer: capText(fill.analyzer),
  );

  TagFill copyWith({
    bool clearFilledBy = false,
    bool clearAnalyzer = false,
    bool clearTemperatureC = false,
  }) => TagFill(
    id: id,
    filledAt: filledAt,
    o2Percent: o2Percent,
    hePercent: hePercent,
    pressureBar: pressureBar,
    temperatureC: clearTemperatureC ? null : temperatureC,
    filledBy: clearFilledBy ? null : filledBy,
    analyzer: clearAnalyzer ? null : analyzer,
  );

  @override
  List<Object?> get props => [
    id,
    filledAt,
    o2Percent,
    hePercent,
    pressureBar,
    temperatureC,
    filledBy,
    analyzer,
  ];
}
