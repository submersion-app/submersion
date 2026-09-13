import 'package:equatable/equatable.dart';

/// The type and tag ids a site should carry after a save (issue #1765).
///
/// Passed alongside a `DiveSite` rather than stored on it: several paths
/// save partially loaded sites (the #1187 wipe), and a field on the entity
/// would let each of them clear a site's types and tags.
class SiteClassification extends Equatable {
  final List<String> typeIds;
  final List<String> tagIds;

  const SiteClassification({this.typeIds = const [], this.tagIds = const []});

  @override
  List<Object?> get props => [typeIds, tagIds];
}
