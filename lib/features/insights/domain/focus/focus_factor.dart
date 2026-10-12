import 'package:flutter/foundation.dart';

enum FocusFactorGroup { diveShape, conditions, whenWhere, kitGas }

/// Every factor the Dive focus table compares, in display order.
enum FocusFactorId {
  maxDepth(FocusFactorGroup.diveShape, numeric: true),
  avgDepth(FocusFactorGroup.diveShape, numeric: true),
  duration(FocusFactorGroup.diveShape, numeric: true),
  waterTemp(FocusFactorGroup.conditions, numeric: true),
  visibility(FocusFactorGroup.conditions),
  current(FocusFactorGroup.conditions),
  waterType(FocusFactorGroup.conditions),
  entryMethod(FocusFactorGroup.conditions),
  month(FocusFactorGroup.whenWhere),
  timeOfDay(FocusFactorGroup.whenWhere),
  site(FocusFactorGroup.whenWhere),
  diveType(FocusFactorGroup.whenWhere),
  gas(FocusFactorGroup.kitGas),
  tankVolume(FocusFactorGroup.kitGas, numeric: true),
  weight(FocusFactorGroup.kitGas, numeric: true),
  suit(FocusFactorGroup.kitGas),
  buddy(FocusFactorGroup.kitGas);

  const FocusFactorId(this.group, {this.numeric = false});

  final FocusFactorGroup group;
  final bool numeric;

  bool get isNumeric => numeric;
}

/// One row of the common-factors table.
@immutable
sealed class FocusFactor {
  const FocusFactor({
    required this.id,
    required this.groupCovered,
    required this.groupSize,
  });

  final FocusFactorId id;

  /// Group dives that recorded this factor.
  final int groupCovered;
  final int groupSize;

  bool get standsOut;

  /// How far the group sits from its baseline, on the scale the standout
  /// rule uses: baseline standard deviations for a number, share gap for a
  /// category. Orders the standouts card; 0 when nothing can be compared.
  double get strength;
}

final class NumericFactor extends FocusFactor {
  const NumericFactor({
    required super.id,
    required super.groupCovered,
    required super.groupSize,
    required this.groupMean,
    required this.baselineMean,
    required this.standsOut,
    required this.strength,
  });

  final double? groupMean;
  final double? baselineMean;

  @override
  final bool standsOut;

  @override
  final double strength;

  double? get difference => groupMean == null || baselineMean == null
      ? null
      : groupMean! - baselineMean!;
}

@immutable
class CategoryShare {
  const CategoryShare({
    required this.key,
    required this.groupShare,
    required this.baselineShare,
    required this.groupCount,
    required this.standsOut,
    required this.strength,
    this.label,
  });

  /// The stable key the label helpers render.
  final String key;

  /// Display text the key alone cannot give (a site's name).
  final String? label;
  final double groupShare;
  final double baselineShare;
  final int groupCount;
  final bool standsOut;

  /// Group share minus baseline share.
  final double strength;
}

final class CategoricalFactor extends FocusFactor {
  const CategoricalFactor({
    required super.id,
    required super.groupCovered,
    required super.groupSize,
    required this.top,
  });

  /// The group's most common values, most common first.
  final List<CategoryShare> top;

  @override
  bool get standsOut => top.any((s) => s.standsOut);

  @override
  double get strength => top.fold(0, (m, s) => s.strength > m ? s.strength : m);
}

@immutable
class FocusFactorReport {
  const FocusFactorReport({required this.factors, required this.tooFewDives});

  final List<FocusFactor> factors;

  /// The group is below the minimum size, so nothing was compared.
  final bool tooFewDives;

  /// Standouts strongest first; ties keep display order.
  List<FocusFactor> get standouts {
    final out = factors.where((f) => f.standsOut).toList();
    final order = {for (var i = 0; i < factors.length; i++) factors[i].id: i};
    out.sort((a, b) {
      final c = b.strength.compareTo(a.strength);
      return c != 0 ? c : order[a.id]!.compareTo(order[b.id]!);
    });
    return List.unmodifiable(out);
  }
}
