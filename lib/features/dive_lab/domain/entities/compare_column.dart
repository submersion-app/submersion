import 'package:equatable/equatable.dart';

/// Which kind of line a column belongs to.
enum CompareLineKind { planned, asDived, whatIf }

/// The rows of the comparison table, in order.
enum CompareRow { maxDepth, bottomTime, ndl, deco, runtime, surfaceGf }

/// How a line stood against its no-deco limit on leaving the bottom.
sealed class CompareNdl extends Equatable {
  const CompareNdl();
}

/// Still inside the limit, with this much time left.
class CompareNdlLeft extends CompareNdl {
  const CompareNdlLeft(this.seconds);

  final int seconds;

  @override
  List<Object?> get props => [seconds];
}

/// Went into deco at this runtime.
class CompareDecoAt extends CompareNdl {
  const CompareDecoAt(this.runtimeSeconds);

  final int runtimeSeconds;

  @override
  List<Object?> get props => [runtimeSeconds];
}

/// One line's values in the comparison table (issue #4003). A null value is a
/// blank cell: this line cannot supply it, never that it was zero.
class CompareColumn extends Equatable {
  const CompareColumn({
    required this.id,
    required this.kind,
    this.title,
    this.maxDepthMeters,
    this.bottomTimeSeconds,
    this.ndl,
    this.decoRequiredSeconds,
    this.decoDoneSeconds,
    this.runtimeSeconds,
    this.surfaceGf,
    this.decoStartSeconds,
  });

  /// 'planned', 'dived', or the saved scenario's id.
  final String id;
  final CompareLineKind kind;

  /// The saved scenario's name; the other kinds have a fixed label.
  final String? title;
  final double? maxDepthMeters;
  final int? bottomTimeSeconds;
  final CompareNdl? ndl;

  /// The stops the model asks for on leaving the bottom.
  final int? decoRequiredSeconds;

  /// Time spent under an obligation after leaving the bottom.
  final int? decoDoneSeconds;
  final int? runtimeSeconds;
  final double? surfaceGf;

  /// Where the chart marks the line running out of no-deco time.
  final int? decoStartSeconds;

  CompareColumn copyWith({
    String? id,
    CompareLineKind? kind,
    String? title,
    double? maxDepthMeters,
    int? bottomTimeSeconds,
    CompareNdl? ndl,
    int? decoRequiredSeconds,
    int? decoDoneSeconds,
    int? runtimeSeconds,
    double? surfaceGf,
    int? decoStartSeconds,
  }) => CompareColumn(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    maxDepthMeters: maxDepthMeters ?? this.maxDepthMeters,
    bottomTimeSeconds: bottomTimeSeconds ?? this.bottomTimeSeconds,
    ndl: ndl ?? this.ndl,
    decoRequiredSeconds: decoRequiredSeconds ?? this.decoRequiredSeconds,
    decoDoneSeconds: decoDoneSeconds ?? this.decoDoneSeconds,
    runtimeSeconds: runtimeSeconds ?? this.runtimeSeconds,
    surfaceGf: surfaceGf ?? this.surfaceGf,
    decoStartSeconds: decoStartSeconds ?? this.decoStartSeconds,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    title,
    maxDepthMeters,
    bottomTimeSeconds,
    ndl,
    decoRequiredSeconds,
    decoDoneSeconds,
    runtimeSeconds,
    surfaceGf,
    decoStartSeconds,
  ];
}
