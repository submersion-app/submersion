import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The dive's own water type after [site] is assigned to it, given the
/// dive's [current] value.
///
/// A site's water type is read through (`Dive.effectiveWaterType`), never
/// copied (issue #5040): when the site has one, the dive's own is left empty
/// so the dive reads the site's, and later edits to the site reach it. The
/// dive then shows the site's water, as it did when the value was copied.
/// A site with no water type, or clearing the site ([site] == null), keeps
/// the current value: it is the dive's own.
WaterType? waterTypeAfterSiteAssign(WaterType? current, DiveSite? site) =>
    site?.waterType != null ? null : current;
