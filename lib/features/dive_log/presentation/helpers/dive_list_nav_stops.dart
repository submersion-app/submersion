import 'package:submersion/features/dive_log/presentation/helpers/dive_list_sections.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_nav_stops.dart';

/// The stop for the trip header of the section at [sectionIndex].
///
/// It carries the section index as well as the trip id, so two runs of the
/// same trip never share a stop.
String diveListTripHeaderKey(int sectionIndex, String tripId) =>
    'trip:$sectionIndex:$tripId';

/// The dive list's keyboard stops: every trip header, the dives of each open
/// trip after it, and loose dives between them (#3065).
KeyboardNavStops diveListNavStops(List<DiveListSection> sections) {
  final stops = KeyboardNavStops();
  for (final (index, section) in sections.indexed) {
    if (section is TripSection) {
      final header = diveListTripHeaderKey(index, section.tripId);
      stops.addHeader(header, section.tripId);
      if (section.collapsed) continue;
      for (final entry in section.entries) {
        stops.addRow(entry.dive.id, header: header);
      }
    } else {
      for (final entry in section.entries) {
        stops.addRow(entry.dive.id);
      }
    }
  }
  return stops;
}
