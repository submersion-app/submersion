import 'package:uuid/uuid.dart';

/// Fixed namespace for the ids of passport copies of trip fills (UUID v5 of
/// the trip event id). Never change: stored copies are found by it.
const String kTripFillPassportNamespace =
    '6b2f0c4e-8d1a-4f7e-9c35-2a7e5d913b08';

/// The id of the passport copy of trip event [tripEventId]. Derived, so
/// every device agrees on it and an edit or delete finds the copy. A leaf of
/// its own so the fill history can recognise a copy without depending on
/// the trips data layer.
String tripFillPassportCopyId(String tripEventId) =>
    const Uuid().v5(kTripFillPassportNamespace, tripEventId);
