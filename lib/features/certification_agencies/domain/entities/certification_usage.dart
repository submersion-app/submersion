import 'package:equatable/equatable.dart';

/// How many rows reference a custom agency or level. Deletion is refused
/// while [isUsed] (issue #690), so nothing is ever rewritten.
class CertificationUsage extends Equatable {
  /// Diver and buddy certification rows, counting each row's own agency and
  /// level and its additional credentials.
  final int certifications;
  final int courses;

  const CertificationUsage({this.certifications = 0, this.courses = 0});

  bool get isUsed => certifications > 0 || courses > 0;

  CertificationUsage operator +(CertificationUsage other) => CertificationUsage(
    certifications: certifications + other.certifications,
    courses: courses + other.courses,
  );

  @override
  List<Object?> get props => [certifications, courses];
}
