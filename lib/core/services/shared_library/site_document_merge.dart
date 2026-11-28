import 'package:submersion/core/services/shared_library/clocked_record.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';

export 'package:submersion/core/services/shared_library/clocked_record.dart'
    show MergeOutcome, mergeClockedRecords;

/// Result of folding a remote site document into the local one (issue
/// #2567).
typedef SiteMergeOutcome = MergeOutcome<SiteDocument>;

/// [mergeClockedRecords] for site documents.
SiteMergeOutcome mergeSiteDocuments({
  required SiteDocument local,
  required SiteDocument remote,
}) => mergeClockedRecords(local: local, remote: remote);
