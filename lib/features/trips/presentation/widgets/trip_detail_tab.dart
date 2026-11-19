/// The trip page's tabs, in display order (#2845). Every trip type shows all
/// six; the index doubles as the TabController index.
///
/// A file of its own, so what needs only the tabs (the trip's card ids,
/// and through them History's labels) does not take in the tab widgets.
enum TripDetailTab { overview, itinerary, gear, checklist, dives, photos }
