/// Longest one reef-data request may take before its part reports unavailable.
///
/// A plain `http.Client` waits on a silent server forever, and a request that
/// never settles never reaches the `catch` that would turn it into a failure.
/// Services apply this to the whole `get`, not to `send`, so it also covers a
/// body that stalls after the headers arrive. The request itself is not
/// cancelled: a response landing after the limit is dropped.
const Duration reefRequestTimeout = Duration(seconds: 15);
