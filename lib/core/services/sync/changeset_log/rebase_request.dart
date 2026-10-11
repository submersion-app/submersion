import 'package:drift/drift.dart';

/// A `local_publish_states.changeset_bytes_since_base` value that asks the
/// changeset writer to publish a fresh base on its next run, whatever the
/// delta holds. A base publish resets the counter to 0, so the request is
/// honoured once.
///
/// Used where rows arrive with no clock and so never ride a changeset: the
/// v277 documents migration (issue #2613) copies existing data into new
/// tables on every device, and a device that joins later adopts the base,
/// so that base must be rewritten to include them.
const int kRebaseRequestedBytes = 1 << 52;

/// Asks for a fresh base on every provider this device publishes to.
Future<void> requestRebase(DatabaseConnectionUser db) => db.customStatement(
  'UPDATE local_publish_states SET changeset_bytes_since_base = ?',
  [kRebaseRequestedBytes],
);

/// Whether [changesetBytesSinceBase] carries a [requestRebase] request.
bool isRebaseRequested(int? changesetBytesSinceBase) =>
    (changesetBytesSinceBase ?? 0) >= kRebaseRequestedBytes;
