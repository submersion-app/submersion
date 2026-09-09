/// Shared paging for cloud dive imports (Suunto Cloud and Garmin Connect).
///
/// The first fetch, and each Load More, asks for this many of the newest
/// remaining dives. Fetch All walks the same cursor until the account's
/// history is exhausted and then hides the paging controls.
abstract final class CloudImportPaging {
  /// Number of latest dives to fetch per page.
  static const int pageSize = 15;
}
