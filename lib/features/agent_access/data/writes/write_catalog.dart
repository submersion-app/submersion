import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/buddy_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/site_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// Every entity an agent can change, by the read catalogue's names.
class WriteCatalog {
  WriteCatalog(RecordRepositories repositories, {LibraryEditStamper? stamper})
    : all = List.unmodifiable(<WritableEntry>[
        DiveWrites(repositories),
        BuddyWrites(repositories),
        SiteWrites(repositories, stamper: stamper),
      ]);

  final List<WritableEntry> all;

  WritableEntry? named(String name) {
    for (final entry in all) {
      if (entry.name == name) return entry;
    }
    return null;
  }
}
