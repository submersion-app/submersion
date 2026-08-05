import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The dive's water type after [site] is assigned to it, given the dive's
/// [current] value.
///
/// Snap-on-assign: take the site's water type when it has one; otherwise keep
/// the current value. A site with no water type — or clearing the site
/// ([site] == null) — never wipes a value the diver already set.
WaterType? waterTypeAfterSiteAssign(WaterType? current, DiveSite? site) =>
    site?.waterType ?? current;
