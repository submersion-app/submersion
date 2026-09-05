/// Shared paging for cloud dive imports (Suunto Cloud and Garmin Connect).
///
/// The first fetch, and each Load More, asks for this many of the newest
/// remaining dives. Fetch All walks the same cursor until the account's
/// history is exhausted and then hides the paging controls.
class CloudImportPaging {
  CloudImportPaging._();

  /// Default number of latest dives to fetch per page.
  static const int defaultPageSize = 15;

  static const int minPageSize = 1;
  static const int maxPageSize = 100;

  /// SharedPreferences key the page-size setting is stored under.
  static const String prefsKey = 'cloud_import_page_size';

  static int clamp(int value) => value.clamp(minPageSize, maxPageSize);
}
