import 'package:equatable/equatable.dart';

/// A marine protected area containing a dive site.
///
/// Sourced from ProtectedSeas Navigator (CC BY 4.0). Only unambiguous
/// identity fields are modelled. The source's activity-permission codes
/// (diving, entry, anchoring, spearfishing) have no published codebook and are
/// intentionally excluded; divers are linked to the authoritative page for
/// regulations instead.
class ReefProtection extends Equatable {
  final String siteName;
  final String? country;

  /// Published IUCN protected-area category, e.g. "Ia", "II", "VI".
  final String? iucnCategory;

  /// Cross-reference into the WDPA, for deep links only.
  final int? wdpaId;

  /// Authoritative regulations page for this area.
  final String? navigatorLink;

  const ReefProtection({
    required this.siteName,
    this.country,
    this.iucnCategory,
    this.wdpaId,
    this.navigatorLink,
  });

  ReefProtection copyWith({
    String? siteName,
    String? country,
    String? iucnCategory,
    int? wdpaId,
    String? navigatorLink,
  }) => ReefProtection(
    siteName: siteName ?? this.siteName,
    country: country ?? this.country,
    iucnCategory: iucnCategory ?? this.iucnCategory,
    wdpaId: wdpaId ?? this.wdpaId,
    navigatorLink: navigatorLink ?? this.navigatorLink,
  );

  Map<String, dynamic> toJson() => {
    'siteName': siteName,
    'country': country,
    'iucnCategory': iucnCategory,
    'wdpaId': wdpaId,
    'navigatorLink': navigatorLink,
  };

  factory ReefProtection.fromJson(Map<String, dynamic> json) => ReefProtection(
    siteName: json['siteName'] as String? ?? '',
    country: json['country'] as String?,
    iucnCategory: json['iucnCategory'] as String?,
    wdpaId: (json['wdpaId'] as num?)?.toInt(),
    navigatorLink: json['navigatorLink'] as String?,
  );

  @override
  List<Object?> get props => [
    siteName,
    country,
    iucnCategory,
    wdpaId,
    navigatorLink,
  ];
}
