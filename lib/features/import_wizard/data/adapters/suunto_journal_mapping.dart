import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_journal.dart';

/// How a Suunto journal maps onto a Submersion dive (issue #3491).
///
/// Only codes seen in a real workout map to Submersion values. A code that
/// merely reads like one (`excellent`, `light`) is not guessed at: it stays
/// text, in a custom field, until a real workout shows what it means. Adding
/// one is a line here plus a fixture.
const _visibilityBands = {'good': VisibilityBand.good};
const _currentStrengths = {'none': CurrentStrength.none};

/// The band Suunto's visibility code [id] stands for, or null when unknown.
VisibilityBand? suuntoVisibilityBand(String id) => _visibilityBands[id];

/// The current strength Suunto's current code [id] stands for, or null when
/// unknown.
CurrentStrength? suuntoCurrentStrength(String id) => _currentStrengths[id];

/// The custom fields [journal] becomes: the details Submersion has no field
/// for, as Suunto's own text, then any visibility or current whose code did
/// not map. Labels are fixed English words, since they are stored with the
/// dive rather than shown through the app's translations.
List<({String key, String value})> suuntoCustomFields(SuuntoJournal journal) {
  final visibility = journal.visibility;
  final current = journal.current;
  return [
    for (final (key, values) in [
      ('Suit', journal.suit),
      ('Environment', journal.environment),
      ('Comfort', journal.comfort),
      ('Buoyancy', journal.buoyancy),
      ('State of mind', journal.stateOfMind),
    ])
      if (values.isNotEmpty) (key: key, value: values.join(', ')),
    if (visibility != null && suuntoVisibilityBand(visibility.id) == null)
      (key: 'Visibility', value: visibility.text),
    if (current != null && suuntoCurrentStrength(current.id) == null)
      (key: 'Current', value: current.text),
  ];
}
