import 'package:connectivity_plus/connectivity_plus.dart';

/// Coarse network classification for transfer policies (design spec
/// section 9). Wifi/ethernet/VPN count as unmetered; a VPN's underlying
/// transport is invisible to the app, so it is treated optimistically.
enum NetworkKind { offline, cellular, unmetered }

class NetworkStatusService {
  NetworkStatusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static NetworkKind kindFrom(List<ConnectivityResult> results) {
    const unmetered = {
      ConnectivityResult.wifi,
      ConnectivityResult.ethernet,
      ConnectivityResult.vpn,
    };
    if (results.any(unmetered.contains)) return NetworkKind.unmetered;
    // Satellite (added in connectivity_plus 7) is metered and expensive, so it
    // shares the cellular policy. Classifying it as offline instead would make
    // a working link look like no link and block transfers outright.
    const metered = {ConnectivityResult.mobile, ConnectivityResult.satellite};
    if (results.any(metered.contains)) return NetworkKind.cellular;
    return NetworkKind.offline;
  }

  Future<NetworkKind> current() async =>
      kindFrom(await _connectivity.checkConnectivity());

  Stream<NetworkKind> get changes =>
      _connectivity.onConnectivityChanged.map(kindFrom).distinct();
}
