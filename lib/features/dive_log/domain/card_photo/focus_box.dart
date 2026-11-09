import 'package:equatable/equatable.dart';

/// Where a subject sits in a photo, normalised 0 to 1 against the full
/// image (the people tags' box). Plain Dart, so the crop logic runs outside
/// Flutter too (the contact-sheet tool).
class FocusBox extends Equatable {
  const FocusBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  double get top => y;
  double get bottom => y + height;

  FocusBox copyWith({double? x, double? y, double? width, double? height}) =>
      FocusBox(
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  @override
  List<Object?> get props => [x, y, width, height];
}
